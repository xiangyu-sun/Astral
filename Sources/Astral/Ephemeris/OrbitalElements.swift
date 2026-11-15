//
//  OrbitalElements.swift
//

import Foundation

/// Keplerian elements: the value at J2000 plus a rate per Julian century.
///
/// Distances are in AU and angles in degrees (converted to radians once, when evaluated).
public struct OrbitalElements: Sendable, Hashable {

  // MARK: Lifecycle

  public init(
    a: Double, aRate: Double = 0,
    e: Double, eRate: Double = 0,
    i: Double, iRate: Double = 0,
    L: Double, LRate: Double,
    peri: Double, periRate: Double = 0,
    node: Double, nodeRate: Double = 0)
  {
    self.a = a; self.aRate = aRate
    self.e = e; self.eRate = eRate
    self.i = i; self.iRate = iRate
    self.L = L; self.LRate = LRate
    self.peri = peri; self.periRate = periRate
    self.node = node; self.nodeRate = nodeRate
  }

  /// Builds from the two JPL table rows: J2000 values, then rates per century.
  init(
    _ v: (Double, Double, Double, Double, Double, Double),
    _ r: (Double, Double, Double, Double, Double, Double))
  {
    self.init(
      a: v.0, aRate: r.0, e: v.1, eRate: r.1, i: v.2, iRate: r.2,
      L: v.3, LRate: r.3, peri: v.4, periRate: r.4, node: v.5, nodeRate: r.5)
  }

  // MARK: Public

  /// Semi-major axis, AU.
  public var a, aRate: Double
  /// Eccentricity.
  public var e, eRate: Double
  /// Inclination, degrees.
  public var i, iRate: Double
  /// Mean longitude, degrees.
  public var L, LRate: Double
  /// Longitude of perihelion, degrees.
  public var peri, periRate: Double
  /// Longitude of the ascending node, degrees.
  public var node, nodeRate: Double
}
