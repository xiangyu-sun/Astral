// swiftlint:disable no_direct_standard_out_logs
import Astral
import Foundation
import simd
import Testing

// MARK: - Fixtures

/// The committed excerpt of de440s.bsp (62 KB, 2026-07-01 .. 2026-12-31), see Fixtures/SPK/make_tiny_kernel.py.
func loadTinyKernelData() throws -> Data {
  let url = try #require(
    Bundle.module.url(forResource: "tiny", withExtension: "bsp", subdirectory: "Fixtures/SPK")
      ?? Bundle.module.url(forResource: "tiny", withExtension: "bsp"),
    "tiny.bsp missing from test bundle"
  )
  return try Data(contentsOf: url)
}

func loadTinyKernel() throws -> SPKFile {
  try SPKFile(data: loadTinyKernelData())
}

// MARK: - SPKHorizonsFixture

/// JPL Horizons vector tables in km and km/s, see Fixtures/SPK/make_spk_fixture.py.
struct SPKHorizonsFixture: Decodable {
  struct Row: Decodable {
    let jd: Double
    let date: String
    let p: [Double]
    let v: [Double]

    var position: SIMD3<Double> {
      SIMD3(p[0], p[1], p[2])
    }

    var velocity: SIMD3<Double> {
      SIMD3(v[0], v[1], v[2])
    }
  }

  struct Case: Decodable {
    let target: String
    let center: String
    let plane: String
    let rows: [Row]
  }

  let source: String
  let cases: [String: Case]

  static func load() throws -> SPKHorizonsFixture {
    let url = try #require(
      Bundle.module.url(forResource: "horizons_spk", withExtension: "json", subdirectory: "Fixtures/SPK")
        ?? Bundle.module.url(forResource: "horizons_spk", withExtension: "json"),
      "horizons_spk.json missing from test bundle"
    )
    return try JSONDecoder().decode(SPKHorizonsFixture.self, from: Data(contentsOf: url))
  }

  func rows(_ name: String) throws -> [Row] {
    try #require(cases[name], "no fixture case \(name)").rows
  }
}

/// ET seconds for a TDB Julian date.
func et(_ jd: Double) -> Double {
  (jd - 2_451_545.0) * 86_400
}

// MARK: - SyntheticSegment

/// Writes a small DAF/SPK with exactly known Chebyshev coefficients, in either byte order.
struct SyntheticSegment {
  var target: Int
  var center: Int
  var frame = 1
  var dataType: Int
  var initialEpoch: Double
  var intervalLength: Double
  /// Full records: midpoint, radius, then coefficients.
  var records: [[Double]]
}

func makeSyntheticKernel(_ segments: [SyntheticSegment], bigEndian: Bool) -> Data {
  func bytes(_ x: Double) -> [UInt8] {
    withUnsafeBytes(of: bigEndian ? x.bitPattern.bigEndian : x.bitPattern.littleEndian) { Array($0) }
  }
  func bytes(_ x: Int32) -> [UInt8] {
    withUnsafeBytes(of: bigEndian ? UInt32(bitPattern: x).bigEndian : UInt32(bitPattern: x).littleEndian) { Array($0) }
  }
  func pad(_ b: [UInt8], to n: Int, with fill: UInt8) -> [UInt8] {
    b + [UInt8](repeating: fill, count: n - b.count)
  }

  var next = 3 * 128 + 1 // first data word: record 4
  var summaries = [UInt8]()
  var names = [UInt8]()
  var data = [UInt8]()
  for (i, seg) in segments.enumerated() {
    let rsize = seg.records[0].count
    let words = seg.records.flatMap { $0 }
      + [seg.initialEpoch, seg.intervalLength, Double(rsize), Double(seg.records.count)]
    let begin = next
    let end = next + words.count - 1
    next = end + 1
    summaries += bytes(seg.initialEpoch)
    summaries += bytes(seg.initialEpoch + seg.intervalLength * Double(seg.records.count))
    for v in [seg.target, seg.center, seg.frame, seg.dataType, begin, end] { summaries += bytes(Int32(v)) }
    names += Array("SYNTH \(i)".utf8) + [UInt8](repeating: 32, count: 40 - "SYNTH \(i)".utf8.count)
    data += words.flatMap(bytes)
  }
  var file = Array("DAF/SPK ".utf8)
  file += bytes(Int32(2)) + bytes(Int32(6))
  file += pad(Array("synthetic".utf8), to: 60, with: 32)
  file += bytes(Int32(2)) + bytes(Int32(2)) + bytes(Int32(next))
  file += Array((bigEndian ? "BIG-IEEE" : "LTL-IEEE").utf8)
  file = pad(file, to: 1024, with: 0)

  let summaryRecord = pad(bytes(0.0) + bytes(0.0) + bytes(Double(segments.count)) + summaries, to: 1024, with: 0)
  let nameRecord = pad(names, to: 1024, with: 32)
  let dataBlock = pad(data, to: (data.count + 1023) / 1024 * 1024, with: 0)
  return Data(file + summaryRecord + nameRecord + dataBlock)
}

