//
//  MoonPostionTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Foundation
import Testing
@testable import Astral

@Suite("Moon Position Tests")
struct MoonPostionTests {

  @Test(
    "Moon position calculation for historical dates",
    arguments: zip(
      [
        DateComponents.date(1969, 6, 28),
        DateComponents.date(1992, 4, 12),
      ],
      [
        AstralBodyPosition(
          right_ascension: -1.9638999378692186,
          declination: -0.4666623303219141,
          distance: 56.55564052259119),
        AstralBodyPosition(
          right_ascension: -3.932462849957415,
          declination: 0.24034553813386558,
          distance: 57.76236323127602),
      ]))
  func moonPositionCalculation(d: DateComponents, expected: AstralBodyPosition) {
    let jd = julianDay(at: d)
    let jd2000 = jd - 2451545 // Julian day relative to Jan 1.5, 2000

    let result = moonPosition(jd2000: jd2000)
    #expect(result == expected)
  }

}
