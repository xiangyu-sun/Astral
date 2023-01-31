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
    let calendar = lhs.calendar ?? .autoupdatingCurrent

    return calendar.compare(calendar.date(from: lhs)!, to: calendar.date(from: rhs)!, toGranularity: .second) == .orderedAscending
  }
}

extension Int? {
  static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs ?? 0) < (rhs ?? 0)
  }
}