/// Chebyshev value and derivative via the trigonometric definitions: an independent check of the recurrence.
func chebyshevReference(_ coefficients: [Double], s: Double) -> (value: Double, derivative: Double) {
  let theta = acos(s)
  var value = 0.0
  var derivative = 0.0
  for (k, c) in coefficients.enumerated() {
    value += c * cos(Double(k) * theta)
    if k > 0 { derivative += c * Double(k) * sin(Double(k) * theta) / sin(theta) }
  }
  return (value, derivative)
}

// MARK: - SPKParsingTests

@Suite("SPK: DAF parsing", .tags(.ephemeris, .integration))
struct SPKParsingTests {
  @Test
  func readsTinyKernelStructure() throws {
    let kernel = try loadTinyKernel()
    #expect(kernel.segments.count == 14)
    #expect(Set(kernel.segments.map(\.target)) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 199, 299, 301, 399])
    #expect(kernel.segments.allSatisfy { $0.dataType == 2 && $0.frame == 1 })
    #expect(kernel.segments.allSatisfy { $0.name == "DE-0440LE-0440" })
    #expect(kernel.comments.contains("Tiny SPK cut from de440s.bsp"))
    #expect(kernel.internalName == "Astral test kernel (DE440s excerpt)")

    // Centres: planets and the Sun around the SSB, Earth and Moon around the EMB, Mercury/Venus around their barycentres.
    let centers = Dictionary(uniqueKeysWithValues: kernel.segments.map { ($0.target, $0.center) })
    #expect(centers[399] == 3 && centers[301] == 3 && centers[3] == 0 && centers[10] == 0)
    #expect(centers[199] == 1 && centers[299] == 2)

    // Every segment is clamped to the 2026-07-01 .. 2026-12-31 window.
    for segment in kernel.segments {
      #expect(abs(segment.startET - et(2_461_222.5)) < 1e-6)
      #expect(abs(segment.stopET - et(2_461_405.5)) < 1e-6)
    }
  }

  @Test
  func readsFromDisk() throws {
    let url = try #require(
      Bundle.module.url(forResource: "tiny", withExtension: "bsp", subdirectory: "Fixtures/SPK")
        ?? Bundle.module.url(forResource: "tiny", withExtension: "bsp")
    )
    let fromDisk = try SPKFile(contentsOf: url)
    #expect(fromDisk.segments == (try loadTinyKernel()).segments)
  }

  @Test
  func acceptsASliceOfLargerData() throws {
    let data = try loadTinyKernelData()
    let padded = Data(repeating: 0xAB, count: 77) + data
    let kernel = try SPKFile(data: padded[77...])
    #expect(kernel.segments.count == 14)
    let direct = try loadTinyKernel()
    let a = try kernel.state(target: 399, center: 10, at: et(2_461_359.0))
    let b = try direct.state(target: 399, center: 10, at: et(2_461_359.0))
    #expect(a == b)
  }

  @Test
  func rejectsBadInput() throws {
    #expect(throws: SPKError.truncated) { try SPKFile(data: Data()) }
    #expect(throws: SPKError.notAnSPKFile) { try SPKFile(data: Data(repeating: 0, count: 2048)) }

    var data = try loadTinyKernelData()
    #expect(throws: SPKError.truncated) { try SPKFile(data: data.prefix(4 * 1024)) }

    data.replaceSubrange(88..<96, with: Array("VAX-GFLT".utf8))
    #expect(throws: SPKError.unsupportedBinaryFormat("VAX-GFLT")) { try SPKFile(data: data) }
  }

  @Test(arguments: [false, true])
  func synthKernelParsesInEitherByteOrder(bigEndian: Bool) throws {
    let segment = SyntheticSegment(
      target: 1000,
      center: 0,
      dataType: 2,
      initialEpoch: 0,
      intervalLength: 100,
      records: [[50, 50, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [150, 50, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]]
    )
    let kernel = try SPKFile(data: makeSyntheticKernel([segment], bigEndian: bigEndian))
    #expect(kernel.segments.count == 1)
    #expect(kernel.segments[0].target == 1000)
    #expect(kernel.segments[0].name == "SYNTH 0")
    #expect(kernel.segments[0].coverage == 0...200)
  }
}

