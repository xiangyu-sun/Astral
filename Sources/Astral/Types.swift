import Foundation

public typealias Degrees = Double
public typealias Radians = Double
public typealias Minutes = Double

// MARK: - Elevetion

enum Elevetion: Equatable {
  case double(Double)
  case tuple(Double, Double)
}
