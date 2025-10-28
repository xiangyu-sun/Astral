import Foundation

/// The depression angle in degrees for the dawn/dusk calculation
public enum Depression: ExpressibleByIntegerLiteral, RawRepresentable {

  case civil
  case nautical
  case astronomical // Corrected spelling
  case other(Int)

  // MARK: Lifecycle

  public init(rawValue value: Int) {
    if value == 6 {
      self = .civil
    } else if value == 12 {
      self = .nautical
    } else if value == 18 {
      self = .astronomical
    } else {
      self = .other(value)
    }
  }

  public init(integerLiteral value: Int) {
    self.init(rawValue: value)
  }

  // MARK: Internal

  public typealias RawValue = Int
  public typealias IntegerLiteralType = Int

  public var rawValue: Int {
    switch self {
    case .civil:
      return 6
    case .nautical:
      return 12
    case .astronomical:
      return 18
    case .other(let int):
      return int
    }
  }
}