// MARK: - SPKEvaluationTests

@Suite("SPK: Chebyshev evaluation", .tags(.ephemeris, .accuracy))
struct SPKEvaluationTests {
  static let cx = [1000.0, 200, 30, 4]
  static let cy = [-50.0, 7, 0.5, -0.25]
  static let cz = [3.0, 0, 1, 0]
  static let vx = [5.0, 0.5, -0.1, 0.01]
  static let vy = [1.0, 2, 3, 4]
  static let vz = [0.0, 0, 0, 1]

  static func type2() -> SyntheticSegment {
    // Second record has the same coefficients but a different midpoint.
    let coefficients: [Double] = [cx, cy, cz].flatMap { $0 }
    let first: [Double] = [50, 50] + coefficients
    let second: [Double] = [150, 50] + coefficients
    return SyntheticSegment(
      target: 1000,
      center: 0,
      dataType: 2,
      initialEpoch: 0,
      intervalLength: 100,
      records: [first, second]
    )
  }

  static func type3() -> SyntheticSegment {
    let coefficients: [Double] = [cx, cy, cz, vx, vy, vz].flatMap { $0 }
    let first: [Double] = [50, 50] + coefficients
    let second: [Double] = [150, 50] + coefficients
    return SyntheticSegment(
      target: 1001,
      center: 1000,
      dataType: 3,
      initialEpoch: 0,
      intervalLength: 100,
      records: [first, second]
    )
  }

  @Test(arguments: [false, true])
  func type2MatchesAnalyticChebyshev(bigEndian: Bool) throws {
    let kernel = try SPKFile(data: makeSyntheticKernel([Self.type2()], bigEndian: bigEndian))
    for (t, mid) in [(0.0, 50.0), (13.7, 50), (50, 50), (99.9, 50), (100, 150), (123.4, 150), (200, 150)] {
      let state = try kernel.state(target: 1000, center: 0, at: t)
      let s = (t - mid) / 50
      let x = chebyshevReference(Self.cx, s: min(max(s, -1 + 1e-12), 1 - 1e-12))
      let y = chebyshevReference(Self.cy, s: min(max(s, -1 + 1e-12), 1 - 1e-12))
      let z = chebyshevReference(Self.cz, s: min(max(s, -1 + 1e-12), 1 - 1e-12))
      #expect(abs(state.position.x - x.value) < 1e-9, "x at \(t)")
      #expect(abs(state.position.y - y.value) < 1e-9, "y at \(t)")
      #expect(abs(state.position.z - z.value) < 1e-9, "z at \(t)")
      // Velocity is the derivative with respect to time: d/ds / radius.
      #expect(abs(state.velocity.x - x.derivative / 50) < 1e-8, "vx at \(t)")
      #expect(abs(state.velocity.y - y.derivative / 50) < 1e-8, "vy at \(t)")
      #expect(abs(state.velocity.z - z.derivative / 50) < 1e-8, "vz at \(t)")
      #expect(state.frame == 1)
    }
  }

