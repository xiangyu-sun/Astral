import Foundation
import Testing
@testable import Astral

@Suite("Moon and Sun Orbital Calculations", .tags(.lunar, .solar, .fast))
struct Moon2Tests {

  // MARK: - Mean Elements at J2000

  @Test("Moon mean longitude at J2000 epoch", .tags(.conversion, .accuracy, .unit))
  func moonMeanLongitudeAtEpoch() {
    let rev = moon_mean_longitude(jd2000: 0)
    #expect(abs(rev - 0.606434) < 1e-9)
  }

  @Test("Moon mean anomaly at J2000 epoch", .tags(.conversion, .accuracy, .unit))
  func moonMeanAnomalyAtEpoch() {
    let rev = moon_mean_anomaly(jd2000: 0)
    #expect(abs(rev - 0.374897) < 1e-9)
  }

  @Test("Moon argument of latitude at J2000 epoch", .tags(.conversion, .accuracy, .unit))
  func moonArgumentOfLatitudeAtEpoch() {
    let rev = moon_argument_of_latitude(jd2000: 0)
    #expect(abs(rev - 0.259091) < 1e-9)
  }

  @Test("Moon mean elongation from sun at J2000 epoch", .tags(.conversion, .accuracy, .unit))
  func moonMeanElongationFromSunAtEpoch() {
    let rev = moon_mean_elongation_from_sun(jd2000: 0)
    #expect(abs(rev - 0.827362) < 1e-9)
  }

  // MARK: - Sun Elements at J2000

  @Test("Sun mean longitude at J2000 epoch", .tags(.conversion, .accuracy, .unit))
  func sunMeanLongitudeAtEpoch() {
    let rev = sun_mean_longitude(jd2000: 0)
    #expect(abs(rev - 0.779072) < 1e-9)
  }

  @Test("Sun mean anomaly at J2000 epoch", .tags(.conversion, .accuracy, .unit))
  func sunMeanAnomalyAtEpoch() {
    let rev = sun_mean_anomoly(jd2000: 0)
    #expect(abs(rev - 0.993126) < 1e-9)
  }

  // MARK: - Obliquity of the Ecliptic

  @Test("Obliquity of ecliptic at J2000 epoch", .tags(.conversion, .accuracy, .unit))
  func obliquityAtEpoch() {
    let ob = obliquity_of_ecliptic(jd2000: 0)
    // 23°26′21.448″ in radians
    let expected = (23.0 + 26.0 / 60.0 + 21.448 / 3600.0) * Double.pi / 180.0
    #expect(abs(ob - expected) < 1e-12)
  }

  // MARK: - True Ecliptic Longitude

  @Test("Moon true longitude is within valid range", .tags(.validation, .unit))
  func moonTrueLongitudeRange() {
    let rev = moon_true_longitude(jd2000: 0)
    #expect(rev >= 0.0)
    #expect(rev < 1.0)
  }

  @Test("Moon true longitude approximately equals mean at epoch", .tags(.accuracy, .unit))
  func moonTrueLongitudeApproxEqualsMean() {
    let meanRev = moon_mean_longitude(jd2000: 0)
    let trueRev = moon_true_longitude(jd2000: 0)
    // At J2000.0, true longitude should be very close to mean longitude
    #expect(abs(trueRev - meanRev) < 2e-2)
  }

  @Test(
    "Moon true longitude with reference data",
    .tags(.accuracy, .unit),
    arguments: zip(
      [8765.5, 8845.5, 8937.5, 9031.5, 9120.5],
      [156.017016, 134.275040, 257.045540, 67.971129, 158.411401]))
  func moonTrueLongitudeWithReferenceData(jd2000: Double, expectedDegrees: Double) {
    let calculatedRevolutions = moon_true_longitude(jd2000: jd2000)
    let calculatedDegrees = calculatedRevolutions * 360.0

    // Allow for 3-degree tolerance given the complexity of lunar calculations
    // Test data for 2024 equinoxes and solstices
    let tolerance = 3.0
    #expect(abs(calculatedDegrees - expectedDegrees) < tolerance)
  }

  @Test("Moon true longitude returns consistent results", .tags(.accuracy, .unit))
  func moonTrueLongitudeConsistency() {
    let jd2000 = 8765.5 // 2024-01-01
    let result1 = moon_true_longitude(jd2000: jd2000)
    let result2 = moon_true_longitude(jd2000: jd2000)

    #expect(abs(result1 - result2) < 1e-15)
  }

  @Test(
    "Moon true longitude normalization across dates",
    .tags(.validation, .edge, .unit),
    arguments: [-10000.0, -1000.0, -100.0, 0.0, 100.0, 1000.0, 10000.0])
  func moonTrueLongitudeNormalization(jd2000: Double) {
    let longitude = moon_true_longitude(jd2000: jd2000)
    #expect(longitude >= 0.0)
    #expect(longitude < 1.0)
  }

  @Test("Moon true longitude generally increases with time", .tags(.validation, .unit))
  func moonTrueLongitudeMonotonicity() {
    // Test that longitude generally increases with time (over short intervals)
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

    // Expect at least 80% of samples to show increasing longitude
    #expect(increasingCount > totalTests * 8 / 10)
  }
}
