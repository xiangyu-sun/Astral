import XCTest
@testable import Astral

final class Moon2Tests: XCTestCase {
  
  // MARK: - Mean Elements at J2000
  
  func testMoonMeanLongitudeAtEpoch() {
    let rev = moon_mean_longitude(jd2000: 0)
    XCTAssertEqual(rev, 0.606434, accuracy: 1e-9,
                   "月亮的平均黄经在 J2000.0 应为 0.606434 周期")
  }
  
  func testMoonMeanAnomalyAtEpoch() {
    let rev = moon_mean_anomoly(jd2000: 0)
    XCTAssertEqual(rev, 0.374897, accuracy: 1e-9,
                   "月亮的平近点角在 J2000.0 应为 0.374897 周期")
  }
  
  func testMoonArgumentOfLatitudeAtEpoch() {
    let rev = moon_argument_of_latitude(jd2000: 0)
    XCTAssertEqual(rev, 0.259091, accuracy: 1e-9,
                   "月亮的纬角论元在 J2000.0 应为 0.259091 周期")
  }
  
  func testMoonMeanElongationFromSunAtEpoch() {
    let rev = moon_mean_elongation_from_sun(jd2000: 0)
    XCTAssertEqual(rev, 0.827362, accuracy: 1e-9,
                   "月亮的平日距在 J2000.0 应为 0.827362 周期")
  }
  
  // MARK: - Sun Elements at J2000
  
  func testSunMeanLongitudeAtEpoch() {
    let rev = sun_mean_longitude(jd2000: 0)
    XCTAssertEqual(rev, 0.779072, accuracy: 1e-9,
                   "太阳的平均黄经在 J2000.0 应为 0.779072 周期")
  }
  
  func testSunMeanAnomalyAtEpoch() {
    let rev = sun_mean_anomoly(jd2000: 0)
    XCTAssertEqual(rev, 0.993126, accuracy: 1e-9,
                   "太阳的平近点角在 J2000.0 应为 0.993126 周期")
  }
  
  // MARK: - Obliquity of the Ecliptic
  
  func testObliquityAtEpoch() {
    let ob = obliquity_of_ecliptic(jd2000: 0)
    // 23°26′21.448″ in radians
    let expected = (23.0 + 26.0/60.0 + 21.448/3600.0) * Double.pi / 180.0
    XCTAssertEqual(ob, expected, accuracy: 1e-12,
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
    XCTAssertEqual(trueRev, meanRev, accuracy: 2e-2,
                   "真黄经应在平均黄经附近 (误差 <0.01 周期)")
  }
}
