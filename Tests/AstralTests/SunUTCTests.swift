//
//  SunUTCTests.swift
//
//
//  Created by Xiangyu Sun on 31/1/23.
//

import Foundation
import Testing
@testable import Astral

@Suite("Sun UTC Calculation Tests")
struct SunUTCTests {

  @Test(
    "Sun function returns correct dawn time",
    arguments: zip(
      [
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
        DateComponents.date(2015, 12, 3),
        DateComponents.date(2015, 12, 12),
        DateComponents.date(2015, 12, 25),
      ],
      [
        DateComponents.datetime(2015, 12, 1, 7, 4),
        DateComponents.datetime(2015, 12, 2, 7, 5),
        DateComponents.datetime(2015, 12, 3, 7, 6),
        DateComponents.datetime(2015, 12, 12, 7, 16),
        DateComponents.datetime(2015, 12, 25, 7, 25),
      ]))
  func sunDawnTime(day: DateComponents, expected: DateComponents) throws {
    let dawnCalc = try sun(observer: .london, date: day)["dawn"]!

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(dawnCalc, expected, accuracy: accuracy))
  }

  @Test(
    "Dawn calculation with civil depression",
    arguments: zip(
      [
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
        DateComponents.date(2015, 12, 3),
        DateComponents.date(2015, 12, 12),
        DateComponents.date(2015, 12, 25),
      ],
      [
        DateComponents.datetime(2015, 12, 1, 7, 4),
        DateComponents.datetime(2015, 12, 2, 7, 5),
        DateComponents.datetime(2015, 12, 3, 7, 6),
        DateComponents.datetime(2015, 12, 12, 7, 16),
        DateComponents.datetime(2015, 12, 25, 7, 25),
      ]))
  func dawnCivil(day: DateComponents, expected: DateComponents) throws {
    let dawnCalc = try dawn(observer: .london, date: day, depression: .civil)

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(dawnCalc, expected, accuracy: accuracy))
  }

  @Test(
    "Dawn calculation with nautical depression",
    arguments: zip(
      [
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
        DateComponents.date(2015, 12, 3),
        DateComponents.date(2015, 12, 12),
        DateComponents.date(2015, 12, 25),
      ],
      [
        DateComponents.datetime(2015, 12, 1, 6, 22),
        DateComponents.datetime(2015, 12, 2, 6, 23),
        DateComponents.datetime(2015, 12, 3, 6, 24),
        DateComponents.datetime(2015, 12, 12, 6, 33),
        DateComponents.datetime(2015, 12, 25, 6, 41),
      ]))
  func dawnNautical(day: DateComponents, expected: DateComponents) throws {
    let dawnCalc = try dawn(observer: .london, date: day, depression: .other(12))

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(dawnCalc, expected, accuracy: accuracy))
  }

  @Test(
    "Dawn calculation with astronomical depression",
    arguments: zip(
      [
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
        DateComponents.date(2015, 12, 3),
        DateComponents.date(2015, 12, 12),
        DateComponents.date(2015, 12, 25),
      ],
      [
        DateComponents.datetime(2015, 12, 1, 5, 41),
        DateComponents.datetime(2015, 12, 2, 5, 42),
        DateComponents.datetime(2015, 12, 3, 5, 44),
        DateComponents.datetime(2015, 12, 12, 5, 52),
        DateComponents.datetime(2015, 12, 25, 6, 1),
      ]))
  func dawnAstronomical(day: DateComponents, expected: DateComponents) throws {
    let dawnCalc = try dawn(observer: .london, date: day, depression: .other(18))

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(dawnCalc, expected, accuracy: accuracy))
  }

  @Test(
    "Sunrise calculation",
    arguments: zip(
      [
        DateComponents.date(2015, 1, 1),
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
        DateComponents.date(2015, 12, 3),
        DateComponents.date(2015, 12, 12),
        DateComponents.date(2015, 12, 25),
      ],
      [
        DateComponents.datetime(2015, 1, 1, 8, 6),
        DateComponents.datetime(2015, 12, 1, 7, 43),
        DateComponents.datetime(2015, 12, 2, 7, 45),
        DateComponents.datetime(2015, 12, 3, 7, 46),
        DateComponents.datetime(2015, 12, 12, 7, 56),
        DateComponents.datetime(2015, 12, 25, 8, 5),
      ]))
  func sunriseCalculation(day: DateComponents, expected: DateComponents) throws {
    let sunriseCalc = try sunrise(observer: .london, date: day)

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(sunriseCalc, expected, accuracy: accuracy))
  }

  @Test(
    "Sunset calculation",
    arguments: zip(
      [
        DateComponents.date(2015, 1, 1),
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
        DateComponents.date(2015, 12, 3),
        DateComponents.date(2015, 12, 12),
        DateComponents.date(2015, 12, 25),
      ],
      [
        DateComponents.datetime(2015, 1, 1, 16, 1),
        DateComponents.datetime(2015, 12, 1, 15, 55),
        DateComponents.datetime(2015, 12, 2, 15, 54),
        DateComponents.datetime(2015, 12, 3, 15, 54),
        DateComponents.datetime(2015, 12, 12, 15, 51),
        DateComponents.datetime(2015, 12, 25, 15, 55),
      ]))
  func sunsetCalculation(day: DateComponents, expected: DateComponents) throws {
    let sunsetCalc = try sunset(observer: .london, date: day)

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(sunsetCalc, expected, accuracy: accuracy))
  }

  @Test(
    "Dusk calculation",
    arguments: zip(
      [
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
        DateComponents.date(2015, 12, 3),
        DateComponents.date(2015, 12, 12),
        DateComponents.date(2015, 12, 25),
      ],
      [
        DateComponents.datetime(2015, 12, 1, 16, 34),
        DateComponents.datetime(2015, 12, 2, 16, 34),
        DateComponents.datetime(2015, 12, 3, 16, 33),
        DateComponents.datetime(2015, 12, 12, 16, 31),
        DateComponents.datetime(2015, 12, 25, 16, 36),
      ]))
  func duskCalculation(day: DateComponents, expected: DateComponents) throws {
    let duskCalc = try dusk(observer: .london, date: day)

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(duskCalc, expected, accuracy: accuracy))
  }

  @Test(
    "Dusk calculation with nautical depression",
    arguments: zip(
      [
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
        DateComponents.date(2015, 12, 3),
        DateComponents.date(2015, 12, 12),
        DateComponents.date(2015, 12, 25),
      ],
      [
        DateComponents.datetime(2015, 12, 1, 17, 16),
        DateComponents.datetime(2015, 12, 2, 17, 16),
        DateComponents.datetime(2015, 12, 3, 17, 16),
        DateComponents.datetime(2015, 12, 12, 17, 14),
        DateComponents.datetime(2015, 12, 25, 17, 19),
      ]))
  func duskNautical(day: DateComponents, expected: DateComponents) throws {
    let actual = try dusk(observer: .london, date: day, depression: .other(12))

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(actual, expected, accuracy: accuracy))
  }

  @Test(
    "Solar noon calculation",
    arguments: zip(
      [
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
        DateComponents.date(2015, 12, 3),
        DateComponents.date(2015, 12, 12),
        DateComponents.date(2015, 12, 25),
      ],
      [
        DateComponents.datetime(2015, 12, 1, 11, 49),
        DateComponents.datetime(2015, 12, 2, 11, 49),
        DateComponents.datetime(2015, 12, 3, 11, 50),
        DateComponents.datetime(2015, 12, 12, 11, 54),
        DateComponents.datetime(2015, 12, 25, 12, 00),
      ]))
  func noonCalculation(day: DateComponents, expected: DateComponents) {
    let actual = noon(observer: .london, date: day)

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(actual, expected, accuracy: accuracy))
  }

  @Test(
    "Solar midnight calculation",
    arguments: zip(
      [
        DateComponents.date(2016, 2, 18),
        DateComponents.date(2016, 10, 26),
      ],
      [
        DateComponents.datetime(2016, 2, 18, 0, 14),
        DateComponents.datetime(2016, 10, 25, 23, 44),
      ]))
  func midnightCalculation(day: DateComponents, expected: DateComponents) {
    let actual = midnight(observer: .london, date: day)

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(actual, expected, accuracy: accuracy))
  }

  @Test("Twilight calculation for sun rising")
  func twilightSunRising() throws {
    let day = DateComponents.date(2019, 8, 29)
    let expected1 = DateComponents.datetime(2019, 8, 29, 4, 32)
    let expected2 = DateComponents.datetime(2019, 8, 29, 5, 8)

    let actual = try twilight(observer: .london, date: day)

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(actual.0, expected1, accuracy: accuracy))
    #expect(expectDateComponentsEqual(actual.1, expected2, accuracy: accuracy))
  }

  @Test("Twilight calculation for sun setting")
  func twilightSunSetting() throws {
    let day = DateComponents.date(2019, 8, 29)
    let expected1 = DateComponents.datetime(2019, 8, 29, 18, 54)
    let expected2 = DateComponents.datetime(2019, 8, 29, 19, 30)

    let actual = try twilight(observer: .london, date: day, direction: .setting)

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(actual.0, expected1, accuracy: accuracy))
    #expect(expectDateComponentsEqual(actual.1, expected2, accuracy: accuracy))
  }

  @Test(
    "Rahukaalam calculation",
    arguments: zip(
      [
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2015, 12, 2),
      ],
      [
        (DateComponents.datetime(2015, 12, 1, 9, 17), DateComponents.datetime(2015, 12, 1, 10, 35)),
        (DateComponents.datetime(2015, 12, 2, 6, 40), DateComponents.datetime(2015, 12, 2, 7, 58)),
      ]))
  func rahuCalculation(day: DateComponents, expected: (DateComponents, DateComponents)) throws {
    let actual = try rahukaalam(observer: .newDelhi, date: day)

    let accuracy = DateComponents(hour: 2)
    #expect(expectDateComponentsEqual(actual.0, expected.0, accuracy: accuracy))
    #expect(expectDateComponentsEqual(actual.1, expected.1, accuracy: accuracy))
  }

  @Test(
    "Solar altitude calculation",
    arguments: zip(
      [
        DateComponents.datetime(2015, 12, 14, 11, 0, 0),
        DateComponents.datetime(2015, 12, 14, 20, 1, 0),
      ],
      [14.381311, -37.3710156]))
  func solarAltitude(day: DateComponents, expected: Double) {
    let actual = elevation(observer: .london, dateandtime: day)
    #expect(abs(expected - actual) < 0.5)
  }

  @Test(
    "Solar azimuth calculation",
    arguments: zip(
      [
        DateComponents.datetime(2015, 12, 14, 11, 0, 0),
        DateComponents.datetime(2015, 12, 14, 20, 1, 0),
      ],
      [166.9676, 279.39927311745]))
  func solarAzimuth(day: DateComponents, expected: Double) {
    let actual = azimuth(observer: .london, dateandtime: day)
    #expect(abs(expected - actual) < 0.5)
  }

  @Test(
    "Solar zenith calculation for London",
    arguments: zip(
      [
        DateComponents.datetime(2021, 10, 10, 6, 0, 0),
        DateComponents.datetime(2021, 10, 10, 7, 0, 0),
        DateComponents.datetime(2021, 10, 10, 18, 0, 0),
        DateComponents.datetime(2020, 2, 3, 10, 37, 0),
      ],
      [93.25029, 84.01829, 97.45711, 71.0]))
  func solarZenithLondon(day: DateComponents, expected: Double) {
    let actual = zenith(observer: .london, dateandtime: day)
    #expect(abs(expected - actual) < 0.5)
  }

  @Test(
    "Solar zenith calculation for Riyadh",
    arguments: zip(
      [
        DateComponents.datetime(2022, 5, 1, 14, 0, 0),
        DateComponents.datetime(2022, 5, 1, 21, 0, 0),
      ],
      [72.40508, 139.58708]))
  func solarZenithRiyadh(day: DateComponents, expected: Double) {
    let actual = zenith(observer: .riyadh, dateandtime: day)
    #expect(abs(expected - actual) < 0.5)
  }

  @Test("Time at elevation for sun rising")
  func timeAtElevationSunRising() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: 6, date: d, direction: SunDirection.rising)
    let cdt = DateComponents.datetime(2016, 1, 4, 9, 5, 0)

    let accuracy = DateComponents(minute: 5)
    #expect(expectDateComponentsEqual(dt, cdt, accuracy: accuracy))
  }

  @Test("Time at elevation for sun setting")
  func timeAtElevationSunSetting() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: 6, date: d, direction: SunDirection.setting)
    let cdt = DateComponents.datetime(2016, 1, 4, 15, 5, 48)

    let accuracy = DateComponents(minute: 5)
    #expect(expectDateComponentsEqual(dt, cdt, accuracy: accuracy))
  }

  @Test("Time at elevation greater than 90 degrees")
  func timeAtElevationGreater90() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: 166, date: d, direction: SunDirection.setting)
    let cdt = DateComponents.datetime(2016, 1, 4, 13, 20, 0)

    let accuracy = DateComponents(minute: 5)
    #expect(expectDateComponentsEqual(dt, cdt, accuracy: accuracy))
  }

  @Test("Time at elevation greater than 180 degrees")
  func timeAtElevationGreater180() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: 186, date: d, direction: SunDirection.rising)
    let cdt = DateComponents.datetime(2016, 1, 4, 16, 44, 42)

    let accuracy = DateComponents(minute: 5)
    #expect(expectDateComponentsEqual(dt, cdt, accuracy: accuracy))
  }

  @Test("Time at elevation for sunrise below horizon")
  func timeAtElevationSunriseBelowHorizon() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: -18, date: d, direction: SunDirection.rising)
    let cdt = DateComponents.datetime(2016, 1, 4, 6, 0, 0)

    let accuracy = DateComponents(minute: 5)
    #expect(expectDateComponentsEqual(dt, cdt, accuracy: accuracy))
  }

  @Test("Time at elevation with negative elevation")
  func timeAtElevationBadElevation() {
    let d = DateComponents.date(2016, 1, 4)
    let dt = time_at_elevation(observer: .london, elevation: -18, date: d, direction: SunDirection.rising)
    let cdt = DateComponents.datetime(2016, 1, 4, 6, 0, 0)

    let accuracy = DateComponents(minute: 5)
    #expect(expectDateComponentsEqual(dt, cdt, accuracy: accuracy))
  }

  @Test("Daylight calculation returns start and end times")
  func daylightCalculation() throws {
    let d = DateComponents.date(2016, 1, 6)
    let dt = try daylight(observer: .london, date: d)
    let cstart = DateComponents.datetime(2016, 1, 6, 8, 5, 0)
    let cend = DateComponents.datetime(2016, 1, 6, 16, 7, 0)

    let accuracy = DateComponents(minute: 2)
    #expect(expectDateComponentsEqual(dt.0, cstart, accuracy: accuracy))
    #expect(expectDateComponentsEqual(dt.1, cend, accuracy: accuracy))
  }

  @Test("Night time calculation returns start and end times")
  func nightTimeCalculation() throws {
    let d = DateComponents.date(2016, 1, 6)
    let dt = try night(observer: .london, date: d)
    let cstart = DateComponents.datetime(2016, 1, 6, 16, 46)
    let cend = DateComponents.datetime(2016, 1, 7, 7, 25)

    let accuracy = DateComponents(minute: 5)
    #expect(expectDateComponentsEqual(dt.0, cstart, accuracy: accuracy))
    #expect(expectDateComponentsEqual(dt.1, cend, accuracy: accuracy))
  }
}
