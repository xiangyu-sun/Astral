//
//  DateComponentsTestHelper.swift
//
//
//  Created by Xiangyu Sun on 26/1/23.
//
import Foundation
import Testing
import XCTest

// MARK: - Swift Testing Helper

/// Helper function to compare DateComponents with a tolerance for Swift Testing
/// Returns true if the difference between two DateComponents is within the specified accuracy
public func expectDateComponentsEqual(
  _ lhs: DateComponents,
  _ rhs: DateComponents,
  accuracy: DateComponents,
  sourceLocation: SourceLocation = #_sourceLocation)
  -> Bool
{
  if lhs == rhs {
    return true
  }

  let diff = Calendar.current.dateComponents(
    [.year, .month, .day, .hour, .minute, .second],
    from: lhs,
    to: rhs).absDateComponents()

  let isWithinAccuracy = diff <= accuracy

  if !isWithinAccuracy {
    Issue.record(
      "DateComponents not equal within accuracy. Difference: \(diff), Accuracy: \(accuracy)",
      sourceLocation: sourceLocation)
  }

  return isWithinAccuracy
}

// MARK: - XCTest Helper (for backwards compatibility)

/// XCTest helper for comparing DateComponents with tolerance
/// This is kept for backwards compatibility with remaining XCTest tests
public func XCTAssertEqual(
  _ expression1: @autoclosure () -> DateComponents,
  _ expression2: @autoclosure () -> DateComponents,
  accuracy: DateComponents,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line)
{
  let lhs = expression1()
  let rhs = expression2()

  if lhs == rhs {
    XCTAssertEqual(lhs, rhs, message(), file: file, line: line)
  } else {
    let diff = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: lhs, to: rhs).absDateComponents()

    XCTAssertLessThanOrEqual(diff, accuracy, message(), file: file, line: line)
  }
}

// MARK: - Shared Extension

extension DateComponents {
  func absDateComponents() -> DateComponents {
    var copy = self
    copy.year = year != nil ? abs(year!) : nil
    copy.month = month != nil ? abs(month!) : nil
    copy.day = day != nil ? abs(day!) : nil
    copy.hour = hour != nil ? abs(hour!) : nil
    copy.minute = minute != nil ? abs(minute!) : nil
    copy.second = second != nil ? abs(second!) : nil

    return copy
  }
}
