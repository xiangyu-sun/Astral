import Foundation

/// The depression angle in degrees for the dawn/dusk calculation
enum Depression: ExpressibleByIntegerLiteral, RawRepresentable {

  case civil
  case nautical
  case astromomic

  case other(Int)

  // MARK: Lifecycle

  init(rawValue value: Int) {
    if value == 8 {
      self = .civil
    } else if value == 12 {
      self = .nautical
    } else if value == 16 {
      self = .astromomic
    } else {
      self = .other(value)
    }
  }

  init(integerLiteral value: Int) {
    self.init(rawValue: value)
  }

  // MARK: Internal

  typealias RawValue = Int

  typealias IntegerLiteralType = Int

  var rawValue: Int {
    switch self {
    case .civil:
      return 8
    case .nautical:
      return 12
    case .astromomic:
      return 16
    case .other(let int):
      return int
    }
  }
}
