//
//  AzimuthTests.swift
//
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Foundation
import Testing
@testable import Astral

@Suite("Azimuth Calculation Tests")
struct AzimuthTests {

  @Test(
    "Azimuth calculation at Greenwich",
    arguments: zip(
      [
        DateComponents.datetime(2022, 10, 6, 1, 10, 0),
        DateComponents.datetime(2022, 10, 6, 16, 45, 0),
        DateComponents.datetime(2022, 10, 10, 6, 43, 0),
        DateComponents.datetime(2022, 10, 10, 3, 0, 0),
      ],
      [240.0, 115.0, 281.0, 235.0]))
  func azimuthAtGreenwich(dt: DateComponents, expected: Double) {
    let observer = Observer(latitude: 51.4733, longitude: -0.0008333, elevation: .double(0))
    let result = azimuth(observer: observer, at: dt)
    #expect(abs(result - expected) < 1)
  }

}
