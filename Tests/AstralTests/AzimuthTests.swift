//
//  AzimuthTests.swift
//  
//
//  Created by Xiangyu Sun on 20/1/23.
//

import XCTest
@testable import Astral

final class AzimuthTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

  let data: [(DateComponents, Double)] = [
          (.datetime(2022, 10, 6, 1, 10, 0), 240.0),
          (.datetime(2022, 10, 6, 16, 45, 0), 115.0),
          (.datetime(2022, 10, 10, 6, 43, 0), 281.0),
          (.datetime(2022, 10, 10, 3, 0, 0), 235.0)
      ]
  
    func testExample() throws {
      for (dt, value) in data {
        let az = azimuth(observer: .init(latitude: 51.4733, longitude: -0.0008333, elevation: .double(0)), at: dt)
        XCTAssertEqual(value, az, accuracy:1)
      }
    }


}
