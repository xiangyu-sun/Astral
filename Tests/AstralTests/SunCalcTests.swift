//
//  SunCalcTests.swift
//
//
//  Created by Xiangyu Sun on 31/1/23.
//

import Foundation
import Numerics
import Testing
@testable import Astral

@Suite("Sun Calculation Tests", .tags(.solar, .fast))
struct SunCalcTests {

  @Test(
    "Geometric mean longitude of sun",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [-1.329130732, 12.00844627, 0.184134155],
      [310.7374254, 233.8203529, 69.43779106]))
  func geometricMeanLongitudeSun(jc: Double, expected: Double) {
    let result = geom_mean_long_sun(juliancentury: jc)
    #expect(abs(result - expected) < 1)
  }

  @Test(
    "Geometric mean anomaly of sun",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [4676.922342, 432650.1681, 6986.1838]))
  func geometricMeanAnomalySun(jc: Double, expected: Double) {
    let result = geom_mean_anomaly_sun(juliancentury: jc)
    #expect(abs(result - expected) < 1)
  }

  @Test(
    "Eccentric location of Earth orbit",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [0.016703588, 0.016185564, 0.016700889]))
  func eccentricLocationEarthOrbit(jc: Double, expected: Double) {
    let result = eccentric_location_earth_orbit(juliancentury: jc)
    #expect(abs(result - expected) < 1e-6)
  }

  @Test(
    "Sun equation of center",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [-0.104951648, -1.753028843, 1.046852316]))
  func sunEquationOfCenter(jc: Double, expected: Double) {
    let result = sun_eq_of_center(juliancentury: jc)
    #expect(abs(result - expected) < 1e-6)
  }

  @Test(
    "Sun true longitude",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [279.9610686, 232.0673358, 70.48465428]))
  func sunTrueLongitude(jc: Double, expected: Double) {
    let result = sun_true_long(juliancentury: jc)
    #expect(abs(result - expected) < 0.001)
  }

  @Test(
    "Sun true anomaly",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [4676.817391, 432648.4151, 6987.230663]))
  func sunTrueAnomaly(jc: Double, expected: Double) {
    let result = sun_true_anomoly(juliancentury: jc)
    #expect(abs(result - expected) < 0.001)
  }

  @Test(
    "Sun radius vector",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [0.983322329, 0.994653382, 1.013961204]))
  func sunRadiusVector(jc: Double, expected: Double) {
    let result = sun_rad_vector(juliancentury: jc)
    #expect(abs(result - expected) < 0.001)
  }

  @Test(
    "Sun apparent longitude",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [279.95995849827, 232.065823531804, 70.475244256027]))
  func sunApparentLongitude(jc: Double, expected: Double) {
    let result = sun_apparent_long(juliancentury: jc)
    #expect(abs(result - expected) < 0.001)
  }

  @Test(
    "Mean obliquity of ecliptic (0.001 accuracy)",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [23.4377307876356, 23.2839797200388, 23.4368965974579]))
  func meanObliquityOfEclipticHighPrecision(jc: Double, expected: Double) {
    let result = mean_obliquity_of_ecliptic(juliancentury: jc)
    #expect(abs(result - expected) < 0.001)
  }

  @Test(
    "Mean obliquity of ecliptic (0.01 accuracy)",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [23.4369810410121, 23.2852236361575, 23.4352890293474]))
  func meanObliquityOfEclipticLowPrecision(jc: Double, expected: Double) {
    let result = mean_obliquity_of_ecliptic(juliancentury: jc)
    #expect(abs(result - expected) < 0.01)
  }

  @Test(
    "Sun right ascension",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [-79.16480352 + 360, -130.3163904 + 360, 68.86915896]))
  func sunRightAscension(jc: Double, expected: Double) {
    let result = sun_rt_ascension(juliancentury: jc)
    #expect(abs(result - expected) < 0.001)
  }

  @Test(
    "Sun declination",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [-23.06317068, -18.16694394, 22.01463552]))
  func sunDeclination(jc: Double, expected: Double) {
    let result = sun_declination(juliancentury: jc)
    #expect(abs(result - expected) < 0.001)
  }

  @Test(
    "Equation of time",
    .tags(.conversion, .accuracy, .unit),
    arguments: zip(
      [0.119986311, 12.00844627, 0.184134155],
      [-3.078194825, 16.58348133, 2.232039737]))
  func equationOfTime(jc: Double, expected: Double) {
    let result = eq_of_time(juliancentury: jc)
    #expect(abs(result - expected) < 0.001)
  }

  @Test(
    "Hour angle calculation",
    .tags(.conversion, .unit),
    arguments: zip(
      [
        DateComponents.date(2012, 1, 1),
        DateComponents.date(3200, 11, 14),
        DateComponents.date(2018, 6, 1),
      ],
      [1.03555238, 1.172253118, 2.133712555]))
  func hourAngleCalculation(d: DateComponents, expected: Double) {
    var date = d
    date.setValue(12, for: .hour)

    let jd = julianDay(at: date)
    let jc = Astral.julianDayToCentury(julianDay: jd)
    let decl = sun_declination(juliancentury: jc)

    let result = hour_angle(
      latitude: Observer.london.latitude,
      declination: decl,
      zenith: 90.8333,
      direction: SunDirection.rising)
    #expect(abs(result - expected) < 0.1)
  }

  @Test("Azimuth at New Delhi", .tags(.position, .integration))
  func azimuthNewDelhi() {
    let date = DateComponents.datetime(2001, 6, 21, 13, 11, 0)
    let result = azimuth(observer: .newDelhi, dateandtime: date)
    #expect(abs(result - 292.76) < 0.01)
  }

  @Test("Elevation at New Delhi", .tags(.position, .integration))
  func elevationNewDelhi() {
    let date = DateComponents.datetime(2001, 6, 21, 13, 11, 0)
    let result = elevation(observer: .newDelhi, dateandtime: date)
    #expect(abs(result - 7.41) < 0.1)
  }

  @Test("Elevation at New Delhi with non-native timezone", .tags(.position, .integration, .time))
  func elevationNewDelhiNonNativeTimezone() {
    let date = DateComponents.datetime(2001, 6, 21, 18, 41, 0, .init(abbreviation: "GMT+5:30")!)
    let result = elevation(observer: .newDelhi, dateandtime: date)
    #expect(abs(result - 7.41) < 0.1)
  }

  @Test("Elevation without refraction", .tags(.position, .integration))
  func elevationWithoutRefraction() {
    let date = DateComponents.datetime(2001, 6, 21, 13, 11, 0)
    let result = elevation(observer: .newDelhi, dateandtime: date, with_refraction: false)
    #expect(abs(result - 7.29) < 0.1)
  }

  @Test("Azimuth above 85 degrees latitude", .tags(.position, .integration, .edge))
  func azimuthAbove85Degrees() {
    let date = DateComponents.datetime(2001, 6, 21, 13, 11, 0)
    let observer = Observer(latitude: 86, longitude: 77.2, elevation: .double(0))
    let result = azimuth(observer: observer, dateandtime: date)
    #expect(abs(result - 276.21) < 0.01)
  }

  @Test("Elevation above 85 degrees latitude", .tags(.position, .integration, .edge))
  func elevationAbove85Degrees() {
    let date = DateComponents.datetime(2001, 6, 21, 13, 11, 0)
    let observer = Observer(latitude: 86, longitude: 77.2, elevation: .double(0))
    let result = elevation(observer: observer, dateandtime: date)
    #expect(abs(result - 23.10250115161950) < 0.001)
  }

  @Test(
    "Elevation equals time at elevation",
    .tags(.position, .integration),
    arguments: 1...20)
  func elevationEqualsTimeAtElevation(elevation: Int) {
    let observer = Observer.london
    let date = DateComponents.date(2020, 2, 6)

    let et = time_at_elevation(
      observer: observer,
      elevation: elevation.double,
      date: date,
      with_refraction: false)

    let sunElevation = Astral.elevation(
      observer: observer,
      dateandtime: et,
      with_refraction: false)

    #expect(abs(sunElevation - elevation.double) < 0.1)
  }

}
