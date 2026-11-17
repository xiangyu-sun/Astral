//
//  SPKSegment.swift
//

import Foundation

/// One segment of an SPK kernel: the trajectory of `target` relative to `center` over a time span.
///
/// Times are ephemeris time (TDB) in seconds past J2000. Positions are in kilometres. The segment only describes
/// the data; evaluate it with ``SPKFile/state(of:at:)``.
public struct SPKSegment: Sendable, Hashable {

  // MARK: Public

  /// Segment name (the DAF name record), usually the source ephemeris such as `DE-0440LE-0440`.
  public let name: String
  /// NAIF ID of the body the segment describes.
  public let target: Int
  /// NAIF ID of the body the target is measured from.
  public let center: Int
  /// NAIF frame code; `1` is J2000 (ICRF axes), which every DE kernel uses.
  public let frame: Int
  /// SPK data type; ``SPKFile`` evaluates type 2 (Chebyshev position) and type 3 (Chebyshev position and velocity).
  public let dataType: Int
  /// First epoch the segment covers, TDB seconds past J2000.
  public let startET: Double
  /// Last epoch the segment covers, TDB seconds past J2000.
  public let stopET: Double

  /// The covered span, TDB seconds past J2000.
  public var coverage: ClosedRange<Double> { startET...stopET }

  /// Whether `et` (TDB seconds past J2000) lies inside the segment.
  public func contains(et: Double) -> Bool {
    et >= startET && et <= stopET
  }

  // MARK: Internal

  /// Layout of a Chebyshev segment, from the four-word trailer at its end.
  struct Layout: Sendable, Hashable {
    /// Start of the first record, TDB seconds past J2000.
    let initialEpoch: Double
    /// Length of each record, seconds.
    let intervalLength: Double
    /// Words per record, including the midpoint and radius.
    let recordSize: Int
    let recordCount: Int
    /// Coefficients per component in every record.
    let coefficientCount: Int
  }

  /// One-based double-word address of the segment's first word.
  let beginAddress: Int
  /// One-based double-word address of the segment's last word.
  let endAddress: Int
  /// Present for types 2 and 3.
  let layout: Layout?
}
