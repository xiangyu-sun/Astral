#!/usr/bin/env python3
"""Regenerates ../BesselianCatalog.swift from NASA GSFC per-eclipse Besselian element pages.

Stdlib only; run with isolated mode:

    python3 -I make_besselian_catalog.py fetch      # download pages -> raw/<id>.txt (text of the <pre> blocks)
    python3 -I make_besselian_catalog.py generate   # raw/*.txt -> ../BesselianCatalog.swift

Source pages: https://eclipse.gsfc.nasa.gov/SEbeselm/SEbeselm2001/SE<YYYY><Mon><DD><T>beselm.html
(Fred Espenak, NASA/GSFC; "Eclipse Predictions by Fred Espenak, NASA's GSFC").

Downloaded pages are untrusted data: they are only parsed with regular expressions, never executed.
This directory is excluded from the Astral target in Package.swift.
"""

import html
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "..", "BesselianCatalog.swift")
BASE = "https://eclipse.gsfc.nasa.gov/SEbeselm/SEbeselm2001/SE{id}beselm.html"

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

# (year, month, day, type letter) of every solar eclipse 2023-2035 (T total, A annular, H hybrid, P partial).
ECLIPSES = [
    (2023, 4, 20, "H"), (2023, 10, 14, "A"),
    (2024, 4, 8, "T"), (2024, 10, 2, "A"),
    (2025, 3, 29, "P"), (2025, 9, 21, "P"),
    (2026, 2, 17, "A"), (2026, 8, 12, "T"),
    (2027, 2, 6, "A"), (2027, 8, 2, "T"),
    (2028, 1, 26, "A"), (2028, 7, 22, "T"),
    (2029, 1, 14, "P"), (2029, 6, 12, "P"), (2029, 7, 11, "P"), (2029, 12, 5, "P"),
    (2030, 6, 1, "A"), (2030, 11, 25, "T"),
    (2031, 5, 21, "A"), (2031, 11, 14, "H"),
    (2032, 5, 9, "A"), (2032, 11, 3, "P"),
    (2033, 3, 30, "T"), (2033, 9, 23, "P"),
    (2034, 3, 20, "T"), (2034, 9, 12, "A"),
    (2035, 3, 9, "A"), (2035, 9, 2, "T"),
]


def page_id(y, m, d, t):
    return "%d%s%02d%s" % (y, MONTHS[m - 1], d, t)


def fetch():
    os.makedirs(RAW, exist_ok=True)
    for y, m, d, t in ECLIPSES:
        pid = page_id(y, m, d, t)
        url = BASE.format(id=pid)
        with urllib.request.urlopen(url, timeout=60) as r:
            page = r.read().decode("utf-8", "replace")
        pres = re.findall(r"<pre>(.*?)</pre>", page, re.S)
        if not pres:
            raise SystemExit("no <pre> block in " + url)
        text = html.unescape(re.sub(r"<[^>]+>", "", "\n".join(pres)))
        with open(os.path.join(RAW, pid + ".txt"), "w", encoding="utf-8") as f:
            f.write("# source: " + url + "\n" + text)
        print("fetched", pid)


NUM = r"[-+]?\d*\.\d+|[-+]?\d+"


def nums(line):
    return [float(v) for v in re.findall(NUM, line)]


def parse(pid, text):
    rec = {"id": pid}
    rec["url"] = BASE.format(id=pid)
    m = re.search(r"Polynomial Besselian Elements for:\s+(\d+) (\w+) (\d+)\s+(\d+):(\d+):([\d.]+) TDT", text)
    year, mon, day = int(m.group(1)), MONTHS.index(m.group(2)) + 1, int(m.group(3))
    rec["t0date"] = (year, mon, day)
    rec["t0"] = int(m.group(4)) + int(m.group(5)) / 60.0 + float(m.group(6)) / 3600.0
    rows = {}
    lines = text.split("\n")
    start = next(i for i, l in enumerate(lines) if "Polynomial Besselian Elements" in l)
    for l in lines[start:]:
        mm = re.match(r"\s+([0-3])\s+(.*)$", l)
        if mm:
            rows[int(mm.group(1))] = nums(mm.group(2))
    r0, r1, r2, r3 = rows[0], rows[1], rows[2], rows[3]
    assert len(r0) == 6 and len(r1) == 6 and len(r2) == 5 and len(r3) == 2, (pid, rows)
    rec["x"] = [r0[0], r1[0], r2[0], r3[0]]
    rec["y"] = [r0[1], r1[1], r2[1], r3[1]]
    rec["d"] = [r0[2], r1[2], r2[2]]
    rec["l1"] = [r0[3], r1[3], r2[3]]
    rec["l2"] = [r0[4], r1[4], r2[4]]
    rec["mu"] = [r0[5], r1[5]]
    tf = re.search(r"Tan\s*.\s*1\s*=\s*([\d.]+)\s+Tan\s*.\s*2\s*=\s*([\d.]+)", text)
    rec["tanF1"], rec["tanF2"] = float(tf.group(1)), float(tf.group(2))
    rec["deltaT"] = float(re.search(r"ΔT\s*=\s*([\d.]+)\s*s", text).group(1))
    rec["gamma"] = float(re.search(r"Gamma\s*=\s*(-?[\d.]+)", text).group(1))
    rec["magnitude"] = float(re.search(r"Eclipse Magnitude\s*=\s*(-?[\d.]+)", text).group(1))
    rec["type"] = pid[-1]
    return rec


