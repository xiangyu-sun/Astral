//
//  AdvancedFeatures.swift
//
//  Astral Examples
//  Advanced astronomical calculations including twilight, golden hour, and rahukaalam
//

import Foundation
import Astral

// MARK: - Twilight Calculations

func twilightExample() {
    print("=== Twilight Calculations ===")
    
    let observer = Observer(latitude: 51.5074, longitude: -0.1278, elevation: .double(0)) // London
    let today = Date().components()
    
    do {
        // Civil twilight (6° depression)
        let civilDawn = try dawn(observer: observer, date: today, depression: .civil)
        let civilDusk = try dusk(observer: observer, date: today, depression: .civil)
        
        // Nautical twilight (12° depression)
        let nauticalDawn = try dawn(observer: observer, date: today, depression: .nautical)
        let nauticalDusk = try dusk(observer: observer, date: today, depression: .nautical)
        
        // Astronomical twilight (18° depression)
        let astronomicalDawn = try dawn(observer: observer, date: today, depression: .astronomical)
        let astronomicalDusk = try dusk(observer: observer, date: today, depression: .astronomical)
        
        print("Civil Twilight:")
        print("  Dawn: \(civilDawn)")
        print("  Dusk: \(civilDusk)")
        
        print("\nNautical Twilight:")
        print("  Dawn: \(nauticalDawn)")
        print("  Dusk: \(nauticalDusk)")
        
        print("\nAstronomical Twilight:")
        print("  Dawn: \(astronomicalDawn)")
        print("  Dusk: \(astronomicalDusk)")
        
    } catch {
        print("Error calculating twilight: \(error)")
    }
}

// MARK: - Golden Hour and Blue Hour

func goldenHourExample() {
    print("\n=== Golden Hour and Blue Hour ===")
    
    let observer = Observer(latitude: 37.7749, longitude: -122.4194, elevation: .double(0)) // San Francisco
    let today = Date().components()
    
    do {
        // Golden hour (morning)
        let morningGoldenHour = try golden_hour(observer: observer, date: today, direction: .rising)
        print("Morning Golden Hour:")
        print("  Start: \(morningGoldenHour.0)")
        print("  End: \(morningGoldenHour.1)")
        
        // Golden hour (evening)
        let eveningGoldenHour = try golden_hour(observer: observer, date: today, direction: .setting)
        print("\nEvening Golden Hour:")
        print("  Start: \(eveningGoldenHour.0)")
        print("  End: \(eveningGoldenHour.1)")
        
        // Blue hour (morning)
        let morningBlueHour = try blue_hour(observer: observer, date: today, direction: .rising)
        print("\nMorning Blue Hour:")
        print("  Start: \(morningBlueHour.0)")
        print("  End: \(morningBlueHour.1)")
        
        // Blue hour (evening)
        let eveningBlueHour = try blue_hour(observer: observer, date: today, direction: .setting)
        print("\nEvening Blue Hour:")
        print("  Start: \(eveningBlueHour.0)")
        print("  End: \(eveningBlueHour.1)")
        
    } catch {
        print("Error calculating golden/blue hour: \(error)")
    }
}

// MARK: - Rahukaalam Calculation

func rahukaalamExample() {
    print("\n=== Rahukaalam Calculation ===")
    
    let observer = Observer.newDelhi // Using New Delhi as it's relevant for Vedic astrology
    let today = Date().components()
    
    do {
        // Daytime Rahukaalam
        let daytimeRahukaalam = try rahukaalam(observer: observer, date: today, daytime: true)
        print("Daytime Rahukaalam:")
        print("  Start: \(daytimeRahukaalam.0)")
        print("  End: \(daytimeRahukaalam.1)")
        
        // Nighttime Rahukaalam
        let nighttimeRahukaalam = try rahukaalam(observer: observer, date: today, daytime: false)
        print("\nNighttime Rahukaalam:")
        print("  Start: \(nighttimeRahukaalam.0)")
        print("  End: \(nighttimeRahukaalam.1)")
        
    } catch {
        print("Error calculating Rahukaalam: \(error)")
    }
}

// MARK: - Time at Specific Elevation

func timeAtElevationExample() {
    print("\n=== Time at Specific Solar Elevation ===")
    
    let observer = Observer(latitude: 40.7128, longitude: -74.0060, elevation: .double(0)) // New York
    let today = Date().components()
    
    // Find times when sun is at specific elevations
    let elevations = [10.0, 20.0, 30.0, 45.0, 60.0]
    
    for elevation in elevations {
        do {
            let morningTime = time_at_elevation(observer: observer, elevation: elevation, date: today, direction: .rising)
            let eveningTime = time_at_elevation(observer: observer, elevation: elevation, date: today, direction: .setting)
            
            print("Sun at \(elevation)° elevation:")
            print("  Morning: \(morningTime)")
            print("  Evening: \(eveningTime)")
            
        } catch {
            print("Error calculating time at \(elevation)° elevation: \(error)")
        }
    }
}

// MARK: - Daylight and Night Duration

func daylightDurationExample() {
    print("\n=== Daylight and Night Duration ===")
    
    let observer = Observer(latitude: 60.1699, longitude: 24.9384, elevation: .double(0)) // Helsinki
    let today = Date().components()
    
    do {
        // Calculate daylight duration
        let daylight = try daylight(observer: observer, date: today)
        let daylightDuration = calculateDuration(from: daylight.0, to: daylight.1)
        
        // Calculate night duration
        let night = try night(observer: observer, date: today)
        let nightDuration = calculateDuration(from: night.0, to: night.1)
        
        print("Daylight Duration: \(daylightDuration)")
        print("Night Duration: \(nightDuration)")
        
    } catch {
        print("Error calculating daylight/night duration: \(error)")
    }
}

// MARK: - Helper Function

func calculateDuration(from start: DateComponents, to end: DateComponents) -> String {
    let calendar = Calendar.current
    
    guard let startDate = calendar.date(from: start),
          let endDate = calendar.date(from: end) else {
        return "Unable to calculate duration"
    }
    
    let duration = endDate.timeIntervalSince(startDate)
    let hours = Int(duration / 3600)
    let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
    
    return "\(hours)h \(minutes)m"
}

// MARK: - Run Examples

print("Astral Advanced Features Examples")
print("=================================")

twilightExample()
goldenHourExample()
rahukaalamExample()
timeAtElevationExample()
daylightDurationExample()

print("\nAdvanced examples completed!")
