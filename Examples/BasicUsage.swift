//
//  BasicUsage.swift
//
//  Astral Examples
//  Basic usage examples for solar and lunar calculations
//

import Astral
import Foundation

// MARK: - Basic Solar Calculations

func basicSolarExample() {
  print("=== Basic Solar Calculations ===")

  // Create an observer for London
  let london = Observer(latitude: 51.5074, longitude: -0.1278, elevation: .double(0))
  let today = Date().components()

  do {
    // Calculate sunrise and sunset
    let sunrise = try sunrise(observer: london, date: today)
    let sunset = try sunset(observer: london, date: today)

    print("London Sunrise: \(sunrise)")
    print("London Sunset: \(sunset)")

    // Calculate solar noon and midnight
    let noon = noon(observer: london, date: today)
    let midnight = midnight(observer: london, date: today)

    print("Solar Noon: \(noon)")
    print("Solar Midnight: \(midnight)")

  } catch {
    print("Error calculating solar times: \(error)")
  }
}

// MARK: - Moon Phase Example

func moonPhaseExample() {
  print("\n=== Moon Phase Calculation ===")

  let today = Date().components()
  let phase = moonPhase(date: today)

  print("Current moon phase: \(String(format: "%.2f", phase)) days")

  // Interpret the phase
  if phase < 7.38 {
    print("Phase: New Moon to First Quarter")
  } else if phase < 14.77 {
    print("Phase: First Quarter to Full Moon")
  } else if phase < 22.15 {
    print("Phase: Full Moon to Last Quarter")
  } else {
    print("Phase: Last Quarter to New Moon")
  }
}

// MARK: - Using Predefined Locations

func predefinedLocationsExample() {
  print("\n=== Predefined Locations ===")

  let locations = [
    ("London", Observer.london),
    ("New Delhi", Observer.newDelhi),
    ("Riyadh", Observer.riyadh),
    ("Wellington", Observer.wellington),
    ("Barcelona", Observer.barcelona),
  ]

  let today = Date().components()

  for (name, observer) in locations {
    do {
      let sunrise = try sunrise(observer: observer, date: today)
      let sunset = try sunset(observer: observer, date: today)

      print("\(name): Sunrise \(sunrise), Sunset \(sunset)")
    } catch {
      print("\(name): Error calculating times - \(error)")
    }
  }
}

// MARK: - Solar Position Example

func solarPositionExample() {
  print("\n=== Solar Position Calculation ===")

  let observer = Observer(latitude: 51.5074, longitude: -0.1278, elevation: .double(0))
  let now = Date().components()

  // Calculate current solar position
  let solarZenith = zenith(observer: observer, dateandtime: now)
  let solarAzimuth = azimuth(observer: observer, dateandtime: now)
  let solarElevation = elevation(observer: observer, dateandtime: now)

  print("Current Solar Position:")
  print("  Zenith: \(String(format: "%.2f", solarZenith))°")
  print("  Azimuth: \(String(format: "%.2f", solarAzimuth))°")
  print("  Elevation: \(String(format: "%.2f", solarElevation))°")
}

// MARK: - Run Examples

print("Astral Library Examples")
print("======================")

basicSolarExample()
moonPhaseExample()
predefinedLocationsExample()
solarPositionExample()

print("\nExamples completed!")
