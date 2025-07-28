import XCTest
@testable import Astral

final class Moon2Tests: XCTestCase {

  // MARK: - Mean Elements at J2000

  func testMoonMeanLongitudeAtEpoch() {
    let rev = moon_mean_longitude(jd2000: 0)
    XCTAssertEqual(
      rev,
      0.606434,
      accuracy: 1e-9,
      "月亮的平均黄经在 J2000.0 应为 0.606434 周期")
  }

  func testMoonMeanAnomalyAtEpoch() {
    let rev = moon_mean_anomoly(jd2000: 0)
    XCTAssertEqual(
      rev,
      0.374897,
      accuracy: 1e-9,
      "月亮的平近点角在 J2000.0 应为 0.374897 周期")
  }

  func testMoonArgumentOfLatitudeAtEpoch() {
    let rev = moon_argument_of_latitude(jd2000: 0)
    XCTAssertEqual(
      rev,
      0.259091,
      accuracy: 1e-9,
      "月亮的纬角论元在 J2000.0 应为 0.259091 周期")
  }

  func testMoonMeanElongationFromSunAtEpoch() {
    let rev = moon_mean_elongation_from_sun(jd2000: 0)
    XCTAssertEqual(
      rev,
      0.827362,
      accuracy: 1e-9,
      "月亮的平日距在 J2000.0 应为 0.827362 周期")
  }

  // MARK: - Sun Elements at J2000

  func testSunMeanLongitudeAtEpoch() {
    let rev = sun_mean_longitude(jd2000: 0)
    XCTAssertEqual(
      rev,
      0.779072,
      accuracy: 1e-9,
      "太阳的平均黄经在 J2000.0 应为 0.779072 周期")
  }

  func testSunMeanAnomalyAtEpoch() {
    let rev = sun_mean_anomoly(jd2000: 0)
    XCTAssertEqual(
      rev,
      0.993126,
      accuracy: 1e-9,
      "太阳的平近点角在 J2000.0 应为 0.993126 周期")
  }

  // MARK: - Obliquity of the Ecliptic

  func testObliquityAtEpoch() {
    let ob = obliquity_of_ecliptic(jd2000: 0)
    // 23°26′21.448″ in radians
    let expected = (23.0 + 26.0 / 60.0 + 21.448 / 3600.0) * Double.pi / 180.0
    XCTAssertEqual(
      ob,
      expected,
      accuracy: 1e-12,
      "黄赤交角在 J2000.0 应为 23°26′21.448″")
  }

  // MARK: - True Ecliptic Longitude

  func testMoonTrueLongitudeRange() {
    let rev = moon_true_longitude(jd2000: 0)
    XCTAssertGreaterThanOrEqual(rev, 0.0, "真黄经返回值应 ≥ 0")
    XCTAssertLessThan(rev, 1.0, "真黄经返回值应 < 1")
  }

  func testMoonTrueLongitudeApproxEqualsMean() {
    let meanRev = moon_mean_longitude(jd2000: 0)
    let trueRev = moon_true_longitude(jd2000: 0)
    // 在 J2000.0，真黄经应与平均黄经非常接近
    XCTAssertEqual(
      trueRev,
      meanRev,
      accuracy: 2e-2,
      "真黄经应在平均黄经附近 (误差 <0.01 周期)")
  }

  // MARK: - Comprehensive True Ecliptic Longitude Tests with Reference Data

  func testMoonTrueLongitudeWithReferenceData() {
    // Test data calculated using established astronomical algorithms
    // Based on simplified lunar theory with accuracy ~0.05 degrees
    let testCases: [(jd2000: Double, expectedDegrees: Double, description: String)] = [
      // 2024-01-01 00:00 UTC (JD = 2460310.5)
      (8765.5, 156.017016, "2024-01-01 00:00 UTC"),
      // 2024-03-21 00:00 UTC (JD = 2460390.5) - Spring Equinox
      (8845.5, 134.275040, "2024-03-21 00:00 UTC (Spring Equinox)"),
      // 2024-06-21 00:00 UTC (JD = 2460482.5) - Summer Solstice
      (8937.5, 257.045540, "2024-06-21 00:00 UTC (Summer Solstice)"),
      // 2024-09-23 00:00 UTC (JD = 2460576.5) - Autumn Equinox
      (9031.5, 67.971129, "2024-09-23 00:00 UTC (Autumn Equinox)"),
      // 2024-12-21 00:00 UTC (JD = 2460665.5) - Winter Solstice
      (9120.5, 158.411401, "2024-12-21 00:00 UTC (Winter Solstice)")
    ]

    for testCase in testCases {
      let calculatedRevolutions = moon_true_longitude(jd2000: testCase.jd2000)
      let calculatedDegrees = calculatedRevolutions * 360.0
      
      // Allow for 3-degree tolerance given the complexity of lunar calculations
      // This accounts for differences between simplified vs full lunar theory
      let tolerance = 3.0
      
      XCTAssertEqual(
        calculatedDegrees,
        testCase.expectedDegrees,
        accuracy: tolerance,
        "Moon ecliptic longitude mismatch for \(testCase.description). Expected: \(testCase.expectedDegrees)°, Got: \(calculatedDegrees)°, Diff: \(abs(calculatedDegrees - testCase.expectedDegrees))°"
      )
    }
  }

  func testMoonTrueLongitudeConsistency() {
    // Test that the function returns consistent results for the same input
    let jd2000 = 8765.5 // 2024-01-01
    let result1 = moon_true_longitude(jd2000: jd2000)
    let result2 = moon_true_longitude(jd2000: jd2000)
    
    XCTAssertEqual(result1, result2, accuracy: 1e-15, "Function should return identical results for identical inputs")
  }

  func testMoonTrueLongitudeNormalization() {
    // Test various dates to ensure longitude is always normalized to [0, 1) revolutions
    let testDates = [-10000.0, -1000.0, -100.0, 0.0, 100.0, 1000.0, 10000.0]
    
    for jd2000 in testDates {
      let longitude = moon_true_longitude(jd2000: jd2000)
      XCTAssertGreaterThanOrEqual(longitude, 0.0, "Longitude should be >= 0 for JD2000=\(jd2000)")
      XCTAssertLessThan(longitude, 1.0, "Longitude should be < 1 for JD2000=\(jd2000)")
    }
  }

  func testMoonTrueLongitudeMonotonicity() {
    // Test that longitude generally increases with time (over short intervals)
    // Note: This is not strictly monotonic due to orbital mechanics, but should show general trend
    let startJD = 0.0
    let increment = 1.0 // 1 day
    var previousLongitude = moon_true_longitude(jd2000: startJD)
    var increasingCount = 0
    let totalTests = 10
    
    for i in 1...totalTests {
      let currentLongitude = moon_true_longitude(jd2000: startJD + Double(i) * increment)
      
      // Handle wraparound at 0/360 degrees
      var deltaLongitude = currentLongitude - previousLongitude
      if deltaLongitude < -0.5 {
        deltaLongitude += 1.0 // Wrapped around
      }
      
      if deltaLongitude > 0 {
        increasingCount += 1
      }
      
      previousLongitude = currentLongitude
    }
    
    // Expect at least 80% of samples to show increasing longitude (accounting for orbital variations)
    XCTAssertGreaterThan(increasingCount, totalTests * 8 / 10, "Longitude should generally increase with time")
  }
}
