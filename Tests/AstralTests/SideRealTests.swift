//
//  SideRealTests.swift
//  
//
//  Created by Xiangyu Sun on 20/1/23.
//

import XCTest
@testable import Astral

final class SideRealTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

  func test_gmst() {
    let dt = DateComponents.datetime(1987, 4, 10, 0, 0, 0)
    let mean_sidereal_time = gmst(dateComponents: dt)
    
    let t = from(hours:mean_sidereal_time / 15)
    XCTAssertEqual(t.hour, 13)
    XCTAssertEqual(t.minute, 10)
    XCTAssertEqual(t.second, 46)
    XCTAssertEqual(t.nanosecond, 366821000)
  }


  func test_gmst_with_time() {
    let dt = DateComponents.datetime(1987, 4, 10, 19, 21, 0)
    let mean_sidereal_time = gmst(dateComponents: dt)
    let t = from(hours:mean_sidereal_time / 15)
    XCTAssertEqual(t.hour, 8)
    XCTAssertEqual(t.minute, 34)
    XCTAssertEqual(t.second, 57)
    XCTAssertEqual(t.nanosecond, 89578000)
  }


  func test_local_mean_sidereal_time() {
    let dt = DateComponents.datetime(1987, 4, 10, 0, 0, 0)
    let mean_sidereal_time = lmst(dateComponents: dt, longitude: -0.13)
    XCTAssertEqual(mean_sidereal_time, 197.693195090862 - 0.13)
  }
}