def parse_greatest(text):
    """Published global circumstances: greatest eclipse (TDT/UT), gamma, magnitude and, when central, the
    position, altitude, path width and central duration at the instant of greatest eclipse."""
    g = {}
    m = re.search(r"Instant of\s+(\d+):(\d+):([\d.]+) TDT\s+J\.D\. = ([\d.]+)", text)
    g["greatestTDTJulianDate"] = float(m.group(4))
    m = re.search(r"Greatest Eclipse:\s+\(=(\d+):(\d+):([\d.]+) UT\)", text)
    g["greatestUTSeconds"] = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
    m = re.search(r"Greatest Eclipse:\s+Time =\s+(\d+):(\d+):([\d.]+) UT\s+Lat =\s+(\d+)°([\d.]+)'([NS])\s+"
                  r"Long =\s+(\d+)°([\d.]+)'([EW])\s+\(GE\)\s+Sun Altitude =\s+([\d.]+)°\s+Path Width =\s+([\d.]+) km\s+"
                  r"Sun Azimuth =\s+([\d.]+)°\s+Central Duration =\s+(\d+)m([\d.]+)s", text)
    if m:
        g["latitude"] = (int(m.group(4)) + float(m.group(5)) / 60) * (1 if m.group(6) == "N" else -1)
        g["longitude"] = (int(m.group(7)) + float(m.group(8)) / 60) * (1 if m.group(9) == "E" else -1)
        g["sunAltitude"] = float(m.group(10))
        g["pathWidthKm"] = float(m.group(11))
        g["sunAzimuth"] = float(m.group(12))
        g["centralDurationSeconds"] = int(m.group(13)) * 60 + float(m.group(14))
    return g


def write_global_fixture(recs):
    import json
    out = []
    for r in recs:
        entry = {"label": "%04d-%02d-%02d" % r["t0date"], "type": {"T": "total", "A": "annular", "H": "hybrid",
                                                                    "P": "partial"}[r["type"]],
                 "gamma": r["gamma"], "magnitude": r["magnitude"], "deltaT": r["deltaT"]}
        entry.update(r["greatest"])
        out.append(entry)
    path = os.path.join(HERE, "..", "..", "..", "..", "Tests", "AstralTests", "Eclipse", "Fixtures", "solar_global.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"description": "Global circumstances published on NASA GSFC's per-eclipse Besselian element pages "
                                  "(UT/TDT of greatest eclipse, gamma, magnitude, and for central eclipses the "
                                  "position, altitude, path width and central duration at greatest eclipse).",
                   "eclipses": out}, f, indent=1)
    print("wrote", os.path.normpath(path))


def sw(v):
    s = repr(float(v))
    return s


def arr(vs):
    return "[" + ", ".join(sw(v) for v in vs) + "]"


def generate():
    recs = []
    for y, m, d, t in ECLIPSES:
        pid = page_id(y, m, d, t)
        with open(os.path.join(RAW, pid + ".txt"), encoding="utf-8") as f:
            text = f.read()
        rec = parse(pid, text)
        rec["greatest"] = parse_greatest(text)
        recs.append(rec)
    kinds = {"T": ".total", "A": ".annular", "H": ".hybrid", "P": ".partial"}
    out = []
    out.append("//")
    out.append("//  BesselianCatalog.swift")
    out.append("//")
    out.append("//  GENERATED by Data/make_besselian_catalog.py, do not edit by hand.")
    out.append("//")
    out.append("//  Polynomial Besselian elements of the solar eclipses 2023-2035, transcribed from the per-eclipse pages of")
    out.append("//  \"Besselian Elements of Solar Eclipses\", NASA/GSFC (F. Espenak), VSOP87/ELP2000-85, k1 = 0.272488, k2 = 0.272281.")
    out.append("//  \"Eclipse Predictions by Fred Espenak, NASA's GSFC\", https://eclipse.gsfc.nasa.gov/SEcat5/beselm.html")
    out.append("//")
    out.append("")
    out.append("import Foundation")
    out.append("")
    out.append("extension BesselianElements {")
    out.append("")
    out.append("  /// Built-in table: the solar eclipses of 2023 to 2035, in chronological order. Immutable.")
    out.append("  ///")
    out.append("  /// Transcribed from NASA GSFC's per-eclipse Besselian element pages. The ΔT of each entry is NASA's prediction at the")
    out.append("  /// time of publication; replace it with ``withDeltaT(_:)`` once the real value is known.")
    out.append("  public static let catalog: [BesselianElements] = [")
    for r in recs:
        y, m, d = r["t0date"]
        out.append("    // %s  (%s)  gamma %.4f  magnitude %.4f" % (r["id"], r["url"], r["gamma"], r["magnitude"]))
        out.append("    BesselianElements(")
        out.append("      label: \"%04d-%02d-%02d\"," % (y, m, d))
        out.append("      publishedType: %s," % kinds[r["type"]])
        out.append("      t0Year: %d, t0Month: %d, t0Day: %d, t0Hours: %s," % (y, m, d, sw(r["t0"])))
        out.append("      deltaT: %s," % sw(r["deltaT"]))
        for k in ["x", "y", "d", "mu", "l1", "l2"]:
            out.append("      %s: %s," % (k, arr(r[k])))
        out.append("      tanF1: %s, tanF2: %s)," % (sw(r["tanF1"]), sw(r["tanF2"])))
    out.append("  ]")
    out.append("}")
    out.append("")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print("wrote", os.path.normpath(OUT), len(recs), "eclipses")
    write_global_fixture(recs)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "fetch":
        fetch()
    elif cmd == "generate":
        generate()
    else:
        raise SystemExit(__doc__)
