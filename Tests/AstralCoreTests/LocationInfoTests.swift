//
//  LocationInfoTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import XCTest
@testable import AstralCore

final class LocationInfoTests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func test_bad_latitude() {
    XCTAssertThrowsError(try LocationInfo(
      name: "A place",
      region: "Somewhere",
      timezone: "Europe/London",
      latitudeStr: "i",
      longitudeStr: "2"))
  }

  func test_bad_longitude() {
    XCTAssertThrowsError(try LocationInfo(
      name: "A place",
      region: "Somewhere",
      timezone: "Europe/London",
      latitudeStr: "2",
      longitudeStr: "i"))
  }

  func test_timezone_group() {
    let li = LocationInfo(name: "", region: "", timezone: .current, latitude: 0, longitude: 0)
    XCTAssertEqual(li.timezoneGroup, "Europe")
  }

}
