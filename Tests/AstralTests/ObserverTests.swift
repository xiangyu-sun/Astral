//
//  ObserverTests.swift
//  
//
//  Created by Xiangyu Sun on 20/1/23.
//

import XCTest
@testable import Astral

final class ObserverTests: XCTestCase {
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  
  
  func test_from_string() throws {
    let obs = try Observer(latitude: "1", longitude: "2", elevation: .double(0))
    XCTAssertEqual(obs.latitude, 1.0)
    XCTAssertEqual(obs.longitude, 2.0)
    XCTAssertEqual(obs.elevation, .double(0))
  }
  
  func test_from_dms() throws {
    let obs = try Observer(latitude: "24°N", longitude: "22°30'S", elevation: .double(0))
    XCTAssertEqual(obs.latitude, 24.0)
    XCTAssertEqual(obs.longitude, -22.5)
    XCTAssertEqual(obs.elevation, .double(0))
  }
  
  func test_bad_latitude(){
    XCTAssertThrowsError(try Observer(latitude: "o", longitude: "1", elevation: .double(0)))
  }
  
  func test_bad_longitude(){
    XCTAssertThrowsError(try Observer(latitude: "1", longitude: "o", elevation: .double(0)))
  }
  
  
  func test_latitude_outside_limits(){
    var obs = Observer(latitude: 90.1, longitude: 0, elevation: .double(0))
    XCTAssertEqual(obs.latitude, 90.0)
    obs = Observer(latitude: -90.1, longitude: 0, elevation: .double(0))
    XCTAssertEqual(obs.latitude, -90.0)
  }
  
  func test_longitude_outside_limits(){
    var obs = Observer(latitude: 0, longitude: 180.1, elevation: .tuple(0,0))
    XCTAssertEqual(obs.longitude, 180.0)
    obs = Observer(latitude: 0, longitude: -180.1, elevation: .double(0))
    XCTAssertEqual(obs.longitude, -180.0)
  }
  
}
