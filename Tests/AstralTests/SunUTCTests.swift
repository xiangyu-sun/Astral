//
//  SunUTCTests.swift
//
//
//  Created by Xiangyu Sun on 31/1/23.
//

import XCTest
@testable import Astral

final class SunUTCTests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testSun() throws {
    let data: [(DateComponents, DateComponents)] = [
      (.date(2015, 12, 1), .datetime(2015, 12, 1, 7, 4)),
      (.date(2015, 12, 2), .datetime(2015, 12, 2, 7, 5)),
      (.date(2015, 12, 3), .datetime(2015, 12, 3, 7, 6)),
      (.date(2015, 12, 12), .datetime(2015, 12, 12, 7, 16)),
      (.date(2015, 12, 25), .datetime(2015, 12, 25, 7, 25)),
    ]

    for (day, down) in data {
      let dawn_calc = try sun(observer: .london, date: day)["dawn"]!

      XCTAssertEqual(dawn_calc, down, accuracy: DateComponents(second: 90))
    }
  }

  func testDawnCivil() throws {
    let data: [(DateComponents, DateComponents)] = [
      (.date(2015, 12, 1), .datetime(2015, 12, 1, 7, 4)),
      (.date(2015, 12, 2), .datetime(2015, 12, 2, 7, 5)),
      (.date(2015, 12, 3), .datetime(2015, 12, 3, 7, 6)),
      (.date(2015, 12, 12), .datetime(2015, 12, 12, 7, 16)),
      (.date(2015, 12, 25), .datetime(2015, 12, 25, 7, 25)),
    ]

    for (day, down) in data {
      let dawn_calc = try dawn(observer: .london, date: day, depression: .civil)

      XCTAssertEqual(dawn_calc, down, accuracy: DateComponents(second: 90))
    }
  }

  func testDawnNautical() throws {
    let data: [(DateComponents, DateComponents)] = [
      (.date(2015, 12, 1), .datetime(2015, 12, 1, 6, 22)),
      (.date(2015, 12, 2), .datetime(2015, 12, 2, 6, 23)),
      (.date(2015, 12, 3), .datetime(2015, 12, 3, 6, 24)),
      (.date(2015, 12, 12), .datetime(2015, 12, 12, 6, 33)),
      (.date(2015, 12, 25), .datetime(2015, 12, 25, 6, 41)),
    ]

    for (day, down) in data {
      let dawn_calc = try dawn(observer: .london, date: day, depression: .other(12))

      XCTAssertEqual(dawn_calc, down, accuracy: DateComponents(second: 90))
    }
  }

  func testDawnAstronomical() throws {
    let data: [(DateComponents, DateComponents)] = [
      (.date(2015, 12, 1), .datetime(2015, 12, 1, 5, 41)),
      (.date(2015, 12, 2), .datetime(2015, 12, 2, 5, 42)),
      (.date(2015, 12, 3), .datetime(2015, 12, 3, 5, 44)),
      (.date(2015, 12, 12), .datetime(2015, 12, 12, 5, 52)),
      (.date(2015, 12, 25), .datetime(2015, 12, 25, 6, 1)),
    ]

    for (day, down) in data {
      let dawn_calc = try dawn(observer: .london, date: day, depression: .other(18))

      XCTAssertEqual(dawn_calc, down, accuracy: DateComponents(second: 90))
    }
  }

  func testSunrise() throws {
    let data: [(DateComponents, DateComponents)] = [
      (.date(2015, 1, 1), .datetime(2015, 1, 1, 8, 6)),
      (.date(2015, 12, 1), .datetime(2015, 12, 1, 7, 43)),
      (.date(2015, 12, 2), .datetime(2015, 12, 2, 7, 45)),
      (.date(2015, 12, 3), .datetime(2015, 12, 3, 7, 46)),
      (.date(2015, 12, 12), .datetime(2015, 12, 12, 7, 56)),
      (.date(2015, 12, 25), .datetime(2015, 12, 25, 8, 5)),
    ]

    for (day, down) in data {
      let dawn_calc = try sunrise(observer: .london, date: day)

      XCTAssertEqual(dawn_calc, down, accuracy: DateComponents(second: 90))
    }
  }

  func testSunset() throws {
    let data: [(DateComponents, DateComponents)] = [
      (.date(2015, 1, 1), .datetime(2015, 1, 1, 16, 1)),
      (.date(2015, 12, 1), .datetime(2015, 12, 1, 15, 55)),
      (.date(2015, 12, 2), .datetime(2015, 12, 2, 15, 54)),
      (.date(2015, 12, 3), .datetime(2015, 12, 3, 15, 54)),
      (.date(2015, 12, 12), .datetime(2015, 12, 12, 15, 51)),
      (.date(2015, 12, 25), .datetime(2015, 12, 25, 15, 55)),
    ]

    for (day, down) in data {
      let dawn_calc = try sunset(observer: .london, date: day)

      XCTAssertEqual(dawn_calc, down, accuracy: DateComponents(second: 90))
    }
  }

  func testDusk() throws {
    let data: [(DateComponents, DateComponents)] = [
      (.date(2015, 12, 1), .datetime(2015, 12, 1, 16, 34)),
      (.date(2015, 12, 2), .datetime(2015, 12, 2, 16, 34)),
      (.date(2015, 12, 3), .datetime(2015, 12, 3, 16, 33)),
      (.date(2015, 12, 12), .datetime(2015, 12, 12, 16, 31)),
      (.date(2015, 12, 25), .datetime(2015, 12, 25, 16, 36)),
    ]

    for (day, down) in data {
      let dawn_calc = try dusk(observer: .london, date: day)

      XCTAssertEqual(dawn_calc, down, accuracy: DateComponents(second: 90))
    }
  }

  func testDuskNautical() throws {
    let data: [(DateComponents, DateComponents)] = [
      (.date(2015, 12, 1), .datetime(2015, 12, 1, 17, 16)),
      (.date(2015, 12, 2), .datetime(2015, 12, 2, 17, 16)),
      (.date(2015, 12, 3), .datetime(2015, 12, 3, 17, 16)),
      (.date(2015, 12, 12), .datetime(2015, 12, 12, 17, 14)),
      (.date(2015, 12, 25), .datetime(2015, 12, 25, 17, 19)),
    ]

    for (day, expected) in data {
      let actual = try dusk(observer: .london, date: day, depression: .other(12))

      XCTAssertEqual(actual, expected, accuracy: DateComponents(second: 90))
    }
  }

  func testNoon() throws {
    let data: [(DateComponents, DateComponents)] = [
      (.date(2015, 12, 1), .datetime(2015, 12, 1, 11, 49)),
      (.date(2015, 12, 2), .datetime(2015, 12, 2, 11, 49)),
      (.date(2015, 12, 3), .datetime(2015, 12, 3, 11, 50)),
      (.date(2015, 12, 12), .datetime(2015, 12, 12, 11, 54)),
      (.date(2015, 12, 25), .datetime(2015, 12, 25, 12, 00)),
    ]

    for (day, expected) in data {
      let actual = noon(observer: .london, date: day)

      XCTAssertEqual(actual, expected, accuracy: DateComponents(second: 90))
    }
  }

  func testMidnight() throws {
    let data: [(DateComponents, DateComponents)] = [
      (.date(2016, 2, 18), .datetime(2016, 2, 18, 0, 14)),
      (.date(2016, 10, 26), .datetime(2016, 10, 25, 23, 44)),
    ]

    for (day, expected) in data {
      let actual = midnight(observer: .london, date: day)

      XCTAssertEqual(actual, expected, accuracy: DateComponents(second: 90))
    }
  }

  func testTwilightSunrising() throws {
    let data: [(DateComponents, (DateComponents, DateComponents))] = [
      (
        .date(2019, 8, 29),
        (
          .datetime(2019, 8, 29, 4, 32),
          .datetime(2019, 8, 29, 5, 8))),
    ]

    for (day, expected) in data {
      let actual = try twilight(observer: .london, date: day)

      XCTAssertEqual(actual.0, expected.0, accuracy: DateComponents(second: 90))
      XCTAssertEqual(actual.1, expected.1, accuracy: DateComponents(second: 90))
    }
  }

  func testTwilightSunSetting() throws {
    let data: [(DateComponents, (DateComponents, DateComponents))] = [
      (
        .date(2019, 8, 29),
        (
          .datetime(2019, 8, 29, 18, 54),
          .datetime(2019, 8, 29, 19, 30))),
    ]

    for (day, expected) in data {
      let actual = try twilight(observer: .london, date: day, direction: .setting)

      XCTAssertEqual(actual.0, expected.0, accuracy: DateComponents(second: 90))
      XCTAssertEqual(actual.1, expected.1, accuracy: DateComponents(second: 90))
    }
  }

  func testRahu() throws {
    let data: [(DateComponents, (DateComponents, DateComponents))] = [
      (
        .date(2015, 12, 1),
        (
          .datetime(2015, 12, 1, 9, 17),
          .datetime(2015, 12, 1, 10, 35))),
      (
        .date(2015, 12, 2),
        (
          .datetime(2015, 12, 2, 6, 40),
          .datetime(2015, 12, 2, 7, 58))),
    ]

    for (day, expected) in data {
      let actual = try rahukaalam(observer: .newDelhi, date: day)

      XCTAssertEqual(actual.0, expected.0, accuracy: DateComponents(hour: 2))
      XCTAssertEqual(actual.1, expected.1, accuracy: DateComponents(hour: 2))
    }
  }

  func testSolarAltitude() throws {
    let data: [(DateComponents, Double)] = [
      (.datetime(2015, 12, 14, 11, 0, 0), 14.381311),
      (.datetime(2015, 12, 14, 20, 1, 0), -37.3710156),
    ]

    for (day, expected) in data {
      let elevation = elevation(observer: .london, dateandtime: day)
      XCTAssertEqual(expected, elevation, accuracy: 0.5)
    }
  }

  func testSolarAzimuth() throws {
    let data: [(DateComponents, Double)] = [
      (.datetime(2015, 12, 14, 11, 0, 0), 166.9676),
      (.datetime(2015, 12, 14, 20, 1, 0), 279.39927311745),
    ]

    for (day, expected) in data {
      let elevation = azimuth(observer: .london, dateandtime: day)
      XCTAssertEqual(expected, elevation, accuracy: 0.5)
    }
  }

  func testSolarZenith_London() throws {
    let data: [(DateComponents, Double)] = [
      (.datetime(2021, 10, 10, 6, 0, 0), 93.25029),
      (.datetime(2021, 10, 10, 7, 0, 0), 84.01829),
      (.datetime(2021, 10, 10, 18, 0, 0), 97.45711),
      (.datetime(2020, 2, 3, 10, 37, 0), 71),
    ]

    for (day, expected) in data {
      let elevation = zenith(observer: .london, dateandtime: day)
      XCTAssertEqual(expected, elevation, accuracy: 0.5)
    }
  }

  func testSolarZenith_Riyadh() throws {
    let data: [(DateComponents, Double)] = [
      (.datetime(2022, 5, 1, 14, 0, 0), 72.40508),
      (.datetime(2022, 5, 1, 21, 0, 0), 139.58708),
    ]

    for (day, expected) in data {
      let actual = zenith(observer: .riyadh, dateandtime: day)
      XCTAssertEqual(expected, actual, accuracy: 0.5)
    }
  }

  func test_TimeAtElevation_SunRising() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: 6, date: d, direction: SunDirection.rising)
    let cdt = DateComponents.datetime(2016, 1, 4, 9, 5, 0)
    // Use error of 5 minutes as website has a rather coarse accuracy
    XCTAssertEqual(dt, cdt, accuracy: DateComponents(minute: 5))
  }

  func test_TimeAtElevation_SunSetting() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: 6, date: d, direction: SunDirection.setting)
    let cdt = DateComponents.datetime(2016, 1, 4, 15, 5, 48)
    // Use error of 5 minutes as website has a rather coarse accuracy
    XCTAssertEqual(dt, cdt, accuracy: DateComponents(minute: 5))
  }

  func test_TimeAtElevation_Greater90() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: 166, date: d, direction: SunDirection.setting)
    let cdt = DateComponents.datetime(2016, 1, 4, 13, 20, 0)
    // Use error of 5 minutes as website has a rather coarse accuracy
    XCTAssertEqual(dt, cdt, accuracy: DateComponents(minute: 5))
  }

  func test_TimeAtElevation_Greater180() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: 186, date: d, direction: SunDirection.rising)
    let cdt = DateComponents.datetime(2016, 1, 4, 16, 44, 42)
    // Use error of 5 minutes as website has a rather coarse accuracy
    XCTAssertEqual(dt, cdt, accuracy: DateComponents(minute: 5))
  }

  func test_TimeAtElevation_SunriseBelowHorizon() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: -18, date: d, direction: SunDirection.rising)
    let cdt = DateComponents.datetime(2016, 1, 4, 6, 0, 0)
    // Use error of 5 minutes as website has a rather coarse accuracy
    XCTAssertEqual(dt, cdt, accuracy: DateComponents(minute: 5))
  }

  func test_TimeAtElevation_BadElevation() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: -18, date: d, direction: SunDirection.rising)
    let cdt = DateComponents.datetime(2016, 1, 4, 6, 0, 0)
    // Use error of 5 minutes as website has a rather coarse accuracy
    XCTAssertEqual(dt, cdt, accuracy: DateComponents(minute: 5))
  }

  func test_Daylight() throws {
    let d = DateComponents.date(2016, 1, 6)
    let dt = try daylight(observer: .london, date: d)
    let cstart = DateComponents.datetime(2016, 1, 6, 8, 5, 0)
    let cend = DateComponents.datetime(2016, 1, 6, 16, 7, 0)

    XCTAssertEqual(dt.0, cstart, accuracy: DateComponents(minute: 2))
    XCTAssertEqual(dt.1, cend, accuracy: DateComponents(minute: 2))
  }

  func test_NightTime() throws {
    let d = DateComponents.date(2016, 1, 6)
    let dt = try night(observer: .london, date: d)
    let cstart = DateComponents.datetime(2016, 1, 6, 16, 46)
    let cend = DateComponents.datetime(2016, 1, 7, 7, 25)

    XCTAssertEqual(dt.0, cstart, accuracy: DateComponents(minute: 5))
    XCTAssertEqual(dt.1, cend, accuracy: DateComponents(minute: 5))
  }
}
