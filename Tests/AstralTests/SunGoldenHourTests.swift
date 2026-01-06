//
//  SunGoldenHourTests.swift
//
//
//  Created by Xiangyu Sun on 31/1/23.
//

import Foundation
import Testing
@testable import Astral

@Suite("Sun Golden Hour and Blue Hour Tests")
struct SunGoldenHourTests {

  // MARK: - Golden Hour Tests

  @Test(
    "Golden hour calculation - morning",
    arguments: zip(
      [
        DateComponents.date(2015, 12, 1),
        DateComponents.date(2016, 1, 1),
      ],
      [
        (
          DateComponents.datetime(2015, 12, 1, 1, 10, 10),
          DateComponents.datetime(2015, 12, 1, 2, 0, 43)
        ),
        (
          DateComponents.datetime(2016, 1, 1, 1, 27, 46),
          DateComponents.datetime(2016, 1, 1, 2, 19, 1)
        ),
      ]
    )
  )
  func goldenHourMorning(day: DateComponents, expected: (DateComponents, DateComponents)) throws {
    let (start, end) = try golden_hour(
      observer: Observer.newDelhi,
      date: day,
      direction: SunDirection.rising
    )

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(end, expected.1, accuracy: accuracy))
    #expect(expectDateComponentsEqual(start, expected.0, accuracy: accuracy))
  }

  @Test("Golden hour calculation - evening")
  func goldenHourEvening() throws {
    let day = DateComponents.date(2016, 5, 18)
    let expectedStart = DateComponents.datetime(2016, 5, 18, 19, 2)
    let expectedEnd = DateComponents.datetime(2016, 5, 18, 20, 17)

    let (start, end) = try golden_hour(
      observer: Observer.london,
      date: day,
      direction: SunDirection.setting
    )

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(end, expectedEnd, accuracy: accuracy))
    #expect(expectDateComponentsEqual(start, expectedStart, accuracy: accuracy))
  }

  @Test("Golden hour calculation - no direction specified")
  func goldenHourNoDate() throws {
    let day = DateComponents.date(2015, 12, 1)
    let expectedStart = DateComponents.datetime(2015, 12, 1, 1, 10, 10)
    let expectedEnd = DateComponents.datetime(2015, 12, 1, 2, 0, 43)

    let (start, end) = try golden_hour(
      observer: Observer.newDelhi,
      date: day
    )

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(end, expectedEnd, accuracy: accuracy))
    #expect(expectDateComponentsEqual(start, expectedStart, accuracy: accuracy))
  }

  // MARK: - Blue Hour Tests

  @Test("Blue hour calculation - morning")
  func blueHourMorning() throws {
    let day = DateComponents.date(2016, 5, 19)
    let expectedStart = DateComponents.datetime(2016, 5, 19, 3, 19)
    let expectedEnd = DateComponents.datetime(2016, 5, 19, 3, 36)

    let (start, end) = try blue_hour(
      observer: Observer.london,
      date: day,
      direction: SunDirection.rising
    )

    let accuracy = DateComponents(minute: 1, second: 30)
    #expect(expectDateComponentsEqual(end, expectedEnd, accuracy: accuracy))
    #expect(expectDateComponentsEqual(start, expectedStart, accuracy: accuracy))
  }

  @Test("Blue hour calculation - evening")
  func blueHourEvening() throws {
    let day = DateComponents.date(2016, 5, 19)
    let expectedStart = DateComponents.datetime(2016, 5, 19, 20, 18)
    let expectedEnd = DateComponents.datetime(2016, 5, 19, 20, 35)

    let (start, end) = try blue_hour(
      observer: Observer.london,
      date: day,
      direction: SunDirection.setting
    )

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(end, expectedEnd, accuracy: accuracy))
    #expect(expectDateComponentsEqual(start, expectedStart, accuracy: accuracy))
  }

  @Test("Blue hour calculation - no date specified")
  func blueHourNoDate() throws {
    let day = DateComponents.date(2016, 5, 19)
    let expectedStart = DateComponents.datetime(2016, 5, 19, 20, 18)
    let expectedEnd = DateComponents.datetime(2016, 5, 19, 20, 35)

    let (start, end) = try blue_hour(
      observer: Observer.london,
      date: day,
      direction: .setting
    )

    let accuracy = DateComponents(second: 90)
    #expect(expectDateComponentsEqual(end, expectedEnd, accuracy: accuracy))
    #expect(expectDateComponentsEqual(start, expectedStart, accuracy: accuracy))
  }
}
