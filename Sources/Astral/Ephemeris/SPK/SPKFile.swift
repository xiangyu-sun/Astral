//
//  SPKFile.swift
//

import Foundation
import simd

// MARK: - SPKState

/// A body's position and velocity relative to another body.
public struct SPKState: Sendable, Hashable {

  // MARK: Lifecycle

  public init(position: SIMD3<Double>, velocity: SIMD3<Double>, frame: Int) {
    self.position = position
    self.velocity = velocity
    self.frame = frame
  }

  // MARK: Public

  /// Position, kilometres.
  public var position: SIMD3<Double>
  /// Velocity, kilometres per second.
  public var velocity: SIMD3<Double>
  /// NAIF frame code of the axes: `1` is J2000 (ICRF), `17` is the ecliptic and equinox of J2000.
  public var frame: Int

  /// The state of nothing relative to itself.
  public static func zero(frame: Int) -> SPKState {
    SPKState(position: .zero, velocity: .zero, frame: frame)
  }
}

// MARK: - SPKFile

/// A NAIF SPK kernel (DAF container), such as JPL's `de440s.bsp`.
///
/// The reader understands the DAF file, summary and name records of either byte order, and evaluates segments of
/// data type 2 (Chebyshev position, velocity from the derivative) and type 3 (Chebyshev position and velocity),
/// which is what every JPL planetary development ephemeris uses. Segments of other types are listed in
/// ``segments`` but cannot be evaluated.
///
/// Time is ephemeris time ET (TDB), in seconds past J2000. States are kilometres and kilometres per second in the
/// frame of the segments, which is J2000 (ICRF axes, frame code 1) for DE kernels. ``state(target:center:at:)``
/// chains segments, so the Moon (301) relative to the Sun (10) goes through the Earth-Moon barycentre (3) and the
/// solar-system barycentre (0).
///
/// ```swift
/// let kernel = try SPKFile(contentsOf: url)                      // e.g. de440s.bsp
/// let jd = JulianDate(days: 2_461_359.0)                         // treated as TDB
/// let moon = try kernel.state(target: 301, center: 399, at: jd)  // km, km/s
/// let mars = try kernel.heliocentricEclipticPosition(of: .mars, at: jd)   // AU, like SolarSystem
/// ```
public struct SPKFile: Sendable {

  // MARK: Lifecycle

  /// Reads a kernel from disk. The file is memory-mapped when possible, so large kernels are not copied.
  public init(contentsOf url: URL) throws {
    try self.init(data: Data(contentsOf: url, options: .mappedIfSafe))
  }

  /// Reads a kernel from memory.
  public init(data: Data) throws {
    // Slices keep their parent's indices; normalise so byte offsets start at 0.
    let data = data.startIndex == 0 ? data : Data(data)
    guard data.count >= Self.recordLength else { throw SPKError.truncated }

    let identification = Self.ascii(data, 0, 8)
    guard identification.hasPrefix("DAF/SPK") else { throw SPKError.notAnSPKFile }

    let format = Self.ascii(data, 88, 8)
    let bigEndian: Bool
    switch format {
    case "LTL-IEEE": bigEndian = false
    case "BIG-IEEE": bigEndian = true
    default: throw SPKError.unsupportedBinaryFormat(format)
    }
    let bytes = DAFBytes(data: data, bigEndian: bigEndian)

    let nd = Int(bytes.int32(at: 8))
    let ni = Int(bytes.int32(at: 12))
    guard nd == 2, ni == 6 else {
      throw SPKError.malformed("SPK summaries need ND=2, NI=6 (found ND=\(nd), NI=\(ni))")
    }
    let forward = Int(bytes.int32(at: 76))
    guard forward >= 1 else { throw SPKError.malformed("bad forward summary record pointer \(forward)") }

    internalName = Self.ascii(data, 16, 60)
    comments = Self.parseComments(data, upToRecord: forward)
    segments = try Self.readSegments(bytes, firstSummaryRecord: forward)
    self.bytes = bytes
  }

  // MARK: Public

  /// The DAF internal file name.
  public let internalName: String
  /// The DAF comment area, with line breaks.
  public let comments: String
  /// Every segment in file order. When two segments describe the same target and epoch, the later one wins.
  public let segments: [SPKSegment]