  @Test(arguments: [false, true])
  func type3ReadsPositionAndVelocityPolynomialsSeparately(bigEndian: Bool) throws {
    let kernel = try SPKFile(data: makeSyntheticKernel([Self.type3()], bigEndian: bigEndian))
    let t = 37.5
    let s = (t - 50) / 50
    let state = try kernel.state(target: 1001, center: 1000, at: t)
    #expect(abs(state.position.x - chebyshevReference(Self.cx, s: s).value) < 1e-9)
    #expect(abs(state.position.y - chebyshevReference(Self.cy, s: s).value) < 1e-9)
    #expect(abs(state.velocity.x - chebyshevReference(Self.vx, s: s).value) < 1e-9)
    #expect(abs(state.velocity.y - chebyshevReference(Self.vy, s: s).value) < 1e-9)
    #expect(abs(state.velocity.z - chebyshevReference(Self.vz, s: s).value) < 1e-9)
  }

  @Test
  func chainingAddsSegmentsAndSubtractsCommonAncestors() throws {
    let kernel = try SPKFile(data: makeSyntheticKernel([Self.type2(), Self.type3()], bigEndian: false))
    let t = 61.0
    let a = try kernel.state(target: 1000, center: 0, at: t)
    let b = try kernel.state(target: 1001, center: 1000, at: t)
    let c = try kernel.state(target: 1001, center: 0, at: t)
    #expect(simd_length(c.position - (a.position + b.position)) < 1e-9)
    #expect(simd_length(c.velocity - (a.velocity + b.velocity)) < 1e-9)
    let reverse = try kernel.state(target: 0, center: 1001, at: t)
    #expect(simd_length(reverse.position + c.position) < 1e-9)
    // 1001 relative to 1000 stops at the shared body and never touches 1000's own segment.
    #expect(try kernel.state(target: 1000, center: 1000, at: t) == SPKState.zero(frame: 1))
  }

  @Test
  func reportsCoverageAndPathErrors() throws {
    let other = SyntheticSegment(
      target: 2000,
      center: 0,
      frame: 17,
      dataType: 2,
      initialEpoch: 0,
      intervalLength: 100,
      records: [[50, 50] + Self.cx + Self.cy + Self.cz, [150, 50] + Self.cx + Self.cy + Self.cz]
    )
    let island = SyntheticSegment(
      target: 3001,
      center: 3000,
      dataType: 2,
      initialEpoch: 0,
      intervalLength: 100,
      records: [[50, 50] + Self.cx + Self.cy + Self.cz, [150, 50] + Self.cx + Self.cy + Self.cz]
    )
    let kernel = try SPKFile(data: makeSyntheticKernel([Self.type2(), other, island], bigEndian: false))
    #expect(throws: SPKError.noCoverage(target: 1000, et: 200.5)) { try kernel.state(target: 1000, center: 0, at: 200.5) }
    #expect(throws: SPKError.noCoverage(target: 1000, et: -1)) { try kernel.state(target: 1000, center: 0, at: -1) }
    // Mixed frames in one chain.
    #expect(throws: SPKError.unsupportedFrame(17)) { try kernel.state(target: 1000, center: 2000, at: 10) }
    // Bodies in different trees (3000 is a root of its own, 0 is another).
    #expect(throws: SPKError.noPath(target: 3001, center: 1000)) { try kernel.state(target: 3001, center: 1000, at: 10) }
    // A body the kernel never mentions.
    #expect(throws: SPKError.noPath(target: 42, center: 0)) { try kernel.state(target: 42, center: 0, at: 10) }
  }

  @Test
  func unsupportedSegmentTypesAreListedButNotEvaluated() throws {
    var type5 = Self.type2()
    type5.dataType = 5
    let kernel = try SPKFile(data: makeSyntheticKernel([type5], bigEndian: false))
    #expect(kernel.segments.count == 1)
    #expect(throws: SPKError.unsupportedSegmentType(5)) { try kernel.state(target: 1000, center: 0, at: 10) }
  }
}

// MARK: - SPKHorizonsTests

@Suite("SPK: DE440s excerpt vs JPL Horizons", .tags(.ephemeris, .accuracy, .integration))
struct SPKHorizonsTests {

  // Tolerances. DE440s (the kernel) and Horizons (DE441) agree to under a millimetre for the planets and the Sun,
  // and to 2.5 m for the Moon (the two developments differ slightly in the lunar orbit): 10 m and 1 mm/s.
  static let positionToleranceKm = 0.01
  static let velocityToleranceKmS = 1e-6

