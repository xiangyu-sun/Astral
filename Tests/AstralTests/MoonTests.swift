//
//  MoonTests.swift
//  
//
//  Created by Xiangyu Sun on 20/1/23.
//

import XCTest
@testable import Astral

final class MoonTests: XCTestCase {
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  
  let moonPhaseData: [(DateComponents, Double)] = [
    (.date(2015, 12, 1), 19.477889),
    (.date(2015, 12, 2), 20.333444),
    (.date(2015, 12, 3), 21.189000),
    (.date(2014, 12, 1), 9.0556666),
    (.date(2014, 12, 2), 10.066777),
    (.date(2014, 1, 1), 27.955666)
  ]
  
  func testMoonPahse() throws {
    for (date, phase) in moonPhaseData {
      XCTAssertEqual(moonPhase(date: date), phase, accuracy: 0.00001)
    }
  }
  
  let moonRiseData: [(DateComponents, DateComponents)] = [
    (.date(2022, 11, 30), .datetime(2022, 11, 30, 13, 17, 0)),
    (.date(2022, 1, 1), .datetime(2022, 1, 1, 6, 55, 0)),
    (.date(2022, 2, 1), .datetime(2022, 2, 1, 8, 24, 0))
  ]
  
  func testMoonRiseUTC() throws {
    for (date, risetime) in moonRiseData {
      
      let calc_time = try moonrise(observer: .london, dateComponents: date)
      XCTAssertNotNil(calc_time)
      XCTAssertEqual(calc_time!.extractYearMonthDayHourMinuteSecond(), risetime.extractYearMonthDayHourMinuteSecond(), accurency: DateComponents(minute: 1))
    }
  }
  
  let moonSetData: [(DateComponents, DateComponents)] = [
    (.date(2021, 10, 28), .datetime(2021, 10, 28, 14, 11, 0)),
    (.date(2021, 11, 6), .datetime(2021, 11, 6, 17, 21, 0)),
    (.date(2022, 2, 1), .datetime(2022, 2, 1, 16, 57, 0))
  ]
  
  func testMoonSetUTC() throws {
    for (date, settime) in moonSetData {
      
      let calc_time = try moonset(observer:.london, dateComponents: date)
      XCTAssertNotNil(calc_time)
      XCTAssertEqual(calc_time?.extractYearMonthDayHourMinuteSecond(), settime.extractYearMonthDayHourMinuteSecond())
    }
  }
  
  
  let moonRiseDataRiyadh: [(DateComponents, DateComponents)] = [
    (.date(2022, 5, 1), .datetime(2022, 5, 1, 2, 34, 0)),
    (.date(2022, 5, 24), .datetime(2022, 5, 24, 22, 59, 0))
  ]
  
  func testMoonRiseRiyadhUTC() throws {
    for (date, risetime) in moonRiseDataRiyadh {
      let calc_time = try moonrise(observer: .riyadh, dateComponents: date)
      XCTAssertNotNil(calc_time)
      XCTAssertEqual(calc_time!.extractYearMonthDayHourMinuteSecond(), risetime.extractYearMonthDayHourMinuteSecond(), accurency: DateComponents(second: 1))
    }
  }
  
  let moonSetRiyadhUTCData: [(DateComponents, DateComponents)] = [
    (.date(2021, 10, 28), .datetime(2021, 10, 28, 9, 26, 0)),
    (.date(2021, 11, 6), .datetime(2021, 11, 6, 15, 33, 0)),
    (.date(2022, 2, 1), .datetime(2022, 2, 1, 14, 54, 0))
  ]
  
  func testMoonSetRiyadhUTC() throws {
    for (date, settime) in moonSetRiyadhUTCData {
      let calc_time = try moonset(observer: .riyadh, dateComponents: date)
      XCTAssertNotNil(calc_time)
      XCTAssertEqual(calc_time?.extractYearMonthDayHourMinuteSecond(), settime.extractYearMonthDayHourMinuteSecond())
    }
  }
  
  static let tz = TimeZone(abbreviation: "GMT+13")!
  
  let moonRiseWelllingtonData: [(DateComponents, DateComponents)] = [
    (.date(2021, 10, 28, tz), .datetime(2021, 10, 28, 2, 6, 0, tz)),
    (.date(2021, 11, 6, tz), .datetime(2021, 11, 6, 6, 45, 0, tz)),
  ]
  

  func testMoonRiseWellington() throws {
    for (date, risetime) in moonRiseWelllingtonData {
      let calc_time = try moonrise(observer: .welllington, dateComponents: date, tzinfo: Self.tz)
      XCTAssertNotNil(calc_time)
      XCTAssertEqual(calc_time?.extractYearMonthDayHourMinuteSecond(timeZone: Self.tz), risetime.extractYearMonthDayHourMinuteSecond(timeZone: Self.tz))
    }
  }
  
  let moonSetWellingtonUTCData: [(DateComponents, DateComponents)] = [
    (.date(2021, 8, 18, tz), .datetime(2021, 8, 18, 3, 31, 0, tz)),
    (.date(2021, 7, 8, tz), .datetime(2021, 7, 8, 15, 16, 0, tz)),
  ]
  
  func testMoonSetWellington() throws {
    for (date, settime) in moonSetWellingtonUTCData {
      let calc_time = try moonrise(observer: .welllington, dateComponents: date, tzinfo: Self.tz)
      XCTAssertNotNil(calc_time)
      XCTAssertEqual(calc_time?.extractYearMonthDayHourMinuteSecond(timeZone: Self.tz), settime.extractYearMonthDayHourMinuteSecond(timeZone: Self.tz))
    }
  }
  
  static let timeZoneBCN = TimeZone(abbreviation: "CET")!
  
  
  let moonRiseBarcelonanData: [(DateComponents, DateComponents)] = [
    (.date(2023, 1, 21, timeZoneBCN), .datetime(2023, 1, 21, 8, 15, 0, timeZoneBCN)),
  ]
  
  let moonRiseBarcelonanDataUTC: [(DateComponents, DateComponents)] = [
    (.date(2023, 1, 21), .datetime(2023, 1, 21, 7, 15, 0)),
  ]
  

  func testMoonRiseBarcelona() throws {
    for (date, risetime) in moonRiseBarcelonanData {
      let calc_time = try moonrise(observer: .barcelona, dateComponents: date, tzinfo: Self.timeZoneBCN)
      XCTAssertNotNil(calc_time)
      XCTAssertEqual(calc_time!.extractYearMonthDayHourMinuteSecond(timeZone: Self.timeZoneBCN), risetime.extractYearMonthDayHourMinuteSecond(timeZone: Self.timeZoneBCN), accurency: DateComponents(minute: 1))
    }
    
    for (date, risetime) in moonRiseBarcelonanDataUTC {
      let calc_time = try moonrise(observer: .barcelona, dateComponents: date)
      XCTAssertNotNil(calc_time)
      XCTAssertEqual(calc_time!.extractYearMonthDayHourMinuteSecond(), risetime.extractYearMonthDayHourMinuteSecond(), accurency: DateComponents(minute: 1))
    }
  }
}
