//
//  File.swift
//
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Foundation

// MARK: - Angle

struct Angle: Equatable, Comparable {

  // MARK: Lifecycle

  init(degrees: Double) {
    self.degrees = degrees
    radians = Angle.deg2rad(degrees)
  }

  init(radians: Double) {
    self.radians = radians
    degrees = Angle.rad2deg(radians)
  }

  // MARK: Internal

  let degrees: Double
  let radians: Double

  static func < (lhs: Angle, rhs: Angle) -> Bool {
    lhs.radians < rhs.radians
  }

  static func degrees(_ degrees: Double) -> Angle {
    .init(degrees: degrees)
  }

  static func radians(_ radians: Double) -> Angle {
    .init(radians: radians)
  }

  static func deg2rad(_ number: Double) -> Double {
    number * .pi / 180
  }

  static func rad2deg(_ number: Double) -> Double {
    number * 180 / .pi
  }
}

func radians(_ number: Double) -> Double {
  number * .pi / 180
}

func degrees(_ number: Double) -> Double {
  number * 180 / .pi
}
