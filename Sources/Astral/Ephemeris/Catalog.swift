//
//  Catalog.swift
//

import Foundation

/// Reference data for the bodies of the solar system.
///
/// The orbital element constants are published values (JPL "Approximate Positions of the Planets", Table 1,
/// and Meeus chapter 47 for the Moon). Never adjust them to make a test pass: compare against JPL Horizons and
/// report the discrepancy instead. Physical data (radius, axial tilt, rotation) is display-only and unverified.
public enum Catalog {

  // MARK: Public

  /// Sun, Mercury–Neptune and the Moon. Pluto is excluded (unverified elements).
  public static let all: [Body] = [
    sun,
    mercury,
    venus,
    earth,
    moon,
    mars,
    jupiter,
    saturn,
    uranus,
    neptune,
  ]

  /// `all` plus Pluto, whose elements are unverified.
  public static let allWithPluto: [Body] = all + [pluto]

  /// Ceres, Eris, Haumea and Makemake. Not part of ``all`` or ``allWithPluto``: add them explicitly.
  ///
  /// Their orbits are JPL Small-Body Database osculating elements (``Body/smallBody``), copied verbatim from the
  /// SBDB API responses in `Tests/AstralTests/Ephemeris/Fixtures/SmallBody/raw/` (epoch 2026-06-09.0 TDB,
  /// JD 2461200.5) and propagated as a two-body orbit about the Sun. Against JPL Horizons this is within
  /// about 1e-3 AU a year from the epoch and degrades slowly beyond: fine for display, not for astrometry.
  /// Physical data is display-only and unverified; axial tilt is unknown for Eris, Haumea and Makemake (0 here).
  public static let dwarfPlanets: [Body] = [ceres, eris, haumea, makemake]

  public static let sun = Body(
    id: .sun,
    parent: nil,
    elements: nil,
    radiusKm: 695_700,
    axialTiltDeg: 7.25,
    rotationPeriodHours: 609.12
  )

  public static let mercury = Body(
    id: .mercury,
    parent: .sun,
    elements: OrbitalElements(
      (0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593),
      (0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081)
    ),
    radiusKm: 2_439.7,
    axialTiltDeg: 0.03,
    rotationPeriodHours: 1_407.6
  )

  public static let venus = Body(
    id: .venus,
    parent: .sun,
    elements: OrbitalElements(
      (0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255),
      (0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418)
    ),
    radiusKm: 6_051.8,
    axialTiltDeg: 177.36,
    rotationPeriodHours: -5_832.5
  )

  /// Elements are the Earth–Moon barycentre row; `SolarSystem` applies the
  /// barycentre correction when the Moon is present.
  public static let earth = Body(
    id: .earth,
    parent: .sun,
    elements: OrbitalElements(
      (1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0),
      (0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0)
    ),
    radiusKm: 6_371.0,
    axialTiltDeg: 23.44,
    rotationPeriodHours: 23.9345
  )

  public static let mars = Body(
    id: .mars,
    parent: .sun,
    elements: OrbitalElements(
      (1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891),
      (0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343)
    ),
    radiusKm: 3_389.5,
    axialTiltDeg: 25.19,
    rotationPeriodHours: 24.6229
  )

  public static let jupiter = Body(
    id: .jupiter,
    parent: .sun,
    elements: OrbitalElements(
      (5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909),
      (-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106)
    ),
    radiusKm: 69_911,
    axialTiltDeg: 3.13,
    rotationPeriodHours: 9.925
  )

  public static let saturn = Body(
    id: .saturn,
    parent: .sun,
    elements: OrbitalElements(
      (9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448),
      (-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794)
    ),
    radiusKm: 58_232,
    axialTiltDeg: 26.73,
    rotationPeriodHours: 10.656
  )

  public static let uranus = Body(
    id: .uranus,
    parent: .sun,
    elements: OrbitalElements(
      (19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503),
      (-0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589)
    ),
    radiusKm: 25_362,
    axialTiltDeg: 97.77,
    rotationPeriodHours: -17.24
  )

  public static let neptune = Body(
    id: .neptune,
    parent: .sun,
    elements: OrbitalElements(
      (30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574),
      (0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664)
    ),
    radiusKm: 24_622,
    axialTiltDeg: 28.32,
    rotationPeriodHours: 16.11
  )

