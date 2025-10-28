# Architecture

This document describes the architecture and algorithms used in the Astral library for astronomical calculations.

## Overview

Astral is a Swift library that provides accurate astronomical calculations for solar and lunar events. The library is designed to be lightweight, fast, and easy to use while maintaining high accuracy for most practical applications.

## Core Components

### Observer (`Observer.swift`)

The `Observer` struct represents a geographical location on Earth with:
- **Latitude**: Geographic latitude in degrees (-90° to +90°)
- **Longitude**: Geographic longitude in degrees (-180° to +180°)  
- **Elevation**: Height above sea level or obscuring feature information

The observer is the fundamental input for all astronomical calculations.

### Solar Calculations (`Sun.swift`)

Solar calculations are based on the algorithms described in:
- **Jean Meeus**: "Astronomical Algorithms" (2nd Edition)
- **US Naval Observatory**: Astronomical Almanac algorithms

#### Key Algorithms

**Geometric Mean Longitude of the Sun**
```
L₀ = 280.46646 + JC × (36000.76983 + 0.0003032 × JC)
```

**Sun's Declination**
```
δ = arcsin(sin(ε) × sin(λ))
```
Where ε is the obliquity of the ecliptic and λ is the sun's apparent longitude.

**Hour Angle Calculation**
```
cos(H) = [cos(zenith) - sin(lat) × sin(δ)] / [cos(lat) × cos(δ)]
```

#### Accuracy

- **Solar times**: ±1 minute for most locations
- **Solar position**: ±0.1° for azimuth and elevation
- **Valid range**: All latitudes except extreme polar regions

### Lunar Calculations (`Moon.swift`)

Lunar calculations use the ELP-2000 lunar series with simplified orbital elements:

#### Key Algorithms

**Moon's Mean Longitude**
```
L = 0.606434 + 0.03660110129 × JD2000
```

**Moon's Mean Anomaly**
```
M = 0.374897 + 0.03629164709 × JD2000
```

**Moon Position Calculation**
Uses iterative refinement with parallax corrections for Earth-based observations.

#### Accuracy

- **Lunar times**: ±2-5 minutes depending on location
- **Lunar position**: ±0.5° for azimuth and elevation
- **Moon phase**: ±0.1 days

### Time Systems (`Julian.swift`)

The library uses Julian Day numbers as the fundamental time system:

**Julian Day Calculation**
```
JD = 367 × Y - ⌊(7 × (Y + ⌊(M + 9) / 12⌋)) / 4⌋ + ⌊(275 × M) / 9⌋ + D + 1721013.5 + H / 24
```

**Julian Century**
```
T = (JD - 2451545.0) / 36525.0
```

## Coordinate Systems

### Geographic Coordinates

- **Latitude**: Positive = North, Negative = South
- **Longitude**: Positive = East, Negative = West
- **Elevation**: Height in meters above sea level

### Astronomical Coordinates

- **Azimuth**: 0° = North, 90° = East, 180° = South, 270° = West
- **Elevation**: 0° = Horizon, 90° = Zenith
- **Zenith**: 0° = Zenith, 90° = Horizon

## Error Handling

### SunError

- `valueError(String)`: Occurs when calculations are impossible (e.g., polar regions)

### MoonError  

- `invalidData(String)`: Occurs when moon doesn't rise/set or invalid input

## Atmospheric Refraction

The library includes atmospheric refraction corrections:

**Refraction at Zenith**
```
R = 1.02 / tan(h + 10.3 / (h + 5.11))
```
Where h is the apparent elevation in degrees.

## Elevation Adjustments

### Horizon Adjustment

For observers above sea level:
```
dip = arccos(R / (R + h))
```
Where R is Earth's radius and h is observer elevation.

### Obscuring Features

For locations with nearby mountains or buildings:
```
adjustment = arctan(vertical_offset / horizontal_distance)
```

## Performance Considerations

### Optimization Strategies

1. **Caching**: Julian Day calculations are cached when possible
2. **Iterative Refinement**: Transit calculations use Newton-Raphson method
3. **Precomputed Tables**: Lunar series coefficients are precomputed
4. **Minimal Dependencies**: Only essential mathematical functions are used

### Memory Usage

- **Observer**: ~100 bytes
- **DateComponents**: ~200 bytes  
- **Calculation results**: ~50 bytes per result

## Testing Strategy

### Test Data Sources

- **US Naval Observatory**: Reference astronomical data
- **NOAA Solar Calculator**: Validation data
- **Published Astronomical Tables**: Historical verification

### Accuracy Validation

- **Solar calculations**: Tested against USNO data
- **Lunar calculations**: Validated against published ephemeris
- **Edge cases**: Polar regions, date boundaries, leap years

## Limitations

### Known Limitations

1. **Polar Regions**: Some calculations may fail near the poles
2. **Historical Dates**: Accuracy decreases for dates before 1900
3. **Future Dates**: Accuracy decreases for dates after 2100
4. **Lunar Perturbations**: Complex lunar calculations may have higher error margins

### Recommended Usage

- **Solar calculations**: Suitable for most applications
- **Lunar calculations**: Good for general use, verify critical applications
- **Photography**: Excellent for golden hour and blue hour calculations
- **Astrology**: Suitable for basic calculations

## Future Improvements

### Planned Enhancements

1. **Higher Precision**: Implement more accurate lunar algorithms
2. **Planetary Positions**: Add support for other planets
3. **Eclipse Calculations**: Solar and lunar eclipse predictions
4. **Time Zone Handling**: Improved timezone conversion utilities

### Performance Optimizations

1. **SIMD Instructions**: Vectorized calculations for batch processing
2. **GPU Acceleration**: Metal compute shaders for intensive calculations
3. **Lazy Evaluation**: On-demand calculation of expensive operations

## References

### Primary Sources

1. **Meeus, Jean**: "Astronomical Algorithms" (2nd Edition, 1998)
2. **US Naval Observatory**: "Astronomical Almanac" (annual publication)
3. **Chapront-Touzé, M. & Chapront, J.**: "ELP-2000 lunar series"

### Online Resources

1. **US Naval Observatory**: https://www.usno.navy.mil/
2. **NOAA Solar Calculator**: https://www.esrl.noaa.gov/gmd/grad/solcalc/
3. **Astronomical Algorithms**: https://www.celestialprogramming.com/

### Software Inspiration

1. **Python Astral**: https://sffjunkie.github.io/astral/
2. **SunCalc.js**: https://github.com/mourner/suncalc
3. **AstroPy**: https://www.astropy.org/
