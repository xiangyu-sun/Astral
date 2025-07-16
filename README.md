# 🌞 Astral

![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-blue)  
![Swift Version](https://img.shields.io/badge/swift-5.0%2B-orange)  
![License](https://img.shields.io/github/license/your-repo/astral)  
![Stars](https://img.shields.io/github/stars/your-repo/astral?style=social)

**Astral** is a Swift library for calculating solar and lunar timings, including sunrise, sunset, twilight phases, moon phases, and more. It is designed for iOS and macOS applications that require astronomical data, such as weather apps, photography tools, home automation, and astrology-related applications.

This project is inspired by the original Python package: [Astral](https://sffjunkie.github.io/astral/).

---

## ✨ Features

- **Sun Calculations** 🌅  
  - Dawn, Sunrise, Solar Noon, Sunset, Dusk, Midnight  
  - Daylight, Twilight, Golden Hour, Blue Hour  
  - Sun’s Elevation, Azimuth, and Zenith  

- **Moon Calculations** 🌙  
  - Moonrise, Moonset  
  - Moon Azimuth, Zenith  
  - Moon Phase  

- **Other Astronomical Calculations** 🔭  
  - Time at a Specific Solar Elevation  
  - Rahukaalam (Inauspicious Time per Indian Vedic Astrology)  

---

## 🚀 Installation

### Swift Package Manager (SPM)

Add **Astral** to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/astral.git", from: "1.0.0")
]
```

Or in **Xcode**:

1. Open your Xcode project.  
2. Go to **File > Swift Packages > Add Package Dependency**.  
3. Enter the repository URL:  

   ```
   https://github.com/your-repo/astral.git
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
let location = Location(latitude: 51.5074, longitude: -0.1278) // London, UK
let sunrise = Astral.calculateSunrise(for: location, on: Date())
let sunset = Astral.calculateSunset(for: location, on: Date())

print("Sunrise: \(sunrise), Sunset: \(sunset)")
```

### Getting Moon Phase

```swift
let moonPhase = Astral.moonPhase(on: Date())
print("Current Moon Phase: \(moonPhase)")
```

### Calculating Solar Position

```swift
let solarAzimuth = Astral.solarAzimuth(for: location, at: Date())
print("Solar Azimuth: \(solarAzimuth)°")
```

---

## 🛠️ Locations Support

Astral comes with a built-in geocoder that provides solar and lunar data for various locations.  
New locations can be added manually using:

```swift
let customLocation = Location(latitude: 37.7749, longitude: -122.4194, name: "San Francisco")
```

---

## 📖 API Reference

The library exposes a handful of helper functions for working with
astronomical data:

- `currentSolarTerm(for:)` – Returns the current solar term index.
- `daysUntilNextSolarTerm(from:)` – Days remaining until the next term.
- `preciseNextSolarTermDate(from:iterations:)` – Exact date of the next term.
- `moon_true_longitude(jd2000:)` – Moon’s true longitude in revolutions.

Refer to the source code for additional utilities.

---

## 🛠️ Contributing

We welcome contributions! To contribute:

1. Fork the repository.  
2. Create a feature branch (`git checkout -b feature-name`).  
3. Commit your changes (`git commit -m "Add feature"`).  
4. Push to the branch (`git push origin feature-name`).  
5. Open a pull request.

---

## 🐟 License

Astral is available under the **MIT License**. See the [`LICENSE`](LICENSE) file for more details.

---

## 🌍 Resources & References

- [Solar Terms - Wikipedia](https://en.wikipedia.org/wiki/Solar_term)  
- [Ecliptic & Sidereal Time](https://en.wikipedia.org/wiki/Sidereal_time)  
- [Ecliptic Coordinate System](https://en.wikipedia.org/wiki/Ecliptic_coordinate_system#Spherical_coordinates)  

---

This README makes the project **approachable, professional, and well-documented**, ensuring developers can **quickly understand, install, and use** Astral. Let me know if you’d like any refinements! 🚀
