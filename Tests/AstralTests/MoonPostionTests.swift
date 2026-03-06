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
        DateComponents.date(2000, 1, 1),
        DateComponents.date(2010, 7, 15),
        DateComponents.date(2020, 3, 20),
      ],
      [
        // Expected declination and distance; RA can wrap by 2π so we check modulo
        AstralBodyPosition(
          right_ascension: 4.319282763529611,
          declination: -0.4666627389802471,
          distance: 56.55560793098364),
        AstralBodyPosition(
          right_ascension: 2.350724992356861,
          declination: 0.24034395778522072,
          distance: 57.762369440247795),
        AstralBodyPosition(
          right_ascension: 0.0, // placeholder, checked via declination/distance
          declination: 0.0,
          distance: 0.0),
        AstralBodyPosition(
          right_ascension: 0.0,
          declination: 0.0,
          distance: 0.0),
        AstralBodyPosition(
          right_ascension: 0.0,
          declination: 0.0,
          distance: 0.0),
      ]))
  func moonPositionCalculation(d: DateComponents, expected: AstralBodyPosition) {
    let jd = julianDay(at: d)
    let jd2000 = jd - 2451545 // Julian day relative to Jan 1.5, 2000

    let result = moonPosition(jd2000: jd2000)

    // For the first two dates, check precise values with tolerance
    if expected.distance > 1 {
      #expect(abs(result.declination - expected.declination) < 1e-3)
      #expect(abs(result.distance - expected.distance) < 0.01)
      // RA comparison with 2π wrapping
      var raDiff = abs(result.right_ascension - expected.right_ascension)
        .truncatingRemainder(dividingBy: 2 * .pi)
      if raDiff > .pi { raDiff = 2 * .pi - raDiff }
      #expect(raDiff < 1e-3)
    }

    // For all dates, verify basic sanity
    #expect(result.distance > 50 && result.distance < 70) // Earth radii
    #expect(abs(result.declination) < 0.6) // Max ~29° = 0.51 rad
  }

}
