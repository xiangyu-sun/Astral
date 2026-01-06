//
//  SunElevationAdjustmentTests.swift
//
//
//  Created by Xiangyu Sun on 31/1/23.
//

import Testing
@testable import Astral

@Suite("Sun Elevation Adjustment Tests")
struct SunElevationAdjustmentTests {

  @Test("Adjust to horizon with positive elevation")
  func floatPositive() {
    let adjustment = adjust_to_horizon(elevation: 12000)
    #expect(abs(adjustment - 3.5138554650954026) < 0.001)
  }

  @Test("Adjust to horizon with negative elevation")
  func floatNegative() {
    let adjustment = adjust_to_horizon(elevation: -1)
    #expect(adjustment == 0)
  }

  @Test("Adjust to obscuring feature with zero distance")
  func tupleZero() {
    let adjustment = adjust_to_obscuring_feature(elevation: (0.0, 100.0))
    #expect(adjustment == 0)
  }

  @Test("Adjust to obscuring feature - 45 degree angle")
  func tuple45Degrees() {
    let adjustment = adjust_to_obscuring_feature(elevation: (10.0, 10.0))
    #expect(abs(adjustment - 45.0) < 0.001)
  }

  @Test("Adjust to obscuring feature - 30 degree angle")
  func tuple30Degrees() {
    let adjustment = adjust_to_obscuring_feature(elevation: (3.0, 4.0))
    #expect(abs(adjustment - 53.130102354156) < 0.001)
  }

  @Test("Adjust to obscuring feature - negative 45 degree angle")
  func tupleNegative45Degrees() {
    let adjustment = adjust_to_obscuring_feature(elevation: (-10.0, 10.0))
    #expect(abs(adjustment - (-45)) < 0.001)
  }

}
