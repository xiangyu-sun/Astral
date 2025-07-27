//
//  JulianTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Foundation
import Testing
@testable import Astral

@Suite("Julian Day Tests")
struct JulianTests {

  let data: [(DateComponents, Double)] = [
    (.datetime(1957, 10, 4, 19, 26, 24), 2436116.31),
    (.date(2000, 1, 1), 2451544.5),
    (.date(2012, 1, 1), 2455927.5),
    (.date(2013, 1, 1), 2456293.5),
    (.date(2023, 1, 21), 2459965.5),
    (.date(2013, 6, 1), 2456444.5),
    (.date(1867, 2, 1), 2402998.5),
    (.date(3200, 11, 14), 2890153.5),
    (.datetime(2000, 1, 1, 12, 0, 0), 2451545.0),
    (.datetime(1999, 1, 1, 0, 0, 0), 2451179.5),
    (.datetime(1987, 1, 27, 0, 0, 0), 2446_822.5),
    (.date(1987, 6, 19), 2446_965.5),
    (.datetime(1987, 6, 19, 12, 0, 0), 2446_966.0),
    (.datetime(1988, 1, 27, 0, 0, 0), 2447_187.5),
    (.date(1988, 6, 19), 2447_331.5),
    (.datetime(1988, 6, 19, 12, 0, 0), 2447_332.0),
    (.datetime(1900, 1, 1, 0, 0, 0), 2415_020.5),
    (.datetime(1600, 1, 1, 0, 0, 0), 2305_447.5),
    (.datetime(1600, 12, 31, 0, 0, 0), 2305_812.5),
    (.datetime(2012, 1, 1, 12), 2455928.0),
    (.date(2013, 1, 1), 2456293.5),
    (.date(2013, 6, 1), 2456444.5),
    (.date(1867, 2, 1), 2402998.5),
    (.date(3200, 11, 14), 2890153.5),
  ]

  let julianCalenderData: [(DateComponents, Double)] = [
    (.datetime(837, 4, 10, 7, 12, 0), 2026_871.8),
    (.datetime(333, 1, 27, 12, 0, 0), 1842_713.0),
  ]

  let julianDayToDateTimeCalenderData: [(Double, DateComponents)] = [
    (2026_871.8, .datetime(837, 4, 10, 7, 12, 0)),
    (1842_713.0, .datetime(333, 1, 27, 12, 0, 0)),
  ]

  let julianCenturyData: [(Double, Double)] = [
    (2455927.5, 0.119986311),
    (2456293.5, 0.130006845),
    (2456444.5, 0.134140999),
    (2402998.5, -1.329130732),
    (2890153.5, 12.00844627),
  ]
  let julianCenturyToDayData: [(Double, Double)] = [
    (0.119986311, 2455927.5),
    (0.130006845, 2456293.5),
    (0.134140999, 2456444.5),
    (-1.329130732, 2402998.5),
    (12.00844627, 2890153.5),
  ]

  @Test("Julian day for default calendar")
  func testDefaultCalendar() throws {
    for (day, jd) in data {
      #expect(julianDay(at: day) == jd)
    }
  }

  @Test("Julian day for Julian calendar")
  func testJulianCalendar() throws {
    for (day, jd) in julianCalenderData {
      #expect(julianDay(at: day, calendar: .init(identifier: .chinese)) == jd)
    }
  }

  @Test("Julian day to date time conversion")
  func testJulianDayToDateTime() throws {
    for (jd, components) in julianDayToDateTimeCalenderData {
      #expect(julianDayToComponent(jd: jd) == components)
    }
  }

  @Test("Julian day to century conversion")
  func test_JulianCentury() {
    for (jd, jc) in julianCenturyData {
      #expect(julianDayToCentury(julianDay: jd).isApproximatelyEqual(to: jc, absoluteTolerance: 0.1))
    }
  }

  @Test("Julian century to day conversion")
  func test_JulianCenturyToDay() {
    for (jc, jd) in julianCenturyToDayData {
      #expect(julianDCenturyToDay(julianCentury: jc).isApproximatelyEqual(to: jd, absoluteTolerance: 0.1))
    }
  }

}
