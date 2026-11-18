//
//  SPKError.swift
//

import Foundation

/// Errors thrown while reading an SPK kernel or evaluating one of its segments.
public enum SPKError: Error, Sendable, Hashable {
  /// The data is not a DAF/SPK file (the identification word is not `DAF/SPK`).
  case notAnSPKFile
  /// The binary format is not IEEE little- or big-endian (for example an old VAX-format kernel).
  case unsupportedBinaryFormat(String)
  /// The file ends before a record or segment it describes.
  case truncated
  /// The file is structurally invalid; the string says how.
  case malformed(String)
  /// The segment's data type is not Chebyshev position (type 2) or position and velocity (type 3).
  case unsupportedSegmentType(Int)
  /// The kernel has no segment for `target` that covers `et`, although it has one for other epochs.
  case noCoverage(target: Int, et: Double)
  /// The segments needed to connect `target` and `center` do not meet at a common body.
  case noPath(target: Int, center: Int)
  /// The segments in a chain use different reference frames, or a frame that cannot be converted.
  case unsupportedFrame(Int)
  /// The kernel has no segment for the given body.
  case bodyNotInKernel(BodyID)
}
