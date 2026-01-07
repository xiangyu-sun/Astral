//
//  SunLocalTests.swift
//
//
//  Created by Xiangyu Sun on 31/1/23.
//

import Foundation
import Testing
@testable import Astral

@Suite("Sun Local Timezone Tests")
struct SunLocalTests {

  @Test(
    "Dawn calculation in local timezone",
    arguments: zip(
      [
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
        DateComponents.date(2015, 12, 3),
        DateComponents.date(2015, 12, 12),
        DateComponents.date(2015, 12, 25),
      ],
      [
        DateComponents.datetime(2015, 12, 1, 6, 30, 0, TimeZone(abbreviation: "GMT+5:30")!),
        DateComponents.datetime(2015, 12, 2, 6, 31, 0, TimeZone(abbreviation: "GMT+5:30")!),
        DateComponents.datetime(2015, 12, 3, 6, 31, 0, TimeZone(abbreviation: "GMT+5:30")!),
        DateComponents.datetime(2015, 12, 12, 6, 38, 0, TimeZone(abbreviation: "GMT+5:30")!),
        DateComponents.datetime(2015, 12, 25, 6, 45, 0, TimeZone(abbreviation: "GMT+5:30")!),
      ]))
  func dawnCalculationLocalTimezone(day: DateComponents, expectedDawn: DateComponents) throws {
    let dheli = TimeZone(abbreviation: "GMT+5:30")!
    let dawnCalc = try sun(
      observer: .newDelhi,
      date: day,
      dawn_dusk_depression: Depression(rawValue: 6),
      tzinfo: dheli)["dawn"]!

    // Compare with 90 second accuracy
    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(dawnCalc, expectedDawn, accuracy: accuracy))
  }

}
