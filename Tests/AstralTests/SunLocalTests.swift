//
//  SunLocalTests.swift
//  
//
//  Created by Xiangyu Sun on 31/1/23.
//

import XCTest
@testable import Astral

final class SunLocalTests: XCTestCase {
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  func testSunLocalTimezone() throws {
    let dheli = TimeZone(abbreviation: "GMT+5:30")!
    let data: [(DateComponents, DateComponents)] =   [
      (.date(2015, 12, 1), .datetime(2015, 12, 1, 6, 30, 0, dheli)),
      (.date(2015, 12, 2), .datetime(2015, 12, 2, 6, 31,0, dheli)),
      (.date(2015, 12, 3), .datetime(2015, 12, 3, 6, 31,0, dheli)),
      (.date(2015, 12, 12), .datetime(2015, 12, 12, 6, 38,0,  dheli)),
      (.date(2015, 12, 25), .datetime(2015, 12, 25, 6, 45,0,  dheli)),
    ]
    
    for (day, down) in data {
      let dawn_calc = try sun(observer: .new_dheli, date: day, dawn_dusk_depression: Depression(rawValue: 6), tzinfo: dheli)["dawn"]
      
      XCTAssertEqual(dawn_calc, down)
    }
  }
  
  
  
}
