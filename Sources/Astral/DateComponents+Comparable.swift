//
//  File.swift
//
//
//  Created by Xiangyu Sun on 27/1/23.
//

import Foundation

// MARK: - DateComponents + Comparable

/// Allows `DateComponents` values to be compared using their total seconds.
extension DateComponents: Comparable {

  /// Returns `true` if `lhs` occurs before `rhs` when both are interpreted as durations.
  public static func < (lhs: DateComponents, rhs: DateComponents) -> Bool {
    toSeconds(dateComponent: lhs) < toSeconds(dateComponent: rhs)
  }
}

extension Int? {
  static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs ?? 0) < (rhs ?? 0)
  }
}
