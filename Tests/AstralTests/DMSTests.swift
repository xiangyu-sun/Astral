//
//  DMSTests.swift
//  
//
//  Created by Xiangyu Sun on 20/1/23.
//

import XCTest
@testable import Astral

final class DMSTests: XCTestCase {
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  func test_north() {
    
    XCTAssertEqual(try convertDegreesMinutesSecondsToDouble(value: "24°28'N", limit: 90), 24.466666, accuracy: 0.1)
  }
  func test_whole_number_of_degrees() {
    XCTAssertEqual(try  convertDegreesMinutesSecondsToDouble(value: "24°", limit: 90.0), 24.0)
  }
  func test_east() {
    XCTAssertEqual(try convertDegreesMinutesSecondsToDouble(value: "54°22'E", limit: 180.0), 54.366666, accuracy: 0.00001)
  }
  func test_south() {
    XCTAssertEqual(try convertDegreesMinutesSecondsToDouble(value: "37°58'S", limit: 90.0), -37.966666, accuracy: 0.00001)
  }
  func test_west() {
    XCTAssertEqual(try convertDegreesMinutesSecondsToDouble(value: "171°50'W", limit: 180.0), -171.8333333, accuracy: 0.00001)
  }
  func test_west_lowercase() {
    XCTAssertEqual(try convertDegreesMinutesSecondsToDouble(value: "171°50'w", limit: 180.0), -171.8333333, accuracy: 0.00001)
  }
  func test_float() {
    XCTAssertEqual(try convertDegreesMinutesSecondsToDouble(value: "0.2", limit: 90.0), 0.2)
  }
  
  func test_not_a_float() {
    XCTAssertThrowsError(try convertDegreesMinutesSecondsToDouble(value: "x", limit: 90.0))
    
  }
  func test_latlng_outside_limit() {
    XCTAssertEqual(try convertDegreesMinutesSecondsToDouble(value: "180°50'w", limit: 180.0), -180)
  }
  
}