  /// TDB seconds past J2000 for a Julian date taken as TDB.
  public static func ephemerisTime(of time: JulianDate) -> Double {
    (time.days - JulianDate.j2000.days) * 86_400
  }

  /// The segments describing `target`, in file order.
  public func segments(targeting target: Int) -> [SPKSegment] {
    segments.filter { $0.target == target }
  }

  /// Position and velocity of `segment`'s target relative to its centre at `et`, in the segment's frame.
  ///
  /// - Parameters:
  ///   - segment: A segment of this kernel.
  ///   - et: TDB seconds past J2000; must lie inside `segment.coverage`.
  /// - Throws: ``SPKError/unsupportedSegmentType(_:)`` unless the segment is type 2 or 3, and
  ///   ``SPKError/noCoverage(target:et:)`` outside the segment's span.
  public func state(of segment: SPKSegment, at et: Double) throws -> SPKState {
    guard let layout = segment.layout else { throw SPKError.unsupportedSegmentType(segment.dataType) }
    guard segment.contains(et: et) else { throw SPKError.noCoverage(target: segment.target, et: et) }

    var index = Int(((et - layout.initialEpoch) / layout.intervalLength).rounded(.down))
    index = min(max(index, 0), layout.recordCount - 1)
    // Zero-based index of the record's first word.
    let first = segment.beginAddress - 1 + index * layout.recordSize
    let n = layout.coefficientCount
    let hasVelocity = segment.dataType == 3

    let (position, velocity) = bytes.data.withUnsafeBytes { raw -> (SIMD3<Double>, SIMD3<Double>) in
      let big = bytes.bigEndian
      func word(_ i: Int) -> Double {
        let bits = raw.loadUnaligned(fromByteOffset: i * 8, as: UInt64.self)
        return Double(bitPattern: big ? UInt64(bigEndian: bits) : UInt64(littleEndian: bits))
      }

      let mid = word(first)
      let radius = word(first + 1)
      let s = (et - mid) / radius

      // Chebyshev polynomials T_k(s) and their derivatives dT_k/ds, accumulated against the coefficients.
      var position = SIMD3<Double>.zero
      var velocity = SIMD3<Double>.zero
      var tPrev2 = 0.0
      var tPrev = 1.0 // T_{k-2}, T_{k-1} (T_0 = 1)
      var dPrev2 = 0.0
      var dPrev = 0.0 // derivatives
      for k in 0..<n {
        let t: Double
        let d: Double
        switch k {
        case 0:
          t = 1
          d = 0

        case 1:
          t = s
          d = 1

        default:
          t = 2 * s * tPrev - tPrev2
          d = 2 * tPrev + 2 * s * dPrev - dPrev2
        }
        let cx = word(first + 2 + k)
        let cy = word(first + 2 + n + k)
        let cz = word(first + 2 + 2 * n + k)
        position += SIMD3(cx, cy, cz) * t
        if hasVelocity {
          velocity += SIMD3(word(first + 2 + 3 * n + k), word(first + 2 + 4 * n + k), word(first + 2 + 5 * n + k)) * t
        } else {
          velocity += SIMD3(cx, cy, cz) * d
        }
        tPrev2 = tPrev
        tPrev = t
        dPrev2 = dPrev
        dPrev = d
      }
      // d/dt = (1/radius) d/ds for type 2; type 3 stores velocity directly.
      return (position, hasVelocity ? velocity : velocity / radius)
    }
    return SPKState(position: position, velocity: velocity, frame: segment.frame)
  }

