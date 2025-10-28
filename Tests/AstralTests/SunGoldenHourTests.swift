//
//  SunGoldenHourTests.swift
//
//
//  Created by Xiangyu Sun on 31/1/23.
//

import XCTest
@testable import Astral

final class SunGoldenHourTests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testGoldenHourMorning() throws {
    let data: [(DateComponents, (DateComponents, DateComponents))] = [
      (
        .date(2015, 12, 1),
        (
          .datetime(2015, 12, 1, 1, 10, 10),
          .datetime(2015, 12, 1, 2, 0, 43))),
      (
        .date(2016, 1, 1),
        (
          .datetime(2016, 1, 1, 1, 27, 46),
          .datetime(2016, 1, 1, 2, 19, 1))),
    ]

    for (day, gh) in data {
      let start1 = gh.0
      let end1 = gh.1

      let (start2, end2) = try golden_hour(
        observer: Observer.newDelhi,
        date: day,
        direction: SunDirection.rising)

      XCTAssertEqual(end1, end2, accuracy: DateComponents(second: 90))
      XCTAssertEqual(start1, start2, accuracy: DateComponents(second: 90))
    }
  }

  func testGoldenHourEvening() throws {
    let data: [(DateComponents, (DateComponents, DateComponents))] = [
      (
        .date(2016, 5, 18),
        (
          .datetime(2016, 5, 18, 19, 2),
          .datetime(2016, 5, 18, 20, 17))),
    ]

    for (day, gh) in data {
      let start1 = gh.0
      let end1 = gh.1

      let (start2, end2) = try golden_hour(
        observer: Observer.london,
        date: day,
        direction: SunDirection.setting)

      XCTAssertEqual(end1, end2, accuracy: DateComponents(second: 90))
      XCTAssertEqual(start1, start2, accuracy: DateComponents(second: 90))
    }
  }

  func testGoldenHourNoDate() throws {
    let data: [(DateComponents, (DateComponents, DateComponents))] = [
      (
        .date(2015, 12, 1),
        (
          .datetime(2015, 12, 1, 1, 10, 10),
          .datetime(2015, 12, 1, 2, 0, 43))),
    ]

    for (day, gh) in data {
      let start1 = gh.0
      let end1 = gh.1

      let (start2, end2) = try golden_hour(
        observer: Observer.newDelhi,
        date: day)

      XCTAssertEqual(end1, end2, accuracy: DateComponents(second: 90))
      XCTAssertEqual(start1, start2, accuracy: DateComponents(second: 90))
    }
  }

  // MARK: Blue Hour

  func testBluenHourMorning() throws {
    let data: [(DateComponents, (DateComponents, DateComponents))] = [
      (
        .date(2016, 5, 19),
        (
          .datetime(2016, 5, 19, 3, 19),
          .datetime(2016, 5, 19, 3, 36))),
    ]

    for (day, bh) in data {
      let start1 = bh.0
      let end1 = bh.1

      let (start2, end2) = try blue_hour(
        observer: Observer.london,
        date: day,
        direction: SunDirection.rising)

      XCTAssertEqual(end1, end2, accuracy: DateComponents(minute: 1, second: 30))
      XCTAssertEqual(start1, start2, accuracy: DateComponents(minute: 1, second: 30))
    }
  }

  func testBluenHourEvening() throws {
    let data: [(DateComponents, (DateComponents, DateComponents))] = [
      (
        .date(2016, 5, 19),
        (
          .datetime(2016, 5, 19, 20, 18),
          .datetime(2016, 5, 19, 20, 35))),
    ]

    for (day, bh) in data {
      let start1 = bh.0
      let end1 = bh.1

      let (start2, end2) = try blue_hour(
        observer: Observer.london,
        date: day,
        direction: SunDirection.setting)

      XCTAssertEqual(end1, end2, accuracy: DateComponents(second: 90))
      XCTAssertEqual(start1, start2, accuracy: DateComponents(second: 90))
    }
  }

  func testBlueHourNoDate() throws {
    let data: [(DateComponents, (DateComponents, DateComponents))] = [
      (
        .date(2016, 5, 19),
        (
          .datetime(2016, 5, 19, 20, 18),
          .datetime(2016, 5, 19, 20, 35))),
    ]

    for (day, gh) in data {
      let start1 = gh.0
      let end1 = gh.1

      let (start2, end2) = try blue_hour(
        observer: Observer.london,
        date: day,
        direction: .setting)

      XCTAssertEqual(end1, end2, accuracy: DateComponents(second: 90))
      XCTAssertEqual(start1, start2, accuracy: DateComponents(second: 90))
    }
  }
}
