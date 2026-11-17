//
//  SmallBody.swift
//

import Foundation
import simd

// MARK: - SmallBodyError

/// Why a ``SmallBody`` could not be created.
public enum SmallBodyError: Error, Sendable, Hashable {
  /// The data is not a JSON object of the expected shape.
  case invalidJSON
  /// The Small-Body Database answered with a message instead of an orbit (e.g. the object was not found).
  case objectNotFound(message: String)
  /// The response carries no orbit.
  case missingOrbit
  /// A required element is absent from the response.
  case missingElement(String)
  /// An element has a value that cannot describe an orbit (non-finite, `e < 0`, `q ≤ 0`, ...).
  case invalidElement(String)
  /// The elements are not referred to the J2000 ecliptic and equinox.
  case unsupportedEquinox(String)
}

// MARK: - OrbitKind

/// The shape of a conic orbit.
public enum OrbitKind: Sendable, Hashable {
  case elliptic, parabolic, hyperbolic
}

// MARK: - SmallBody

/// An asteroid or a comet, described by osculating elements as published by the JPL Small-Body Database (SBDB).
///
/// Conventions are those of SBDB: heliocentric elements referred to the **J2000 ecliptic and equinox**, distances
/// in AU, angles in degrees, times as Julian dates in **TDB**. The ephemeris API as a whole treats ``JulianDate``
/// as TDB (see ``JulianDate``), so a `JulianDate` can be passed straight to ``position(at:)``.
///
/// The orbit is propagated as a pure two-body problem about the Sun, with the Gaussian gravitational constant
/// ``Kepler/gaussianGravitationalConstant`` (`GM☉ = k²`). Elliptic, parabolic and hyperbolic orbits are all
/// supported (universal variables, see ``Kepler/perifocalState(perihelionDistance:eccentricity:daysSincePerihelion:)``).
///
/// Planetary perturbations and the non-gravitational forces of comets are not modelled, so the error grows with
/// the distance in time from ``epoch``: a few 1e-7 AU at the epoch itself and typically 1e-4 AU to 1e-2 AU some
/// weeks away, depending on how close the body passes a planet (or the Sun, for a comet). Use elements whose
/// epoch is near the date of interest, as SBDB publishes them.
///
/// ```swift
/// let json = try Data(contentsOf: ceresSBDBResponse)      // from https://ssd-api.jpl.nasa.gov/sbdb.api?sstr=Ceres&full-prec=1
/// let ceres = try SmallBody(sbdbJSON: json)
/// let p = ceres.position(at: JulianDate(Date()))          // heliocentric J2000 ecliptic, AU
/// ```
public struct SmallBody: Sendable, Hashable {

  // MARK: Lifecycle

  /// Creates a body from the elements of a conic, as published for comets: perihelion distance and time.
  ///
  /// - Parameters:
  ///   - name: A display name, e.g. `"1 Ceres (A801 AA)"`.
  ///   - epoch: The osculation epoch (JD, TDB).
  ///   - eccentricity: `e ≥ 0`. `e = 1` is a parabola.
  ///   - perihelionDistance: `q`, AU, positive.
  ///   - inclination: `i`, degrees.
  ///   - longitudeOfAscendingNode: `Ω`, degrees.
  ///   - argumentOfPerihelion: `ω`, degrees.
  ///   - timeOfPerihelion: `T`, the time of perihelion passage (JD, TDB).
  /// - Throws: ``SmallBodyError/invalidElement(_:)`` if a value is not finite, `e < 0` or `q ≤ 0`.
  public init(
    name: String? = nil,
    epoch: JulianDate,
    eccentricity: Double,
    perihelionDistance: Double,
    inclination: Double,
    longitudeOfAscendingNode: Double,
    argumentOfPerihelion: Double,
    timeOfPerihelion: JulianDate)
    throws
  {
    let values = [
      epoch.days, eccentricity, perihelionDistance, inclination, longitudeOfAscendingNode, argumentOfPerihelion,
      timeOfPerihelion.days,
    ]
    guard values.allSatisfy(\.isFinite) else { throw SmallBodyError.invalidElement("non-finite value") }
    guard eccentricity >= 0 else { throw SmallBodyError.invalidElement("e") }
    guard perihelionDistance > 0 else { throw SmallBodyError.invalidElement("q") }
    self.name = name
    self.epoch = epoch
    self.eccentricity = eccentricity
    self.perihelionDistance = perihelionDistance
    self.inclination = inclination
    self.longitudeOfAscendingNode = longitudeOfAscendingNode
    self.argumentOfPerihelion = argumentOfPerihelion
    self.timeOfPerihelion = timeOfPerihelion
  }