  /// Bodies whose Horizons target maps straight onto an Astral body (Mars..Pluto are system barycentres).
  static let bodies: [(name: String, id: BodyID)] = [
    ("mercury", .mercury),
    ("venus", .venus),
    ("earth", .earth),
    ("moon", .moon),
    ("mars", .mars),
    ("jupiter", .jupiter),
    ("saturn", .saturn),
    ("uranus", .uranus),
    ("neptune", .neptune),
    ("pluto", .pluto),
  ]

  @Test(arguments: SPKHorizonsTests.bodies.map(\.name))
  func heliocentricEclipticMatchesHorizons(name: String) throws {
    let id = try #require(Self.bodies.first { $0.name == name }).id
    let kernel = try loadTinyKernel()
    let fixture = try SPKHorizonsFixture.load()
    var worstP = 0.0
    var worstV = 0.0
    for row in try fixture.rows("helio_ecl_\(name)") {
      let state = try kernel.eclipticState(of: id, relativeTo: .sun, at: JulianDate(days: row.jd))
      let dp = simd_length(state.position - row.position)
      let dv = simd_length(state.velocity - row.velocity)
      worstP = max(worstP, dp)
      worstV = max(worstV, dv)
      #expect(state.frame == 17)
      #expect(dp < Self.positionToleranceKm, "\(name) JD \(row.jd): position off by \(dp) km")
      #expect(dv < Self.velocityToleranceKmS, "\(name) JD \(row.jd): velocity off by \(dv) km/s")
    }
    print("SPK vs Horizons (helio ecliptic) \(name): worst position \(worstP * 1000) m, velocity \(worstV * 1e6) mm/s")
  }

  @Test
  func heliocentricPositionInAUMatchesHorizons() throws {
    let kernel = try loadTinyKernel()
    let fixture = try SPKHorizonsFixture.load()
    for row in try fixture.rows("helio_ecl_earth") {
      let au = try kernel.heliocentricEclipticPosition(of: .earth, at: JulianDate(days: row.jd))
      #expect(simd_length(au - row.position / Units.kmPerAU) < 1e-10, "JD \(row.jd)") // 15 m
    }
  }

  /// Raw ICRF states relative to the solar-system barycentre: no rotation, exercising chaining (Earth through the
  /// Earth-Moon barycentre) and plain single segments.
  @Test(arguments: [("sun", 10), ("earth", 399), ("moon", 301), ("emb", 3), ("jupiter", 5)])
  func barycentricICRFMatchesHorizons(name: String, naif: Int) throws {
    let kernel = try loadTinyKernel()
    let fixture = try SPKHorizonsFixture.load()
    var worstP = 0.0
    for row in try fixture.rows("ssb_icrf_\(name)") {
      let state = try kernel.state(target: naif, center: 0, at: et(row.jd))
      let dp = simd_length(state.position - row.position)
      let dv = simd_length(state.velocity - row.velocity)
      worstP = max(worstP, dp)
      #expect(state.frame == 1)
      #expect(dp < Self.positionToleranceKm, "\(name) JD \(row.jd): position off by \(dp) km")
      #expect(dv < Self.velocityToleranceKmS, "\(name) JD \(row.jd): velocity off by \(dv) km/s")
    }
    print("SPK vs Horizons (SSB ICRF) \(name): worst position \(worstP * 1000) m")
  }

  /// Moon relative to Earth, and the JulianDate overload, which treats the date as TDB.
  @Test
  func geocentricMoonMatchesHorizons() throws {
    let kernel = try loadTinyKernel()
    let fixture = try SPKHorizonsFixture.load()
    for row in try fixture.rows("geo_ecl_moon") {
      let state = try kernel.eclipticState(of: .moon, relativeTo: .earth, at: JulianDate(days: row.jd))
      #expect(simd_length(state.position - row.position) < Self.positionToleranceKm, "JD \(row.jd)")
      #expect(simd_length(state.velocity - row.velocity) < Self.velocityToleranceKmS, "JD \(row.jd)")
    }
  }

  @Test
  func julianDateOverloadIsTDBSecondsPastJ2000() throws {
    let kernel = try loadTinyKernel()
    let jd = JulianDate(days: 2_461_300.25)
    let a = try kernel.state(target: 399, center: 10, at: jd)
    let b = try kernel.state(target: 399, center: 10, at: (2_461_300.25 - 2_451_545.0) * 86_400)
    #expect(a == b)
    #expect(SPKFile.ephemerisTime(of: .j2000) == 0)
  }

