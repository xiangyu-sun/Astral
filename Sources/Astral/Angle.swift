//
//  File.swift
//
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Foundation

// MARK: - Angle

public struct Angle: Equatable, Comparable {

  // MARK: Lifecycle

  public init(degrees: Double) {
    self.degrees = degrees
    radians = Angle.deg2rad(degrees)
  }

  public init(radians: Double) {
    self.radians = radians
    degrees = Angle.rad2deg(radians)
  }

  // MARK: Internal

  public let degrees: Double
  public let radians: Double

  public static func < (lhs: Angle, rhs: Angle) -> Bool {
    lhs.radians < rhs.radians
  }

  public static func degrees(_ degrees: Double) -> Angle {
    .init(degrees: degrees)
  }

  public static func radians(_ radians: Double) -> Angle {
    .init(radians: radians)
  }

  static func deg2rad(_ number: Double) -> Double {
    number * .pi / 180
  }

  static func rad2deg(_ number: Double) -> Double {
    number * 180 / .pi
  }
}

public func radians(_ number: Double) -> Double {
  number * .pi / 180
}

public func degrees(_ number: Double) -> Double {
  number * 180 / .pi
}