  /// Creates a body from the elements published for asteroids: semi-major axis and mean anomaly at the epoch.
  ///
  /// For a hyperbola (`e > 1`) `semiMajorAxis` is negative, as in SBDB, and `meanAnomaly` is the hyperbolic mean
  /// anomaly `e·sinh H − H` (in degrees), as in SBDB. Mean motion is `k / |a|^1.5`.
  ///
  /// - Parameters:
  ///   - semiMajorAxis: `a`, AU; positive for an ellipse, negative for a hyperbola. `e = 1` has no semi-major
  ///     axis: use the initializer taking the perihelion distance.
  ///   - meanAnomaly: `M` at `epoch`, degrees.
  /// - Throws: ``SmallBodyError/invalidElement(_:)`` if the values are inconsistent (e.g. `a < 0` with `e < 1`).
  public init(
    name: String? = nil,
    epoch: JulianDate,
    eccentricity: Double,
    semiMajorAxis: Double,
    inclination: Double,
    longitudeOfAscendingNode: Double,
    argumentOfPerihelion: Double,
    meanAnomaly: Double)
    throws
  {
    guard semiMajorAxis.isFinite, meanAnomaly.isFinite, eccentricity.isFinite else {
      throw SmallBodyError.invalidElement("non-finite value")
    }
    guard eccentricity != 1 else { throw SmallBodyError.invalidElement("a (undefined for e = 1)") }
    guard (eccentricity < 1) == (semiMajorAxis > 0), semiMajorAxis != 0 else {
      throw SmallBodyError.invalidElement("a (sign inconsistent with e)")
    }
    let n = Kepler.gaussianGravitationalConstant / (abs(semiMajorAxis) * abs(semiMajorAxis).squareRoot())
    var M = meanAnomaly * Units.degToRad
    if eccentricity < 1 { M = Kepler.wrapPi(M) }
    try self.init(
      name: name,
      epoch: epoch,
      eccentricity: eccentricity,
      perihelionDistance: semiMajorAxis * (1 - eccentricity),
      inclination: inclination,
      longitudeOfAscendingNode: longitudeOfAscendingNode,
      argumentOfPerihelion: argumentOfPerihelion,
      timeOfPerihelion: JulianDate(days: epoch.days - M / n))
  }

  /// Creates a body from the response of the SBDB API, `https://ssd-api.jpl.nasa.gov/sbdb.api?sstr=<id>`.
  ///
  /// Pass `full-prec=1` in the request to get full-precision values; without it SBDB rounds every element to a
  /// few digits, which is not enough for a position better than about 1e-3 AU. This library does no networking:
  /// fetch the data yourself and hand it over. See <https://ssd-api.jpl.nasa.gov/doc/sbdb.html>.
  ///
  /// Reads `object.fullname` and `orbit.epoch`, and from `orbit.elements` the entries `e`, `i`, `om`, `w` and
  /// either `q` and `tp` (the preferred, universal pair, always present for comets) or `a` and `ma`.
  ///
  /// - Throws: ``SmallBodyError``.
  public init(sbdbJSON data: Data) throws {
    let response: SBDBResponse
    do {
      response = try JSONDecoder().decode(SBDBResponse.self, from: data)
    } catch {
      throw SmallBodyError.invalidJSON
    }
    guard let orbit = response.orbit else {
      if let message = response.message { throw SmallBodyError.objectNotFound(message: message) }
      throw SmallBodyError.missingOrbit
    }
    if let equinox = orbit.equinox, equinox != "J2000" {
      throw SmallBodyError.unsupportedEquinox(equinox)
    }
    guard let epoch = orbit.epoch else { throw SmallBodyError.missingElement("epoch") }
    var elements: [String: Double] = [:]
    for element in orbit.elements ?? [] {
      if let value = element.value { elements[element.name] = value }
    }
    func required(_ key: String) throws -> Double {
      guard let value = elements[key] else { throw SmallBodyError.missingElement(key) }
      return value
    }
    let name = response.object?.fullname ?? response.object?.shortname
    let e = try required("e")
    let i = try required("i")
    let node = try required("om")
    let peri = try required("w")
    if let q = elements["q"], let tp = elements["tp"] {
      try self.init(
        name: name, epoch: JulianDate(days: epoch), eccentricity: e, perihelionDistance: q, inclination: i,
        longitudeOfAscendingNode: node, argumentOfPerihelion: peri, timeOfPerihelion: JulianDate(days: tp))
    } else if let a = elements["a"], let ma = elements["ma"] {
      try self.init(
        name: name, epoch: JulianDate(days: epoch), eccentricity: e, semiMajorAxis: a, inclination: i,
        longitudeOfAscendingNode: node, argumentOfPerihelion: peri, meanAnomaly: ma)
    } else {
      throw SmallBodyError.missingElement("q and tp (or a and ma)")
    }
  }