  /// The Moon relative to the Sun goes Moon -> EMB -> SSB and Sun -> SSB; check against explicit segment arithmetic.
  @Test
  func chainingMatchesManualSegmentArithmetic() throws {
    let kernel = try loadTinyKernel()
    let t = et(2_461_333.123456)
    func segment(_ target: Int) throws -> SPKSegment {
      try #require(kernel.segments(targeting: target).first)
    }
    let moonEMB = try kernel.state(of: segment(301), at: t)
    let embSSB = try kernel.state(of: segment(3), at: t)
    let sunSSB = try kernel.state(of: segment(10), at: t)
    let chained = try kernel.state(target: 301, center: 10, at: t)
    #expect(simd_length(chained.position - (moonEMB.position + embSSB.position - sunSSB.position)) < 1e-6)
    #expect(simd_length(chained.velocity - (moonEMB.velocity + embSSB.velocity - sunSSB.velocity)) < 1e-12)

    // Earth and Moon are on opposite sides of the barycentre: Earth = EMB - Moon/(1+mu), Moon relative to Earth is 301 - 399.
    let earthRel = try kernel.state(target: 399, center: 3, at: t)
    let moonRel = try kernel.state(target: 301, center: 3, at: t)
    let ratio = -simd_length(earthRel.position) / simd_length(moonRel.position)
    #expect(abs(ratio) < 0.013 && abs(ratio) > 0.011) // mass ratio of the Moon to the Earth-Moon system is 1/82.3
  }

  /// Velocity is the time derivative of position.
  @Test(arguments: [399, 301, 5, 10])
  func velocityIsDerivativeOfPosition(naif: Int) throws {
    let kernel = try loadTinyKernel()
    for jd in [2_461_240.3, 2_461_300.25, 2_461_380.9] {
      let t = et(jd)
      let h = 5.0
      let plus = try kernel.state(target: naif, center: 0, at: t + h).position
      let minus = try kernel.state(target: naif, center: 0, at: t - h).position
      let numeric = (plus - minus) / (2 * h)
      let analytic = try kernel.state(target: naif, center: 0, at: t).velocity
      #expect(simd_length(numeric - analytic) < 1e-6, "target \(naif) JD \(jd)")
    }
  }

  @Test
  func continuousAcrossRecordBoundaries() throws {
    let kernel = try loadTinyKernel()
    let moon = try #require(kernel.segments(targeting: 301).first)
    let layoutStart = moon.startET
    // The Moon's records are 4 days long; evaluate either side of every boundary in the window.
    var boundary = (layoutStart / 345_600).rounded(.up) * 345_600
    var checked = 0
    while boundary < moon.stopET - 10 {
      let before = try kernel.state(target: 301, center: 3, at: boundary - 1e-6)
      let after = try kernel.state(target: 301, center: 3, at: boundary + 1e-6)
      #expect(simd_length(before.position - after.position) < 1e-3, "boundary \(boundary)")
      boundary += 345_600
      checked += 1
    }
    #expect(checked > 30)
  }

