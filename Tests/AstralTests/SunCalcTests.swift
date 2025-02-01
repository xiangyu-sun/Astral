//
//  SunCalcTests.swift
//
//
//  Created by Xiangyu Sun on 31/1/23.
//

import XCTest
@testable import Astral

final class SunCalcTests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testGeom() throws {
    let data = [
      (-1.329130732, 310.7374254),
      (12.00844627, 233.8203529),
      (0.184134155, 69.43779106),
    ]

    for (jc,gmls) in data {
      XCTAssertEqual(geom_mean_long_sun(juliancentury: jc), gmls, accuracy: 1)
    }
  }

  func testGmas() throws {
    let data = [
      (0.119986311, 4676.922342),
      (12.00844627, 432650.1681),
      (0.184134155, 6986.1838),
    ]

    for (jc,gams) in data {
      XCTAssertEqual(geom_mean_anomaly_sun(juliancentury: jc), gams, accuracy: 1)
    }
  }

  func testEEO() throws {
    let data = [
      (0.119986311, 0.016703588),
      (12.00844627, 0.016185564),
      (0.184134155, 0.016700889),
    ]

    for (jc,eeo) in data {
      XCTAssertEqual(eccentric_location_earth_orbit(juliancentury: jc), eeo, accuracy: 1e-6)
    }
  }

  func testEOS() throws {
    let data = [
      (0.119986311, -0.104951648),
      (12.00844627, -1.753028843),
      (0.184134155, 1.046852316),
    ]

    for (jc,eos) in data {
      XCTAssertEqual(sun_eq_of_center(juliancentury: jc), eos, accuracy: 1e-6)
    }
  }

  func testSTL() throws {
    let data = [
      (0.119986311, 279.9610686),
      (12.00844627, 232.0673358),
      (0.184134155, 70.48465428),
    ]

    for (jc,stl) in data {
      XCTAssertEqual(sun_true_long(juliancentury: jc), stl, accuracy: 0.001)
    }
  }

  func testSTAL() throws {
    let data = [
      (0.119986311, 4676.817391),
      (12.00844627, 432648.4151),
      (0.184134155, 6987.230663),
    ]

    for (jc,sta) in data {
      XCTAssertEqual(sun_true_anomoly(juliancentury: jc), sta, accuracy: 0.001)
    }
  }

  func testSRV() throws {
    let data = [
      (0.119986311, 0.983322329),
      (12.00844627, 0.994653382),
      (0.184134155, 1.013961204),
    ]

    for (jc,srv) in data {
      XCTAssertEqual(sun_rad_vector(juliancentury: jc), srv, accuracy: 0.001)
    }
  }

  func testSAL() throws {
    let data = [
      (0.119986311, 279.95995849827),
      (12.00844627, 232.065823531804),
      (0.184134155, 70.475244256027),
    ]

    for (jc,sal) in data {
      XCTAssertEqual(sun_apparent_long(juliancentury: jc), sal, accuracy: 0.001)
    }
  }

  func testMOOE() throws {
    let data = [
      (0.119986311, 23.4377307876356),
      (12.00844627, 23.2839797200388),
      (0.184134155, 23.4368965974579),
    ]

    for (jc,expected) in data {
      XCTAssertEqual(mean_obliquity_of_ecliptic(juliancentury: jc), expected, accuracy: 0.001)
    }
  }

  func testOC() throws {
    let data = [
      (0.119986311, 23.4369810410121),
      (12.00844627, 23.2852236361575),
      (0.184134155, 23.4352890293474),
    ]

    for (jc,expected) in data {
      XCTAssertEqual(mean_obliquity_of_ecliptic(juliancentury: jc), expected, accuracy: 0.01)
    }
  }

  func testSRA() throws {
    let data = [
      (0.119986311, -79.16480352),
      (12.00844627, -130.3163904),
      (0.184134155, 68.86915896),
    ]

    for (jc,expected) in data {
      XCTAssertEqual(sun_rt_ascension(juliancentury: jc), expected, accuracy: 0.001)
    }
  }

  func testSD() throws {
    let data = [
      (0.119986311, -23.06317068),
      (12.00844627, -18.16694394),
      (0.184134155, 22.01463552),
    ]

    for (jc,expected) in data {
      XCTAssertEqual(sun_declination(juliancentury: jc), expected, accuracy: 0.001)
    }
  }

  func testEOT() throws {
    let data = [
      (0.119986311, -3.078194825),
      (12.00844627, 16.58348133),
      (0.184134155, 2.232039737),
    ]

    for (jc,expected) in data {
      XCTAssertEqual(eq_of_time(juliancentury: jc), expected, accuracy: 0.001)
    }
  }

  func testHA() throws {
    let data: [(DateComponents, Double)] = [
      (.date(2012, 1, 1), 1.03555238),
      (.date(3200, 11, 14), 1.172253118),
      (.date(2018, 6, 1), 2.133712555),
    ]

    for (d,expected) in data {
      var date = d
      date.setValue(12, for: .hour)

      let jd = julianDay(at: date)

      let jc = julianDayToCentury(julianDay: jd)
      let decl = sun_declination(juliancentury: jc)

      XCTAssertEqual(
        hour_angle(latitude: Observer.london.latitude, declination: decl, zenith: 90.8333, direction: SunDirection.rising),
        expected,
        accuracy: 0.1)
    }
  }

  func testAzimuth() {
    let date = DateComponents.datetime(2001, 6, 21, 13, 11, 0)
    XCTAssertEqual(azimuth(observer: .new_dheli ,dateandtime: date), 292.76, accuracy: 0.01)
  }

  func testElevation() {
    let date = DateComponents.datetime(2001, 6, 21, 13, 11, 0)
    XCTAssertEqual(elevation(observer: .new_dheli ,dateandtime: date), 7.41, accuracy: 0.1)
  }

  func testElevation_Nonnative() {
    let date = DateComponents.datetime(2001, 6, 21, 18, 41, 0, .init(abbreviation: "GMT+5:30")!)
    XCTAssertEqual(elevation(observer: .new_dheli ,dateandtime: date), 7.41, accuracy: 0.1)
  }

  func testElevation_without_fraction() {
    let date = DateComponents.datetime(2001, 6, 21, 13, 11, 0)
    XCTAssertEqual(elevation(observer: .new_dheli ,dateandtime: date, with_refraction: false), 7.29, accuracy: 0.1)
  }

  func testAzimuthAbove85D() {
    let date = DateComponents.datetime(2001, 6, 21, 13, 11, 0)
    XCTAssertEqual(
      azimuth(observer: Observer(latitude: 86, longitude: 77.2, elevation: .double(0)) ,dateandtime: date),
      276.21,
      accuracy: 0.01)
  }

  func testElevationAbove85D() {
    let date = DateComponents.datetime(2001, 6, 21, 13, 11, 0)
    XCTAssertEqual(
      elevation(observer: Observer(latitude: 86, longitude: 77.2, elevation: .double(0)) ,dateandtime: date),
      23.10250115161950,
      accuracy: 0.001)
  }

  func test_ElevationEqualsTimeAtElevation() {
    for elevetion in 1...20 {
      let o = Observer.london
      let td = DateComponents.date(2020, 2, 6)

      let et = time_at_elevation(observer: o, elevation: elevetion.double , date: td, with_refraction: false)

      let sun_elevation = elevation(observer: o, dateandtime: et, with_refraction: false)

      XCTAssertEqual(sun_elevation, elevetion.double, accuracy: 0.1)
    }
  }

}
