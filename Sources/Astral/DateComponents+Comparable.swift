//
//  File.swift
//
//
//  Created by Xiangyu Sun on 27/1/23.
//

import Foundation

// MARK: - DateComponents + Comparable

extension DateComponents: Comparable {

  public static func < (lhs: DateComponents, rhs: DateComponents) -> Bool {
    lhs.year < rhs.year ||
      lhs.month < rhs.month ||
      lhs.day < rhs.day ||
      lhs.hour < rhs.hour ||
      lhs.minute < rhs.minute ||
      lhs.second < rhs.second
  }
}

extension Int? {
  static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs ?? 0) < (rhs ?? 0)
  }
}
