//
//  File.swift
//
//  Created by Xiangyu Sun on 19/1/23.
//

import Foundation
import Numerics

// MARK: - Lunar Argument Constants
let Gm = 2  // Moon mean anomoly
let Fm = 3  // Moon argument of latitude
let D  = 4  // Moon mean elongation from sun
let Om = 5  // Longitude of the lunar ascending node
let Ls = 7  // Sun mean longitude
let Gs = 8  // Sun mean anomoly
let L2 = 12 // Venus mean longitude

// MARK: - Table4Row Structure
struct Table4Row {
  init(_ coefficient: Double, _ t: Bool, _ sincos: @escaping (Double) -> Double, _ argument_multiplers: [Int: Int]) {
    self.coefficient = coefficient
    self.t = t
    self.sincos = sincos
    self.argument_multiplers = argument_multiplers
  }

  let coefficient: Double
  let t: Bool
  let sincos: (Double) -> Double
  let argument_multiplers: [Int: Int]
}

// MARK: - Lunar Series Tables

let table4_v: [Table4Row] = [
  Table4Row(0.39558, false, sin, [Gm: 0, Fm: 1, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.08200, false, sin, [Gm: 0, Fm: 1, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.03257, false, sin, [Gm: 1, Fm: -1, D: 0, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.01092, false, sin, [Gm: 1, Fm: 1, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00666, false, sin, [Gm: 1, Fm: -1, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00644, false, sin, [Gm: 1, Fm: 1, D: -2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00331, false, sin, [Gm: 0, Fm: 1, D: -2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00304, false, sin, [Gm: 0, Fm: 1, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00240, false, sin, [Gm: 1, Fm: -1, D: -2, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00226, false, sin, [Gm: 1, Fm: 1, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00108, false, sin, [Gm: 1, Fm: 1, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00079, false, sin, [Gm: 0, Fm: 1, D: 0, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00078, false, sin, [Gm: 0, Fm: 1, D: 2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00066, false, sin, [Gm: 0, Fm: 1, D: 0, Om: 1, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00062, false, sin, [Gm: 0, Fm: 1, D: 0, Om: 1, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00050, false, sin, [Gm: 1, Fm: -1, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00045, false, sin, [Gm: 2, Fm: 1, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00031, false, sin, [Gm: 2, Fm: 1, D: -2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00027, false, sin, [Gm: 1, Fm: 1, D: -2, Om: 1, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00024, false, sin, [Gm: 0, Fm: 1, D: -2, Om: 1, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00021, true, sin, [Gm: 0, Fm: 1, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00018, false, sin, [Gm: 0, Fm: 1, D: -1, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00016, false, sin, [Gm: 0, Fm: 1, D: 2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00016, false, sin, [Gm: 1, Fm: -1, D: 0, Om: -1, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00016, false, sin, [Gm: 2, Fm: -1, D: 0, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00015, false, sin, [Gm: 0, Fm: 1, D: -2, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00012, false, sin, [Gm: 1, Fm: -1, D: -2, Om: -1, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00011, false, sin, [Gm: 1, Fm: -1, D: 0, Om: -1, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00009, false, sin, [Gm: 1, Fm: 1, D: 0, Om: 1, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(0.00009, false, sin, [Gm: 2, Fm: 1, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00008, false, sin, [Gm: 2, Fm: -1, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00008, false, sin, [Gm: 1, Fm: 1, D: 2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00008, false, sin, [Gm: 0, Fm: 3, D: -2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00007, false, sin, [Gm: 1, Fm: -1, D: 2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00007, false, sin, [Gm: 2, Fm: -1, D: -2, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00007, false, sin, [Gm: 1, Fm: 1, D: 0, Om: 1, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00006, false, sin, [Gm: 0, Fm: 1, D: 1, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00006, false, sin, [Gm: 0, Fm: 1, D: -2, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(0.00006, false, sin, [Gm: 1, Fm: -1, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00006, false, sin, [Gm: 0, Fm: 1, D: 2, Om: 1, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00005, false, sin, [Gm: 1, Fm: 1, D: -2, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00004, false, sin, [Gm: 2, Fm: 1, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00004, false, sin, [Gm: 1, Fm: -3, D: 0, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00004, false, sin, [Gm: 1, Fm: -1, D: 0, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00003, false, sin, [Gm: 1, Fm: -1, D: 0, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00003, false, sin, [Gm: 0, Fm: 1, D: -1, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00003, false, sin, [Gm: 0, Fm: 1, D: -2, Om: 1, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00003, false, sin, [Gm: 0, Fm: 1, D: -2, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00003, false, sin, [Gm: 1, Fm: 1, D: -2, Om: 1, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(0.00003, false, sin, [Gm: 0, Fm: 1, D: 0, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00003, false, sin, [Gm: 0, Fm: 1, D: -1, Om: 1, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 1, Fm: -1, D: -2, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 0, Fm: 1, D: 0, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00002, false, sin, [Gm: 1, Fm: 1, D: -1, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 1, Fm: 1, D: 0, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00002, false, sin, [Gm: 3, Fm: 1, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 2, Fm: -1, D: -4, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00002, false, sin, [Gm: 1, Fm: -1, D: -2, Om: -1, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00002, true, sin, [Gm: 1, Fm: -1, D: 0, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 1, Fm: -1, D: -4, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 1, Fm: 1, D: -4, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 2, Fm: -1, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00002, false, sin, [Gm: 1, Fm: 1, D: 2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00002, false, sin, [Gm: 1, Fm: 1, D: 0, Om: 0, Ls: 0, Gs: -1, L2: 0]),
]

let table4_u: [Table4Row] = [
  Table4Row(1, false, cos, [Gm: 0, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.10828, false, cos, [Gm: 1, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.01880, false, cos, [Gm: 1, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.01479, false, cos, [Gm: 0, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00181, false, cos, [Gm: 2, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00147, false, cos, [Gm: 2, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00105, false, cos, [Gm: 0, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00075, false, cos, [Gm: 1, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00067, false, cos, [Gm: 1, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(0.00057, false, cos, [Gm: 0, Fm: 0, D: 1, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00055, false, cos, [Gm: 1, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00046, false, cos, [Gm: 1, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00041, false, cos, [Gm: 1, Fm: -2, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00024, false, cos, [Gm: 0, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00017, false, cos, [Gm: 0, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00013, false, cos, [Gm: 1, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00010, false, cos, [Gm: 1, Fm: 0, D: -4, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00009, false, cos, [Gm: 0, Fm: 0, D: 1, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00007, false, cos, [Gm: 2, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00006, false, cos, [Gm: 3, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00006, false, cos, [Gm: 0, Fm: 2, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00005, false, cos, [Gm: 0, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: -2, L2: 0]),
  Table4Row(-0.00005, false, cos, [Gm: 2, Fm: 0, D: -4, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00005, false, cos, [Gm: 1, Fm: 2, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00005, false, cos, [Gm: 1, Fm: 0, D: -1, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00004, false, cos, [Gm: 1, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00004, false, cos, [Gm: 3, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00003, false, cos, [Gm: 1, Fm: 0, D: -4, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00003, false, cos, [Gm: 2, Fm: -2, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00003, false, cos, [Gm: 0, Fm: 2, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
]

let table4_w: [Table4Row] = [
  Table4Row(0.10478, false, sin, [Gm: 1, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.04105, false, sin, [Gm: 0, Fm: 2, D: 0, Om: 2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.02130, false, sin, [Gm: 1, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.01779, false, sin, [Gm: 0, Fm: 2, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.01774, false, sin, [Gm: 0, Fm: 0, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00987, false, sin, [Gm: 0, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00338, false, sin, [Gm: 1, Fm: -2, D: 0, Om: -2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00309, false, sin, [Gm: 0, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00190, false, sin, [Gm: 0, Fm: 2, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00144, false, sin, [Gm: 1, Fm: 0, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00144, false, sin, [Gm: 1, Fm: -2, D: 0, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00113, false, sin, [Gm: 1, Fm: 2, D: 0, Om: 2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00094, false, sin, [Gm: 1, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00092, false, sin, [Gm: 2, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00071, false, sin, [Gm: 0, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(0.00070, false, sin, [Gm: 2, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00067, false, sin, [Gm: 1, Fm: 2, D: -2, Om: 2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00066, false, sin, [Gm: 0, Fm: 2, D: -2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00066, false, sin, [Gm: 0, Fm: 0, D: 2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00061, false, sin, [Gm: 1, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00058, false, sin, [Gm: 0, Fm: 0, D: 1, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00049, false, sin, [Gm: 1, Fm: 2, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00049, false, sin, [Gm: 1, Fm: 0, D: 0, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00042, false, sin, [Gm: 1, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00034, false, sin, [Gm: 0, Fm: 2, D: -2, Om: 2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00026, false, sin, [Gm: 0, Fm: 2, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00025, false, sin, [Gm: 1, Fm: -2, D: -2, Om: -2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00024, false, sin, [Gm: 1, Fm: -2, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00023, false, sin, [Gm: 1, Fm: 2, D: -2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00023, false, sin, [Gm: 1, Fm: 0, D: -2, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00019, false, sin, [Gm: 1, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00012, false, sin, [Gm: 1, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(0.00011, false, sin, [Gm: 1, Fm: 0, D: -2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00011, false, sin, [Gm: 1, Fm: -2, D: -2, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00010, false, sin, [Gm: 0, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00009, false, sin, [Gm: 1, Fm: 0, D: -1, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00008, false, sin, [Gm: 0, Fm: 0, D: 1, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00008, false, sin, [Gm: 0, Fm: 2, D: 2, Om: 2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00008, false, sin, [Gm: 0, Fm: 0, D: 0, Om: 2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00007, false, sin, [Gm: 0, Fm: 2, D: 0, Om: 2, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(0.00006, false, sin, [Gm: 0, Fm: 2, D: 0, Om: 2, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00005, false, sin, [Gm: 1, Fm: 2, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00005, false, sin, [Gm: 3, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00005, false, sin, [Gm: 1, Fm: 0, D: 0, Om: 0, Ls: 16, Gs: 0, L2: -18]),
  Table4Row(-0.00005, false, sin, [Gm: 2, Fm: 2, D: 0, Om: 2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00004, true, sin, [Gm: 0, Fm: 2, D: 0, Om: 2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00004, false, cos, [Gm: 1, Fm: 0, D: 0, Om: 0, Ls: 16, Gs: 0, L2: -18]),
  Table4Row(-0.00004, false, sin, [Gm: 1, Fm: -2, D: 2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00004, false, sin, [Gm: 1, Fm: 0, D: -4, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00004, false, sin, [Gm: 3, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00004, false, sin, [Gm: 0, Fm: 2, D: 2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00004, false, sin, [Gm: 0, Fm: 0, D: 2, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00003, false, sin, [Gm: 0, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: 2, L2: 0]),
  Table4Row(-0.00003, false, sin, [Gm: 1, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 2, L2: 0]),
  Table4Row(0.00003, false, sin, [Gm: 0, Fm: 2, D: -2, Om: 1, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00003, false, sin, [Gm: 0, Fm: 0, D: 2, Om: 1, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(0.00003, false, sin, [Gm: 2, Fm: 2, D: -2, Om: 2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00003, false, sin, [Gm: 0, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: -2, L2: 0]),
  Table4Row(-0.00003, false, sin, [Gm: 2, Fm: 0, D: -2, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00003, false, sin, [Gm: 1, Fm: 2, D: -2, Om: 2, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00003, false, sin, [Gm: 2, Fm: 0, D: -4, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00002, false, sin, [Gm: 0, Fm: 2, D: -2, Om: 2, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 2, Fm: 2, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 2, Fm: 0, D: 0, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00002, true, cos, [Gm: 1, Fm: 0, D: 0, Om: 0, Ls: 16, Gs: 0, L2: -18]),
  Table4Row(0.00002, false, sin, [Gm: 0, Fm: 0, D: 4, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 0, Fm: 2, D: -1, Om: 2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 1, Fm: 2, D: -2, Om: 0, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 2, Fm: 0, D: 0, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 2, Fm: -2, D: 0, Om: -1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(0.00002, false, sin, [Gm: 1, Fm: 0, D: 2, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(0.00002, false, sin, [Gm: 2, Fm: 0, D: 0, Om: 0, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 1, Fm: 0, D: -4, Om: 0, Ls: 0, Gs: 1, L2: 0]),
  Table4Row(0.00002, true, sin, [Gm: 1, Fm: 0, D: 0, Om: 0, Ls: 16, Gs: 0, L2: -18]),
  Table4Row(-0.00002, false, sin, [Gm: 1, Fm: -2, D: 0, Om: -2, Ls: 0, Gs: -1, L2: 0]),
  Table4Row(0.00002, false, sin, [Gm: 2, Fm: -2, D: 0, Om: -2, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 1, Fm: 0, D: 2, Om: 1, Ls: 0, Gs: 0, L2: 0]),
  Table4Row(-0.00002, false, sin, [Gm: 1, Fm: -2, D: 2, Om: -1, Ls: 0, Gs: 0, L2: 0]),
]
