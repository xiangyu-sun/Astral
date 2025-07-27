//
//  File.swift
//
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Foundation

/// The position of an astral body as seen from earth
struct AstralBodyPosition: Equatable {
  var right_ascension: Radians
  var declination: Radians
  var distance: Radians

  static let zero = AstralBodyPosition(right_ascension: 0, declination: 0, distance: 0)
}
