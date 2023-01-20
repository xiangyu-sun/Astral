//
//  File.swift
//  
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Foundation

struct Angle: Equatable, Comparable {
  static func < (lhs: Angle, rhs: Angle) -> Bool {
    lhs.radians < rhs.radians
  }
  
  
  static func degrees(_ degrees :Double) -> Angle {
    .init(degrees: degrees)
  }
  
  static func radians(_ radians: Double) -> Angle {
    .init(radians: radians)
  }
  
  let degrees: Double
  let radians: Double
  
  init(degrees: Double) {
    self.degrees = degrees
    self.radians = Angle.deg2rad(degrees)
  }
  
  init(radians: Double) {
    self.radians = radians
    self.degrees = Angle.rad2deg(radians)
  }
  
  static func deg2rad(_ number: Double) -> Double {
      return number * .pi / 180
  }

  static func rad2deg(_ number: Double) -> Double {
      return number * 180 / .pi
  }
}

func radians(_ number: Double) -> Double {
    return number * .pi / 180
}


func degrees(_ number: Double) -> Double {
    return number * 180 / .pi
}
