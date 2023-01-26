//
//  File.swift
//  
//
//  Created by Xiangyu Sun on 26/1/23.
//
import Foundation
import XCTest


public func XCTAssertEqual(_ expression1: @autoclosure () -> DateComponents, _ expression2: @autoclosure () -> DateComponents, accurency: DateComponents, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {

  let lhs = expression1()
  let rhs = expression2()
  
  if lhs == rhs {
    XCTAssertEqual(lhs, rhs)
  } else {
    let diff = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: lhs, to: rhs).absDateComponents()
    
    XCTAssertLessThanOrEqual(diff, accurency)
  }
}


extension DateComponents {
  func absDateComponents() -> DateComponents {
    var copy = self
    copy.year = self.year != nil ? abs(self.year!) : nil
    copy.month =  self.month != nil ? abs(self.month!) : nil
    copy.day =  self.day != nil ? abs(self.day!) : nil
    copy.hour =  self.hour != nil ? abs(self.hour!) : nil
    copy.minute =  self.minute != nil ? abs(self.minute!) : nil
    copy.second =  self.second != nil ? abs(self.second!) : nil
    
    return copy
  }
}


extension DateComponents: Comparable {
  public static func < (lhs: DateComponents, rhs: DateComponents) -> Bool {
    lhs.year < rhs.year ||
    lhs.month < rhs.month ||
    lhs.day < rhs.day ||
    lhs.hour < rhs.hour ||
    lhs.minute < rhs.minute ||
    lhs.second < rhs.second
  }
}


extension Optional where Wrapped == Int {
  static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs ?? 0) < (rhs ?? 0)
  }
}
