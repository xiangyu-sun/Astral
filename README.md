# 🌞 Astral

![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS-blue)  
![Swift Version](https://img.shields.io/badge/swift-6.0%2B-orange)  
![License](https://img.shields.io/github/license/sunxiangyu/astral)  
![Build Status](https://img.shields.io/github/workflow/status/sunxiangyu/astral/CI/main)

**Astral** is a Swift library for calculating solar and lunar timings, including sunrise, sunset, twilight phases, moon phases, and more. It is designed for iOS and macOS applications that require astronomical data, such as weather apps, photography tools, home automation, and astrology-related applications.

This project is inspired by the original Python package: [Astral](https://sffjunkie.github.io/astral/).

---

## ✨ Features

- **Sun Calculations** 🌅  
  - Dawn, Sunrise, Solar Noon, Sunset, Dusk, Midnight  
  - Daylight, Twilight, Golden Hour, Blue Hour  
  - Sun's Elevation, Azimuth, and Zenith  

- **Moon Calculations** 🌙  
  - Moonrise, Moonset  
  - Moon Azimuth, Zenith  
  - Moon Phase  

- **Planetary Positions** 🪐  
  - Heliocentric positions of Mercury–Neptune, Earth and the Moon (JPL element tables, 1800–2050)  
  - Geocentric Moon from mean elements, periodic terms, or Astral's lunar series  
  - Moon phase geometry, body orientation (Earth rotation, tidal lock)  

- **Other Astronomical Calculations** 🔭  
  - Time at a Specific Solar Elevation  
  - Rahukaalam (Inauspicious Time per Indian Vedic Astrology)  

---

## 🚀 Installation

### Swift Package Manager (SPM)

Add **Astral** to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/sunxiangyu/astral.git", from: "1.0.0")
]
```

Or in **Xcode**:

1. Open your Xcode project.  
2. Go to **File > Swift Packages > Add Package Dependency**.  
3. Enter the repository URL:  

   ```
   https://github.com/sunxiangyu/astral.git
   ```

4. Choose a version and add it to your project.

---

## 📚 Usage

### Importing Astral

```swift
import Astral
```

### Calculating Sunrise & Sunset

```swift
let observer = Observer(latitude: 51.5074, longitude: -0.1278, elevation: .double(0)) // London, UK
let date = Date().components()

do {
    let sunrise = try sunrise(observer: observer, date: date)
    let sunset = try sunset(observer: observer, date: date)
    print("Sunrise: \(sunrise), Sunset: \(sunset)")
} catch {
    print("Error calculating sun times: \(error)")
}
```

### Getting Moon Phase

```swift
let moonPhase = moonPhase(date: Date().components())
print("Current Moon Phase: \(moonPhase) days")
```

### Calculating Solar Position

```swift
let observer = Observer(latitude: 51.5074, longitude: -0.1278, elevation: .double(0))
let solarAzimuth = azimuth(observer: observer, dateandtime: Date().components())
print("Solar Azimuth: \(solarAzimuth)°")
```

### Using Predefined Locations

```swift
let londonObserver = Observer.london
let sunrise = try sunrise(observer: londonObserver, date: Date().components())
print("London sunrise: \(sunrise)")
```

### Twilight Calculations

```swift
let observer = Observer(latitude: 51.5074, longitude: -0.1278, elevation: .double(0))
let date = Date().components()

do {
    let civilDawn = try dawn(observer: observer, date: date, depression: .civil)
    let civilDusk = try dusk(observer: observer, date: date, depression: .civil)
    print("Civil dawn: \(civilDawn), Civil dusk: \(civilDusk)")
} catch {
    print("Error calculating twilight: \(error)")
}
```

---

## 🪐 Planetary positions

`SolarSystem` computes the position of every body as a pure function of the date, in the heliocentric J2000
ecliptic frame (AU). The planets use JPL's "Approximate Positions of the Planets" element tables (valid
1800–2050); the Moon can use mean elements, mean elements plus periodic terms (the default), or Astral's lunar
series (`.series`, accurate to well under an arcminute against JPL Horizons).

```swift
import Astral
import simd

let system = SolarSystem()                        // Sun, Mercury–Neptune, Earth and its Moon
let snapshot = system.snapshot(at: JulianDate(Date()))

if let mars = snapshot.position(of: .mars) {
    print("Mars is \(simd_length(mars)) AU from the Sun")
}

// Moon phase from the Sun–Earth–Moon geometry
let phase = MoonPhase(date: Date())
print(phase.name, phase.illuminatedFraction)      // e.g. .waxingGibbous 0.83

// Highest-accuracy Moon, and the Moon's geocentric vector in AU
let precise = SolarSystem(moonModel: .series)
let moonFromEarth = MoonEphemeris.geocentricPositionSeries(at: JulianDate(Date()))
```

| Moon model | Longitude error vs JPL Horizons | Distance error |
|------------|---------------------------------|----------------|
| `.meanElements` | up to ~1.5° | up to ~1.4 % |
| `.periodicTerms` (default) | up to ~0.1° | up to ~1.4 % |
| `.series` | up to ~40″ | up to ~0.006 % |

`JulianDate` is also a bridge to the rest of Astral: `JulianDate(Date)`, `JulianDate(DateComponents)`, and
`centuriesSinceJ2000`. Note that `MoonPhase` (a type) coexists with the existing `moonPhase(date:)` function, which
returns the Moon's age in days.

---

## 🛠️ Locations Support

Astral comes with predefined observer locations:

```swift
Observer.london      // London, UK
Observer.newDelhi    // New Delhi, India  
Observer.riyadh      // Riyadh, Saudi Arabia
Observer.wellington  // Wellington, New Zealand
Observer.barcelona   // Barcelona, Spain
```

You can also create custom locations:

```swift
let customObserver = Observer(latitude: 37.7749, longitude: -122.4194, elevation: .double(0))
```

---

## 📖 API Reference

### Core Types

- `Observer` - Represents a geographical location with latitude, longitude, and elevation
- `LocationInfo` - Location with timezone information
- `Elevation` - Elevation specification (simple height or tuple for obscuring features)
- `Depression` - Twilight depression angles (civil, nautical, astronomical)
- `SunDirection` - Direction for calculations (rising, setting)
- `JulianDate`, `SolarSystem`, `SystemSnapshot`, `BodyState`, `BodyID`, `Body`, `Catalog`, `OrbitalElements`, `Kepler`,
  `MoonEphemeris`, `MoonModel`, `MoonPhase`, `BodyOrientation`, `Units` - Planetary ephemeris API

### Main Functions

- `sunrise(observer:date:tzinfo:)` – Calculate sunrise time
- `sunset(observer:date:tzinfo:)` – Calculate sunset time  
- `dawn(observer:date:depression:tzinfo:)` – Calculate dawn time
- `dusk(observer:date:depression:tzinfo:)` – Calculate dusk time
- `noon(observer:date:tzinfo:)` – Calculate solar noon
- `midnight(observer:date:tzinfo:)` – Calculate solar midnight
- `moonrise(observer:dateComponents:tzinfo:)` – Calculate moonrise time
- `moonset(observer:dateComponents:tzinfo:)` – Calculate moonset time
- `moonPhase(date:)` – Calculate moon phase age in days
- `zenith(observer:dateandtime:with_refraction:)` – Calculate solar zenith angle
- `azimuth(observer:dateandtime:)` – Calculate solar azimuth angle
- `elevation(observer:dateandtime:with_refraction:)` – Calculate solar elevation angle

Refer to the source code for additional utilities and detailed documentation.

---

## 🧪 Testing

Run the test suite to verify everything works:

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter SunCalcTests

# Run with code coverage
swift test --enable-code-coverage
```

---

## 🛠️ Contributing

We welcome contributions! To contribute:

1. Fork the repository.  
2. Create a feature branch (`git checkout -b feature-name`).  
3. Commit your changes (`git commit -m "Add feature"`).  
4. Push to the branch (`git push origin feature-name`).  
5. Open a pull request.

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## 🐟 License

Astral is available under the **MIT License**. See the [`LICENSE`](LICENSE) file for more details.

---

## 🌍 Resources & References

- [Solar Terms - Wikipedia](https://en.wikipedia.org/wiki/Solar_term)  
- [Ecliptic & Sidereal Time](https://en.wikipedia.org/wiki/Sidereal_time)  
- [Ecliptic Coordinate System](https://en.wikipedia.org/wiki/Ecliptic_coordinate_system#Spherical_coordinates)  
- [Python Astral Package](https://sffjunkie.github.io/astral/) - Original inspiration

---

## ⚠️ Troubleshooting

### Common Issues

**"Unable to find sunrise/sunset time"**
- This typically occurs in polar regions where the sun doesn't rise or set
- Check if your latitude is within reasonable bounds (±66.5°)

**"InvalidData" errors for moon calculations**
- Some locations may not have moonrise/moonset on certain dates
- This is normal astronomical behavior

**Accuracy concerns**
- Solar calculations are accurate to approximately ±1 minute
- Lunar calculations may vary more due to orbital perturbations
- For critical applications, consider validating against published astronomical tables

---

## 📊 Platform Support

| Platform | Minimum Version |
|----------|----------------|
| macOS    | 10.13+         |
| iOS      | 13.0+          |
| watchOS  | 5.0+           |
| Swift    | 6.0+ (Xcode 16+) |

---

