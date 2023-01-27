//
//  File.swift
//
//
//  Created by Xiangyu Sun on 26/1/23.
//
import Foundation
import XCTest

public func XCTAssertEqual(
  _ expression1: @autoclosure () -> DateComponents,
  _ expression2: @autoclosure () -> DateComponents,
  accurency: DateComponents,
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

    XCTAssertLessThanOrEqual(diff, accurency, message(), file: file, line: line)
  }
}

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