  /// Position and velocity of `target` relative to `center`, kilometres and kilometres per second.
  ///
  /// Segments are chained through their centres: each body is followed up to the solar-system barycentre (0), or
  /// to the last body the kernel has a segment for, and the two chains are combined at the first body they share.
  /// If several segments cover the epoch for a body, the last one in the file is used.
  ///
  /// - Parameters:
  ///   - target: NAIF ID of the body.
  ///   - center: NAIF ID of the observer or origin.
  ///   - et: Ephemeris time, TDB seconds past J2000.
  /// - Returns: The state in the frame of the segments (J2000 for DE kernels), tagged with its frame code.
  public func state(target: Int, center: Int, at et: Double) throws -> SPKState {
    if target == center { return .zero(frame: segments.first?.frame ?? 1) }
    let a = try chain(from: target, at: et)
    let b = try chain(from: center, at: et)
    if let frameA = a.frame, let frameB = b.frame, frameA != frameB {
      throw SPKError.unsupportedFrame(frameB)
    }
    for node in a.nodes {
      guard let match = b.nodes.first(where: { $0.id == node.id }) else { continue }
      return SPKState(
        position: node.state.position - match.state.position,
        velocity: node.state.velocity - match.state.velocity,
        frame: a.frame ?? b.frame ?? 1
      )
    }
    throw SPKError.noPath(target: target, center: center)
  }

  /// ``state(target:center:at:)`` for a Julian date, which is interpreted as TDB.
  ///
  /// No UTC to TDB conversion is made, in keeping with ``JulianDate``: TDB differs from UTC by about 69 s now,
  /// which moves the Moon by roughly 70 km.
  public func state(target: Int, center: Int, at time: JulianDate) throws -> SPKState {
    try state(target: target, center: center, at: Self.ephemerisTime(of: time))
  }

  // MARK: Internal

  static let recordLength = 1_024

  // MARK: Private

  private struct ChainNode {
    let id: Int
    /// The chain's start body relative to `id`.
    let state: SPKState
  }

  private struct Chain {
    var nodes: [ChainNode]
    var frame: Int?
  }

  private let bytes: DAFBytes

  private static func ascii(_ data: Data, _ offset: Int, _ length: Int) -> String {
    let slice = data[(data.startIndex + offset)..<(data.startIndex + offset + length)]
    let trimmed = slice.prefix { $0 != 0 }
    var text = String(decoding: trimmed, as: UTF8.self)
    while text.hasSuffix(" ") { text.removeLast() }
    return text
  }

  /// The comment area: records 2 up to the first summary record. Lines end in NUL and the text ends at an EOT byte.
  private static func parseComments(_ data: Data, upToRecord forward: Int) -> String {
    let start = recordLength
    let end = min(max(forward - 1, 1) * recordLength, data.count)
    guard end > start else { return "" }
    var text = [UInt8]()
    for byte in data[(data.startIndex + start)..<(data.startIndex + end)] {
      if byte == 4 { break }
      text.append(byte == 0 ? 10 : byte)
    }
    return String(decoding: text, as: UTF8.self)
  }

  /// Walks the chain of summary records from the forward pointer.
  private static func readSegments(_ bytes: DAFBytes, firstSummaryRecord: Int) throws -> [SPKSegment] {
    let summarySize = 5 // ND + (NI + 1) / 2 doubles
    let maxRecords = bytes.data.count / recordLength
    var segments = [SPKSegment]()
    var record = firstSummaryRecord
    var visited = 0

    while record != 0 {
      visited += 1
      guard visited <= maxRecords else { throw SPKError.malformed("summary records form a loop") }
      let base = (record - 1) * recordLength
      guard base >= 0, base + recordLength <= bytes.data.count else { throw SPKError.truncated }

      let next = bytes.double(at: base)
      let count = Int(bytes.double(at: base + 16))
      guard count >= 0, 24 + count * summarySize * 8 <= recordLength else {
        throw SPKError.malformed("summary record \(record) claims \(count) summaries")
      }
      let nameBase = record * recordLength // the name record follows its summary record

      for i in 0..<count {
        let off = base + 24 + i * summarySize * 8
        let start = bytes.double(at: off)
        let stop = bytes.double(at: off + 8)
        let target = Int(bytes.int32(at: off + 16))
        let center = Int(bytes.int32(at: off + 20))
        let frame = Int(bytes.int32(at: off + 24))
        let dataType = Int(bytes.int32(at: off + 28))
        let begin = Int(bytes.int32(at: off + 32))
        let end = Int(bytes.int32(at: off + 36))

        guard begin >= 1, end >= begin else { throw SPKError.malformed("bad segment addresses \(begin)...\(end)") }
        guard end * 8 <= bytes.data.count else { throw SPKError.truncated }

        var name = ""
        let nameOffset = nameBase + i * summarySize * 8
        if nameOffset + summarySize * 8 <= bytes.data.count {
          name = ascii(bytes.data, nameOffset, summarySize * 8)
        }

        var layout: SPKSegment.Layout?
        if dataType == 2 || dataType == 3 {
          layout = try chebyshevLayout(bytes, dataType: dataType, begin: begin, end: end)
        }
        segments.append(SPKSegment(
          name: name,
          target: target,
          center: center,
          frame: frame,
          dataType: dataType,
          startET: start,
          stopET: stop,
          beginAddress: begin,
          endAddress: end,
          layout: layout
        ))
      }
      record = Int(next)
    }
    return segments
  }