  // MARK: Public

  /// A display name, when known (`"433 Eros (A898 PA)"`).
  public let name: String?
  /// The osculation epoch (JD, TDB).
  public let epoch: JulianDate
  /// Eccentricity.
  public let eccentricity: Double
  /// Perihelion distance, AU.
  public let perihelionDistance: Double
  /// Inclination to the J2000 ecliptic, degrees.
  public let inclination: Double
  /// Longitude of the ascending node, degrees.
  public let longitudeOfAscendingNode: Double
  /// Argument of perihelion, degrees.
  public let argumentOfPerihelion: Double
  /// Time of perihelion passage (JD, TDB). For an ellipse this is one of the (equivalent) perihelion passages.
  public let timeOfPerihelion: JulianDate

  /// Whether the orbit is an ellipse, a parabola or a hyperbola.
  public var kind: OrbitKind {
    eccentricity < 1 ? .elliptic : (eccentricity == 1 ? .parabolic : .hyperbolic)
  }

  /// Semi-major axis, AU: positive for an ellipse, negative for a hyperbola, `nil` for a parabola.
  public var semiMajorAxis: Double? {
    eccentricity == 1 ? nil : perihelionDistance / (1 - eccentricity)
  }

  /// Aphelion distance, AU (ellipses only).
  public var aphelionDistance: Double? {
    kind == .elliptic ? perihelionDistance * (1 + eccentricity) / (1 - eccentricity) : nil
  }

  /// Sidereal period, days (ellipses only).
  public var period: Double? {
    guard let a = semiMajorAxis, kind == .elliptic else { return nil }
    return 2 * .pi * a * a.squareRoot() / Kepler.gaussianGravitationalConstant
  }

  /// Mean motion in degrees per day, `k / |a|^1.5` (`nil` for a parabola).
  public var meanMotion: Double? {
    guard let a = semiMajorAxis else { return nil }
    return Kepler.gaussianGravitationalConstant / (abs(a) * abs(a).squareRoot()) / Units.degToRad
  }

  /// The mean anomaly at `time`, degrees: `n·(t − T)` wrapped to `[−180, 180]` for an ellipse, the unwrapped
  /// hyperbolic mean anomaly `e·sinh H − H` for a hyperbola, and `nil` for a parabola.
  public func meanAnomaly(at time: JulianDate) -> Double? {
    guard let n = meanMotion else { return nil }
    let M = n * (time.days - timeOfPerihelion.days)
    return kind == .elliptic ? Kepler.wrapPi(M * Units.degToRad) / Units.degToRad : M
  }

  /// Heliocentric position at `time` (JD, TDB) in the J2000 ecliptic frame, AU.
  public func position(at time: JulianDate) -> SIMD3<Double> {
    state(at: time).position
  }

