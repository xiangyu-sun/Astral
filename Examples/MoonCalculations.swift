//
//  MoonCalculations.swift
//
//  Astral Examples
//  Advanced moon calculation examples
//

import Foundation
import Astral

// MARK: - Moon Rise and Set Times

func moonRiseSetExample() {
    print("=== Moon Rise and Set Times ===")
    
    let observer = Observer(latitude: 51.5074, longitude: -0.1278, elevation: .double(0)) // London
    let today = Date().components()
    
    do {
        let moonrise = try moonrise(observer: observer, dateComponents: today)
        let moonset = try moonset(observer: observer, dateComponents: today)
        
        if let rise = moonrise {
            print("Moonrise: \(rise)")
        } else {
            print("No moonrise today (moon doesn't rise)")
        }
        
        if let set = moonset {
            print("Moonset: \(set)")
        } else {
            print("No moonset today (moon doesn't set)")
        }
        
    } catch {
        print("Error calculating moon times: \(error)")
    }
}

// MARK: - Moon Phase Tracking

func moonPhaseTrackingExample() {
    print("\n=== Moon Phase Tracking ===")
    
    let calendar = Calendar.current
    let today = Date()
    
    // Calculate moon phase for the next 30 days
    print("Moon phases for the next 30 days:")
    print("Date\t\tPhase (days)\tDescription")
    print("----------------------------------------")
    
    for i in 0..<30 {
        if let date = calendar.date(byAdding: .day, value: i, to: today) {
            let components = date.components()
            let phase = moonPhase(date: components)
            
            let phaseDescription: String
            if phase < 1.85 {
                phaseDescription = "New Moon"
            } else if phase < 5.54 {
                phaseDescription = "Waxing Crescent"
            } else if phase < 9.23 {
                phaseDescription = "First Quarter"
            } else if phase < 12.92 {
                phaseDescription = "Waxing Gibbous"
            } else if phase < 16.61 {
                phaseDescription = "Full Moon"
            } else if phase < 20.30 {
                phaseDescription = "Waning Gibbous"
            } else if phase < 23.99 {
                phaseDescription = "Last Quarter"
            } else {
                phaseDescription = "Waning Crescent"
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd"
            print("\(dateFormatter.string(from: date))\t\t\(String(format: "%.2f", phase))\t\t\(phaseDescription)")
        }
    }
}

// MARK: - Moon Phase for Specific Dates

func specificDateMoonPhase() {
    print("\n=== Moon Phase for Specific Dates ===")
    
    let importantDates = [
        "2023-01-01", // New Year
        "2023-02-14", // Valentine's Day
        "2023-07-04", // Independence Day
        "2023-12-25"  // Christmas
    ]
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    for dateString in importantDates {
        if let date = dateFormatter.date(from: dateString) {
            let components = date.components()
            let phase = moonPhase(date: components)
            
            print("\(dateString): Moon phase = \(String(format: "%.2f", phase)) days")
        }
    }
}

// MARK: - Moon Visibility Window

func moonVisibilityWindow() {
    print("\n=== Moon Visibility Window ===")
    
    let observer = Observer(latitude: 40.7128, longitude: -74.0060, elevation: .double(0)) // New York
    let today = Date().components()
    
    do {
        let moonrise = try moonrise(observer: observer, dateComponents: today)
        let moonset = try moonset(observer: observer, dateComponents: today)
        
        if let rise = moonrise, let set = moonset {
            print("Moon is visible from \(rise) to \(set)")
            
            // Calculate visibility duration
            let calendar = Calendar.current
            if let riseDate = calendar.date(from: rise),
               let setDate = calendar.date(from: set) {
                let duration = setDate.timeIntervalSince(riseDate)
                let hours = Int(duration / 3600)
                let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
                print("Visibility duration: \(hours)h \(minutes)m")
            }
        } else {
            print("Moon is not visible today (polar day/night or moon doesn't rise/set)")
        }
        
    } catch {
        print("Error calculating moon visibility: \(error)")
    }
}

// MARK: - Run Examples

print("Astral Moon Calculation Examples")
print("================================")

moonRiseSetExample()
moonPhaseTrackingExample()
specificDateMoonPhase()
moonVisibilityWindow()

print("\nMoon examples completed!")
