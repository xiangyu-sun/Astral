//
//  MoonPostionTests.swift
//  
//
//  Created by Xiangyu Sun on 20/1/23.
//

import XCTest
@testable import Astral

final class MoonPostionTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


  
  func test_moon_position(){
    var d = DateComponents.date(1969, 6, 28)
    var jd = julianDay(at:d)
    var jd2000 = jd - 2451545  // Julian day relative to Jan 1.5, 2000
    
    XCTAssertEqual(moonPosition(jd2000: jd2000), AstralBodyPosition(right_ascension: -1.9638999378692186, declination: -0.4666623303219141, distance: 56.55564052259119))
    
    d = DateComponents.date(1992, 4, 12)
    jd = julianDay(at: d)
    jd2000 = jd - 2451545  // Julian day relative to Jan 1.5, 2000
    XCTAssertEqual(moonPosition(jd2000: jd2000), AstralBodyPosition(right_ascension: -3.932462849957415, declination: 0.24034553813386558, distance: 57.76236323127602))
    
  }


}