  /// Reads and checks the INIT, INTLEN, RSIZE, N trailer of a type 2 or 3 segment.
  private static func chebyshevLayout(
    _ bytes: DAFBytes,
    dataType: Int,
    begin: Int,
    end: Int
  ) throws -> SPKSegment.Layout {
    guard end - begin + 1 >= 4 else { throw SPKError.malformed("segment too short for a trailer") }
    let trailer = (end - 4) * 8
    let initialEpoch = bytes.double(at: trailer)
    let intervalLength = bytes.double(at: trailer + 8)
    let rsize = bytes.double(at: trailer + 16)
    let n = bytes.double(at: trailer + 24)
    guard
      initialEpoch.isFinite, intervalLength.isFinite, intervalLength > 0,
      rsize.isFinite, rsize == rsize.rounded(), n.isFinite, n == n.rounded(), n >= 1
    else {
      throw SPKError.malformed("bad segment trailer")
    }
    let recordSize = Int(rsize)
    let recordCount = Int(n)
    let components = dataType == 2 ? 3 : 6
    guard recordSize > 2, (recordSize - 2) % components == 0 else {
      throw SPKError.malformed("record size \(recordSize) does not fit type \(dataType)")
    }
    guard recordSize * recordCount + 4 == end - begin + 1 else {
      throw SPKError.malformed("segment length does not match \(recordCount) records of \(recordSize) words")
    }
    return SPKSegment.Layout(
      initialEpoch: initialEpoch,
      intervalLength: intervalLength,
      recordSize: recordSize,
      recordCount: recordCount,
      coefficientCount: (recordSize - 2) / components
    )
  }

  /// The body's states relative to each of its ancestors, from itself up to the root.
  private func chain(from start: Int, at et: Double) throws -> Chain {
    var nodes = [ChainNode(id: start, state: .zero(frame: 1))]
    var frame: Int?
    var current = start
    var accumulated = SPKState.zero(frame: 1)
    // A solar system has few levels; the limit also guards against a cyclic file.
    for _ in 0..<16 {
      guard let segment = segment(for: current, at: et) else {
        if segments.contains(where: { $0.target == current }) {
          throw SPKError.noCoverage(target: current, et: et)
        }
        break
      }
      if let known = frame, known != segment.frame { throw SPKError.unsupportedFrame(segment.frame) }
      frame = segment.frame
      let relative = try state(of: segment, at: et)
      accumulated.position += relative.position
      accumulated.velocity += relative.velocity
      accumulated.frame = segment.frame
      current = segment.center
      nodes.append(ChainNode(id: current, state: accumulated))
      if current == 0 { break }
    }
    return Chain(nodes: nodes, frame: frame)
  }

  private func segment(for target: Int, at et: Double) -> SPKSegment? {
    segments.last { $0.target == target && $0.contains(et: et) }
  }

}

// MARK: - DAFBytes

/// Byte-order-aware access to the words of a DAF file. Offsets are zero-based byte offsets.
struct DAFBytes: Sendable {
  let data: Data
  let bigEndian: Bool

  func double(at offset: Int) -> Double {
    let bits = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self) }
    return Double(bitPattern: bigEndian ? UInt64(bigEndian: bits) : UInt64(littleEndian: bits))
  }

  func int32(at offset: Int) -> Int32 {
    let bits = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    return Int32(bitPattern: bigEndian ? UInt32(bigEndian: bits) : UInt32(littleEndian: bits))
  }
}
