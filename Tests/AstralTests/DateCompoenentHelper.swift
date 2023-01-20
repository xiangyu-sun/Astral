//
//  File.swift
//  
//
//  Created by Xiangyu Sun on 20/1/23.
//

import Foundation

extension DateComponents {
  static func date(_ year: Int, _ month: Int, _ day: Int, _ timeZone: TimeZone = .gmt) -> DateComponents {
    .init(timeZone:timeZone, year: year, month: month, day: day)
  }
  
  static func datetime(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0, _ timeZone: TimeZone = .gmt) -> DateComponents  {
    .init(timeZone:timeZone, year: year, month: month, day: day, hour: hour, minute: minute, second: second)
  }
}