  @Test
  func coverageEdgesAndErrors() throws {
    let kernel = try loadTinyKernel()
    // Inclusive at both ends, an error one second outside.
    _ = try kernel.state(target: 399, center: 10, at: et(2_461_222.5))
    _ = try kernel.state(target: 399, center: 10, at: et(2_461_405.5))
    #expect(throws: SPKError.noCoverage(target: 399, et: et(2_461_222.5) - 1)) {
      try kernel.state(target: 399, center: 10, at: et(2_461_222.5) - 1)
    }
    #expect(throws: SPKError.noCoverage(target: 301, et: et(2_461_405.5) + 1)) {
      try kernel.state(target: 301, center: 399, at: et(2_461_405.5) + 1)
    }
    #expect(throws: SPKError.noPath(target: 999, center: 10)) { try kernel.state(target: 999, center: 10, at: et(2_461_300)) }
    #expect(throws: SPKError.bodyNotInKernel(.mars)) {
      // A kernel with only the Earth-Moon pair.
      let moonOnly = SyntheticSegment(
        target: 301,
        center: 399,
        dataType: 2,
        initialEpoch: 0,
        intervalLength: 100,
        records: [[50, 50] + SPKEvaluationTests.cx + SPKEvaluationTests.cy + SPKEvaluationTests.cz]
      )
      let small = try SPKFile(data: makeSyntheticKernel([moonOnly], bigEndian: false))
      _ = try small.heliocentricEclipticPosition(of: .mars, at: JulianDate(days: 2_451_545.0))
    }
  }

  @Test
  func bodyIDMapping() throws {
    let kernel = try loadTinyKernel()
    // de440s has body centres for Mercury, Venus, Earth, Moon, Sun and barycentres for the rest.
    #expect(kernel.naifID(for: .sun) == 10)
    #expect(kernel.naifID(for: .mercury) == 199)
    #expect(kernel.naifID(for: .venus) == 299)
    #expect(kernel.naifID(for: .earth) == 399)
    #expect(kernel.naifID(for: .moon) == 301)
    #expect(kernel.naifID(for: .mars) == 4)
    #expect(kernel.naifID(for: .jupiter) == 5)
    #expect(kernel.naifID(for: .pluto) == 9)
    for body in BodyID.allCases { #expect(!SPKFile.naifIDs(for: body).isEmpty) }
  }
}

// MARK: - SPKSolarSystemComparisonTests

/// SPK positions against ``SolarSystem``. The tolerances are the documented accuracy of the closed-form model:
/// twice JPL's nominal errors for the planets (the same table as the Horizons fixture tests) and the Moon model
/// bounds of MoonModelAccuracyTests. They are not loosened here; if the model drifts, these tests say so.
@Suite("SPK vs SolarSystem", .tags(.ephemeris, .accuracy, .integration))
struct SPKSolarSystemComparisonTests {

  struct Row: Sendable, CustomTestStringConvertible {
    let name: String
    let id: BodyID
    let lonArcsec: Double
    let latArcsec: Double
    let distKkm: Double

    var testDescription: String {
      name
    }
  }

  /// JPL nominal errors 1800-2050 (arcsec, arcsec, thousand km); the tolerance is twice these.
  static let rows: [Row] = [
    .init(name: "Mercury", id: .mercury, lonArcsec: 15, latArcsec: 1, distKkm: 1),
    .init(name: "Venus", id: .venus, lonArcsec: 20, latArcsec: 1, distKkm: 4),
    .init(name: "Mars", id: .mars, lonArcsec: 40, latArcsec: 2, distKkm: 25),
    .init(name: "Jupiter", id: .jupiter, lonArcsec: 400, latArcsec: 10, distKkm: 600),
    .init(name: "Saturn", id: .saturn, lonArcsec: 600, latArcsec: 25, distKkm: 1_500),
    .init(name: "Uranus", id: .uranus, lonArcsec: 50, latArcsec: 2, distKkm: 1_000),
    .init(name: "Neptune", id: .neptune, lonArcsec: 10, latArcsec: 1, distKkm: 200),
  ]

  static let epochs = [2_461_230.5, 2_461_265.2403, 2_461_300.25, 2_461_359.0, 2_461_400.0]

  @Test(arguments: SPKSolarSystemComparisonTests.rows)
  func planetsAgreeWithClosedFormModel(row: Row) throws {
    let kernel = try loadTinyKernel()
    let system = SolarSystem()
    for jd in Self.epochs {
      let time = JulianDate(days: jd)
      let spk = try kernel.heliocentricEclipticPosition(of: row.id, at: time)
      let model = try #require(system.snapshot(at: time).position(of: row.id))
      let err = PositionError(model: model, reference: spk)
      print(
        "SPK vs SolarSystem \(row.name) JD \(jd): lon \(fmt(err.lonArcsec))\" lat \(fmt(err.latArcsec))\" dist \(fmt(err.distKkm)) x1000km"
      )
      // KNOWN ISSUE, as in PlanetFixtureTests: Neptune's JPL row reproduces its position relative to the
      // solar-system barycentre, not the Sun. Constants are left as published.
      withKnownIssue(isIntermittent: true) {
        #expect(err.lonArcsec <= row.lonArcsec * 2, "\(row.name) JD \(jd) lon \(err.lonArcsec)\"")
        #expect(err.latArcsec <= row.latArcsec * 2, "\(row.name) JD \(jd) lat \(err.latArcsec)\"")
        #expect(err.distKkm <= row.distKkm * 2, "\(row.name) JD \(jd) dist \(err.distKkm) x1000 km")
      } when: { row.id == .neptune }
    }
  }