  /// UNVERIFIED: elements recalled from the older Standish table and not checked against a source. Not in `all`.
  public static let pluto = Body(
    id: .pluto,
    parent: .sun,
    elements: OrbitalElements(
      (39.48211675, 0.24882730, 17.14001206, 238.92903833, 224.06891629, 110.30393684),
      (-0.00031596, 0.00005170, 0.00004818, 145.20780515, -0.04062942, -0.01183482)
    ),
    radiusKm: 1_188.3,
    axialTiltDeg: 122.53,
    rotationPeriodHours: -153.29
  )

  /// 1 Ceres (A801 AA). Mean radius and rotation from Dawn; obliquity about 4 degrees.
  public static let ceres = Body(
    id: .ceres,
    parent: .sun,
    elements: nil,
    radiusKm: 469.7,
    axialTiltDeg: 4,
    rotationPeriodHours: 9.074170,
    smallBody: sbdb(
      name: "1 Ceres (A801 AA)",
      e: 0.07969229514816586,
      q: 2.545159361382861,
      tp: 2_461_599.841466614066,
      i: 10.58802780183462,
      om: 80.24862682043221,
      w: 73.29421453021587
    )
  )

  /// 136199 Eris (2003 UB313). Radius from the 2010 stellar occultation; rotation synchronous with Dysnomia.
  public static let eris = Body(
    id: .eris,
    parent: .sun,
    elements: nil,
    radiusKm: 1_163,
    axialTiltDeg: 0,
    rotationPeriodHours: 378.87,
    smallBody: sbdb(
      name: "136199 Eris (2003 UB313)",
      e: 0.4382385347971672,
      q: 38.16267353549761,
      tp: 2_545_407.716847013144,
      i: 43.9258279471791,
      om: 36.00477044417249,
      w: 150.7949235840312
    )
  )

  /// 136108 Haumea (2003 EL61). A triaxial ellipsoid (about 1161 x 852 x 513 km); `radiusKm` is the
  /// volume-equivalent radius.
  public static let haumea = Body(
    id: .haumea,
    parent: .sun,
    elements: nil,
    radiusKm: 798,
    axialTiltDeg: 0,
    rotationPeriodHours: 3.915341,
    smallBody: sbdb(
      name: "136108 Haumea (2003 EL61)",
      e: 0.1944430148898797,
      q: 34.68751758088936,
      tp: 2_500_416.599615282750,
      i: 28.20847393040364,
      om: 121.7860561329425,
      w: 240.6905472508661
    )
  )

  /// 136472 Makemake (2005 FY9).
  public static let makemake = Body(
    id: .makemake,
    parent: .sun,
    elements: nil,
    radiusKm: 715,
    axialTiltDeg: 0,
    rotationPeriodHours: 22.8266,
    smallBody: sbdb(
      name: "136472 Makemake (2005 FY9)",
      e: 0.1588889953992523,
      q: 38.33021338173601,
      tp: 2_408_158.694098616288,
      i: 29.02785603743067,
      om: 79.2948338209406,
      w: 297.0922733397207
    )
  )

  public static let moon = Body(
    id: .moon,
    parent: .earth,
    elements: OrbitalElements(
      a: 0.00256955,
      e: 0.0549,
      i: 5.145,
      L: 218.3164477,
      LRate: 481_267.88123421,
      peri: 83.3532465,
      periRate: 4_069.0137287,
      node: 125.0445479,
      nodeRate: -1_934.1362891
    ),
    radiusKm: 1_737.4,
    axialTiltDeg: 0,
    rotationPeriodHours: 655.72
  )

  // MARK: Private

  /// The common SBDB epoch of the dwarf-planet rows, JD TDB.
  private static let dwarfPlanetEpoch = JulianDate(days: 2_461_200.5)

  /// A small body from verbatim SBDB `q`/`tp` elements. The values are constants checked by the tests, so the
  /// initializer cannot throw here.
  private static func sbdb(
    name: String,
    e: Double,
    q: Double,
    tp: Double,
    i: Double,
    om: Double,
    w: Double
  ) -> SmallBody {
    // swiftlint:disable:next force_try
    try! SmallBody(
      name: name,
      epoch: dwarfPlanetEpoch,
      eccentricity: e,
      perihelionDistance: q,
      inclination: i,
      longitudeOfAscendingNode: om,
      argumentOfPerihelion: w,
      timeOfPerihelion: JulianDate(days: tp)
    )
  }
}
