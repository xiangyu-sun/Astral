//
//  JulianTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Foundation
import Numerics
import Testing
@testable import Astral

@Suite("Julian Day Calculations", .tags(.time, .conversion, .fast))
struct JulianTests {

  @Test(
    "Julian day calculation for default calendar",
    .tags(.unit, .accuracy),
    arguments: zip(
      [
        DateComponents.datetime(1957, 10, 4, 19, 26, 24),
        DateComponents.date(2000, 1, 1),
        DateComponents.date(2012, 1, 1),
        DateComponents.date(2013, 1, 1),
        DateComponents.date(2023, 1, 21),
        DateComponents.date(2013, 6, 1),
        DateComponents.date(1867, 2, 1),
        DateComponents.date(3200, 11, 14),
        DateComponents.datetime(2000, 1, 1, 12, 0, 0),
        DateComponents.datetime(1999, 1, 1, 0, 0, 0),
        DateComponents.datetime(1987, 1, 27, 0, 0, 0),
        DateComponents.date(1987, 6, 19),
        DateComponents.datetime(1987, 6, 19, 12, 0, 0),
        DateComponents.datetime(1988, 1, 27, 0, 0, 0),
        DateComponents.date(1988, 6, 19),
        DateComponents.datetime(1988, 6, 19, 12, 0, 0),
        DateComponents.datetime(1900, 1, 1, 0, 0, 0),
        DateComponents.datetime(1600, 1, 1, 0, 0, 0),
        DateComponents.datetime(1600, 12, 31, 0, 0, 0),
        DateComponents.datetime(2012, 1, 1, 12),
        DateComponents.date(2013, 1, 1),
        DateComponents.date(2013, 6, 1),
        DateComponents.date(1867, 2, 1),
        DateComponents.date(3200, 11, 14),
      ],
      [
        2436116.31,
        2451544.5,
        2455927.5,
        2456293.5,
        2459965.5,
        2456444.5,
        2402998.5,
        2890153.5,
        2451545.0,
        2451179.5,
        2446_822.5,
        2446_965.5,
        2446_966.0,
        2447_187.5,
        2447_331.5,
        2447_332.0,
        2415_020.5,
        2305_447.5,
        2305_812.5,
        2455928.0,
        2456293.5,
        2456444.5,
        2402998.5,
        2890153.5,
      ]))
  func defaultCalendar(day: DateComponents, expectedJD: Double) {
    #expect(julianDay(at: day) == expectedJD)
  }

  @Test(
    "Julian day calculation for Julian calendar",
    .tags(.unit, .accuracy),
    arguments: zip(
      [
        DateComponents.datetime(837, 4, 10, 7, 12, 0),
        DateComponents.datetime(333, 1, 27, 12, 0, 0),
      ],
      [
        2026_871.8,
        1842_713.0,
      ]))
  func julianCalendar(day: DateComponents, expectedJD: Double) {
    #expect(julianDay(at: day, calendar: .init(identifier: .chinese)) == expectedJD)
  }

  @Test(
    "Julian day to DateComponents conversion",
    .tags(.unit, .accuracy),
    arguments: zip(
      [
        2026_871.8,
        1842_713.0,
      ],
      [
        DateComponents.datetime(837, 4, 10, 7, 12, 0),
        DateComponents.datetime(333, 1, 27, 12, 0, 0),
      ]))
  func julianDayToDateTime(jd: Double, expectedComponents: DateComponents) {
    #expect(julianDayToComponent(jd: jd) == expectedComponents)
  }

  @Test(
    "Julian day to century conversion",
    .tags(.unit, .accuracy),
    arguments: zip(
      [
        2455927.5,
        2456293.5,
        2456444.5,
        2402998.5,
        2890153.5,
      ],
      [
        0.119986311,
        0.130006845,
        0.134140999,
        -1.329130732,
        12.00844627,
      ]))
  func julianDayToCenturyConversion(jd: Double, expectedJC: Double) {
    let result = Astral.julianDayToCentury(julianDay: jd)
    #expect(abs(result - expectedJC) < 0.1)
  }

  @Test(
    "Julian century to day conversion",
    .tags(.unit, .accuracy),
    arguments: zip(
      [
        0.119986311,
        0.130006845,
        0.134140999,
        -1.329130732,
        12.00844627,
      ],
      [
        2455927.5,
        2456293.5,
        2456444.5,
        2402998.5,
        2890153.5,
      ]))
  func julianCenturyToDayConversion(jc: Double, expectedJD: Double) {
    let result = Astral.julianDCenturyToDay(julianCentury: jc)
    #expect(abs(result - expectedJD) < 0.1)
  }

}