  /// Heliocentric position (AU) and velocity (AU/day) at `time` (JD, TDB) in the J2000 ecliptic frame.
  public func state(at time: JulianDate) -> (position: SIMD3<Double>, velocity: SIMD3<Double>) {
    let pf = Kepler.perifocalState(
      perihelionDistance: perihelionDistance,
      eccentricity: eccentricity,
      daysSincePerihelion: time.days - timeOfPerihelion.days)
    return (rotateToEcliptic(pf.position), rotateToEcliptic(pf.velocity))
  }

  /// Points of the orbit outline in the J2000 ecliptic frame, AU.
  ///
  /// An ellipse is sampled uniformly in true anomaly over a full revolution, starting at perihelion (the caller
  /// closes the loop). A parabola or hyperbola is sampled from branch to branch across perihelion, inclusive, up
  /// to `maxRadius`.
  ///
  /// - Parameters:
  ///   - samples: The number of points (at least 2).
  ///   - maxRadius: The largest heliocentric distance drawn for open orbits, AU. Ignored for ellipses.
  public func orbitPath(samples: Int, maxRadius: Double = 50) -> [SIMD3<Double>] {
    guard samples >= 2 else { return [] }
    let e = eccentricity
    let p = perihelionDistance * (1 + e)
    let point = { (v: Double) -> SIMD3<Double> in
      let r = p / (1 + e * cos(v))
      return self.rotateToEcliptic(SIMD2(r * cos(v), r * sin(v)))
    }
    if e < 1 {
      return (0..<samples).map { point(2 * .pi * Double($0) / Double(samples)) }
    }
    // Open orbit: |v| < vMax, where r(vMax) = maxRadius (and r → ∞ at acos(−1/e) for a hyperbola).
    let radius = max(maxRadius, perihelionDistance * 1.0001)
    let vMax = acos(max(-1, min(1, (p / radius - 1) / e)))
    return (0..<samples).map { point(-vMax + 2 * vMax * Double($0) / Double(samples - 1)) }
  }

  // MARK: Private

  /// Rotates a vector from the orbital plane (x toward perihelion) into the J2000 ecliptic frame.
  private func rotateToEcliptic(_ v: SIMD2<Double>) -> SIMD3<Double> {
    let d = Units.degToRad
    let (cw, sw) = (cos(argumentOfPerihelion * d), sin(argumentOfPerihelion * d))
    let (cO, sO) = (cos(longitudeOfAscendingNode * d), sin(longitudeOfAscendingNode * d))
    let (cI, sI) = (cos(inclination * d), sin(inclination * d))
    return SIMD3(
      (cw * cO - sw * sO * cI) * v.x + (-sw * cO - cw * sO * cI) * v.y,
      (cw * sO + sw * cO * cI) * v.x + (-sw * sO + cw * cO * cI) * v.y,
      (sw * sI) * v.x + (cw * sI) * v.y)
  }
}

// MARK: - SBDBResponse

/// The part of the SBDB API response that `SmallBody` reads. Values are decoded leniently: SBDB sends numbers as
/// strings (sometimes with no leading zero, `".0797"`) and `null` for undefined elements.
private struct SBDBResponse: Decodable {
  struct Object: Decodable {
    var fullname: String?
    var shortname: String?
  }

  struct Element: Decodable {
    var name: String
    var value: Double?

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      name = try container.decode(String.self, forKey: .name)
      value = try? container.decode(LenientDouble.self, forKey: .value).value
    }

    private enum CodingKeys: String, CodingKey { case name, value }
  }

  struct Orbit: Decodable {
    var equinox: String?
    var epoch: Double?
    var elements: [Element]?

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      equinox = try? container.decode(String.self, forKey: .equinox)
      epoch = try? container.decode(LenientDouble.self, forKey: .epoch).value
      elements = try? container.decode([Element].self, forKey: .elements)
    }

    private enum CodingKeys: String, CodingKey { case equinox, epoch, elements }
  }

  var object: Object?
  var orbit: Orbit?
  var message: String?
}

/// A number that arrives either as a JSON number or as a string.
private struct LenientDouble: Decodable {
  let value: Double

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let number = try? container.decode(Double.self) {
      value = number
    } else {
      let string = try container.decode(String.self).trimmingCharacters(in: .whitespaces)
      guard let number = Double(string) else {
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "not a number: \(string)")
      }
      value = number
    }
  }
}