  @Test(arguments: MoonModel.allCases)
  func moonAgreesWithEachMoonModel(model: MoonModel) throws {
    let kernel = try loadTinyKernel()
    let system = SolarSystem(moonModel: model)
    let (lonTol, latTol, distTol): (Double, Double, Double) =
      switch model {
      case .meanElements, .periodicTerms: (3 * 3600, 1 * 3600, 0.06)
      case .series: (90, 130, 0.0002)
      }
    for jd in Self.epochs {
      let time = JulianDate(days: jd)
      let ref = try kernel.eclipticState(of: .moon, relativeTo: .earth, at: time).position / Units.kmPerAU
      let snapshot = system.snapshot(at: time)
      let geo = try #require(snapshot.position(of: .moon)) - #require(snapshot.position(of: .earth))
      let m = Spherical(geo)
      let r = Spherical(ref)
      let lon = abs(wrapPi(m.lon - r.lon)) * arcsecPerRad
      let lat = abs(m.lat - r.lat) * arcsecPerRad
      let dist = abs(m.r - r.r) / r.r
      print("SPK vs SolarSystem Moon(\(model)) JD \(jd): lon \(fmt(lon))\" lat \(fmt(lat))\" dist \(fmt(dist * 100, 4))%")
      #expect(lon <= lonTol && lat <= latTol && dist <= distTol, "\(model) JD \(jd)")
    }
  }

  @Test
  func earthAgreesWithClosedFormModel() throws {
    let kernel = try loadTinyKernel()
    let system = SolarSystem(moonModel: .series)
    // The EM barycentre row's tolerance (x2): 20", 8", 6000 km thousand-km units; Earth's own centre inherits it.
    for jd in Self.epochs {
      let time = JulianDate(days: jd)
      let spk = try kernel.heliocentricEclipticPosition(of: .earth, at: time)
      let model = try #require(system.snapshot(at: time).position(of: .earth))
      let err = PositionError(model: model, reference: spk)
      print(
        "SPK vs SolarSystem Earth JD \(jd): lon \(fmt(err.lonArcsec))\" lat \(fmt(err.latArcsec))\" dist \(fmt(err.distKkm)) x1000km"
      )
      #expect(err.lonArcsec <= 40 && err.latArcsec <= 16 && err.distKkm <= 12, "JD \(jd)")
    }
  }

  /// The snapshot built from the kernel has the same shape as the closed-form one and its positions are the kernel's.
  @Test
  func snapshotFromKernel() throws {
    let kernel = try loadTinyKernel()
    let time = JulianDate(days: 2_461_359.0)
    let system = SolarSystem(bodies: Catalog.allWithPluto)
    let fromKernel = try system.snapshot(at: time, kernel: kernel)
    let closedForm = system.snapshot(at: time)
    #expect(Set(fromKernel.states.keys) == Set(closedForm.states.keys))
    #expect(fromKernel.time == time)
    #expect(fromKernel.position(of: .sun) == .zero)
    for id in BodyID.allCases {
      let expected = try kernel.heliocentricEclipticPosition(of: id, at: time)
      #expect(fromKernel.position(of: id) == expected)
    }
    // Orientation comes from the same code: the Moon faces the Earth.
    let moon = try #require(fromKernel.states[.moon])
    let earth = try #require(fromKernel.states[.earth])
    #expect(moon.orientation == BodyOrientation.tidallyLocked(toParent: earth.position - moon.position))
  }

  @Test
  func snapshotSkipsBodiesTheKernelLacks() throws {
    let moonOnly = SyntheticSegment(
      target: 10,
      center: 0,
      dataType: 2,
      initialEpoch: 0,
      intervalLength: 1e12,
      records: [[5e11, 5e11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]
    )
    let kernel = try SPKFile(data: makeSyntheticKernel([moonOnly], bigEndian: false))
    let snapshot = try SolarSystem().snapshot(at: JulianDate(days: 2_451_545.0), kernel: kernel)
    #expect(Set(snapshot.states.keys) == [.sun])
  }
}
