//
//  SunElevationAdjustmentTests.swift
//  
//
//  Created by Xiangyu Sun on 31/1/23.
//

import XCTest
@testable import Astral
final class SunElevationAdjustmentTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

  func test_Float_Positive() {
    let adjustment = adjust_to_horizon(elevation: 12000)
    XCTAssertEqual(adjustment, 3.517744168209966)
  }

  func test_Float_Negative() {
    let adjustment = adjust_to_horizon(elevation: -1)
    XCTAssertEqual(adjustment, 0)
  }
  
  func test_Tuple_0() {
    let adjustment = adjust_to_obscuring_feature(elevation: (0.0, 100.0))
    XCTAssertEqual(adjustment, 0)
  }
  
  func test_Tuple_45deg() {
    let adjustment = adjust_to_obscuring_feature(elevation: (10.0, 10.0))
    XCTAssertEqual(adjustment, 45.0, accuracy: 0.001)
  }
  
  func test_Tuple_30deg() {
    let adjustment = adjust_to_obscuring_feature(elevation: (3.0, 4.0))
    XCTAssertEqual(adjustment, 53.130102354156, accuracy: 0.001)

  }
  
  func test_Tuple_neg45deg() {
    let adjustment = adjust_to_obscuring_feature(elevation: (-10.0, 10.0))
    XCTAssertEqual(adjustment, -45, accuracy: 0.001)
  }
  
}
