//
//  File.swift
//
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Foundation

/// The position of an astral body as seen from earth
internal struct AstralBodyPosition: Equatable {
  internal var right_ascension: Radians
  internal var declination: Radians
  internal var distance: Radians

  internal static let zero = AstralBodyPosition(right_ascension: 0, declination: 0, distance: 0)
}
