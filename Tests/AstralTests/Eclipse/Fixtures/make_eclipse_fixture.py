#!/usr/bin/env python3
"""Regenerates solar_local.json, lunar_eclipses.json and transits.json from NASA GSFC data.

Stdlib only (plus `node` for the solar part); run in isolated mode from anywhere:

    python3 -I make_eclipse_fixture.py fetch      # download pages -> raw/ (untrusted data; only parsed, never run)
    python3 -I make_eclipse_fixture.py generate   # raw/ -> the three JSON fixtures

Solar local circumstances
    NASA's "Solar Eclipse Calculator for Google Maps" (SEcirc.js, X. Jubier / F. Espenak / S. Dutta) is the reference
    implementation behind the NASA GSFC eclipse maps. The static NASA pages no longer publish city tables, so the
    expected values are what NASA's own SEcirc.js returns, executed offline with `node` (raw/nasa_harness.js) on the
    Besselian elements embedded in the same NASA page (SEgoogle/SEgoogle2001/SE<date>google.html). The calculator uses
    sea-level observers and ΔT as published on the page. Times are stored unrounded (NASA displays 0.1 s) together
    with the strings NASA displays.

Lunar eclipses
    The contact times and magnitudes are the values printed on NASA's per-eclipse figures
    (https://eclipse.gsfc.nasa.gov/LEplot/LEplot2001/LE<date><T>.pdf, F. Espenak; ΔT = 75 s, Danjon rule). The PDFs
    are raster images, so the numbers were transcribed by hand (see LUNAR below).

Transits
    NASA GSFC "Seven Century Catalog of Mercury Transits" and "Six Millennium Catalog of Venus Transits"
    (https://eclipse.gsfc.nasa.gov/transit/catalog/...): geocentric contact times in UT to the minute.
"""

import html
import json
import os
import re
import subprocess
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
GOOGLE = "https://eclipse.gsfc.nasa.gov/SEgoogle/SEgoogle2001/SE{id}google.html"
SECIRC = "https://eclipse.gsfc.nasa.gov/SEgoogle/SEcirc.js"
TRANSIT_CATALOGS = {
    "mercury": "https://eclipse.gsfc.nasa.gov/transit/catalog/MercuryCatalog.html",
    "venus": "https://eclipse.gsfc.nasa.gov/transit/catalog/VenusCatalog.html",
}

# (id used in the NASA URL, label) of the eclipses with a Google-maps page (8-digit elements).
SOLAR_GOOGLE = [("2023Oct14A", "2023-10-14"), ("2024Apr08T", "2024-04-08"), ("2026Aug12T", "2026-08-12"),
                ("2027Aug02T", "2027-08-02")]

# (name, latitude, longitude east) at sea level.
SITES = {
    "2023-10-14": [("Albuquerque", 35.0844, -106.6504), ("Corpus Christi", 27.8006, -97.3964),
                   ("Los Angeles", 34.0522, -118.2437), ("Mexico City", 19.4326, -99.1332)],
    "2024-04-08": [("Dallas", 32.7767, -96.7970), ("Mazatlan", 23.2494, -106.4111),
                   ("Indianapolis", 39.7684, -86.1581), ("New York", 40.7128, -74.0060),
                   ("Los Angeles", 34.0522, -118.2437)],
    "2026-08-12": [("Barcelona", 41.390205, 2.154007), ("Madrid", 40.4168, -3.7038),
                   ("Reykjavik", 64.1466, -21.9426), ("London", 51.5074, -0.1278),
                   ("Valencia", 39.4699, -0.3763)],
    "2027-08-02": [("Luxor", 25.6872, 32.6396), ("Cairo", 30.0444, 31.2357),
                   ("Tangier", 35.7595, -5.8340), ("Jeddah", 21.4858, 39.1925)],
}

# NASA GSFC lunar eclipse figures. Contacts in UT as printed (hh, mm, ss); magnitudes; ΔT = 75 s.
LUNAR = [
    {"date": "2025-03-14", "type": "total", "gamma": 0.3484, "penumbralMagnitude": 2.2595, "umbralMagnitude": 1.1784,
     "greatestTD": "06:59:56.2", "greatest": "06:58:41.7", "deltaT": 75,
     "P1": "03:57:24", "U1": "05:09:33", "U2": "06:25:59", "U3": "07:31:23", "U4": "08:47:48", "P4": "10:00:01"},
    {"date": "2025-09-07", "type": "total", "gamma": -0.2752, "penumbralMagnitude": 2.3440, "umbralMagnitude": 1.3619,
     "greatestTD": "18:12:57.9", "greatest": "18:11:43.1", "deltaT": 75,
     "P1": "15:28:21", "U1": "16:27:02", "U2": "17:30:41", "U3": "18:52:47", "U4": "19:56:26", "P4": "20:55:00"},
    {"date": "2026-03-03", "type": "total", "gamma": -0.3765, "penumbralMagnitude": 2.1838, "umbralMagnitude": 1.1507,
     "greatestTD": "11:34:52.1", "greatest": "11:33:37.0", "deltaT": 75,
     "P1": "08:44:22", "U1": "09:50:00", "U2": "11:04:26", "U3": "12:02:45", "U4": "13:17:10", "P4": "14:22:59"},
    {"date": "2026-08-28", "type": "partial", "gamma": 0.4964, "penumbralMagnitude": 1.9645, "umbralMagnitude": 0.9299,
     "greatestTD": "04:14:04.4", "greatest": "04:12:49.0", "deltaT": 75,
     "P1": "01:23:55", "U1": "02:33:48", "U4": "05:51:55", "P4": "07:01:41"},
]

# (planet, catalog date as printed) of the transits used for validation.
TRANSITS = [("mercury", "2003 May 07"), ("mercury", "2006 Nov 08"), ("mercury", "2016 May 09"),
            ("mercury", "2019 Nov 11"), ("mercury", "2032 Nov 13"), ("venus", "2004 Jun 08"),
            ("venus", "2012 Jun 06")]


def get(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read().decode("utf-8", "replace")


def fetch():
    os.makedirs(RAW, exist_ok=True)
    with open(os.path.join(RAW, "SEcirc.js"), "w", encoding="utf-8") as f:
        f.write(get(SECIRC))
    for pid, label in SOLAR_GOOGLE:
        page = get(GOOGLE.format(id=pid))
        m = re.search(r"var elements = new Array\((.*?)\);", page, re.S)
        with open(os.path.join(RAW, "elements_%s.txt" % label), "w", encoding="utf-8") as f:
            f.write("// source: " + GOOGLE.format(id=pid) + "\nvar elements = new Array(" + m.group(1) + ");\n")
    for name, url in TRANSIT_CATALOGS.items():
        page = re.sub(r"<script.*?</script>", "", get(url), flags=re.S)
        text = html.unescape(re.sub(r"<[^>]+>", "", page))
        rows = [l for l in text.split("\n") if re.match(r"\s*\d{4}\s+[A-Z][a-z]{2}\s+\d\d\s+\d\d:\d\d", l)]
        with open(os.path.join(RAW, "transit_%s_rows.txt" % name), "w", encoding="utf-8") as f:
            f.write("# source: " + url + "\n# Date I II Greatest III IV MinSep(arcsec) RA Dec GST Series\n")
            f.write("\n".join(rows) + "\n")
    print("fetched")


def parse_elements(text):
    body = re.search(r"var elements = new Array\((.*?)\);", text, re.S).group(1)
    body = re.sub(r"//[^\n]*", "", body)
    v = [float(s) for s in re.findall(r"[-+]?\d*\.\d+|[-+]?\d+", body)]
    return {"jd": v[0], "t0": v[1], "tmin": v[2], "tmax": v[3], "deltaT": v[4],
            "x": v[5:9], "y": v[9:13], "d": v[13:16], "mu": v[16:19], "l1": v[19:22], "l2": v[22:25],
            "tanF1": v[25], "tanF2": v[26]}


def run_nasa_calculator(elements_text, sites):
    harness = os.path.join(RAW, "nasa_harness.js")
    payload = json.dumps({"elements": elements_text, "sites": sites})
    out = subprocess.run(["node", harness, os.path.join(RAW, "SEcirc.js")], input=payload, capture_output=True,
                         text=True, check=True)
    return json.loads(out.stdout)


def solar():
    eclipses = []
    for pid, label in SOLAR_GOOGLE:
        with open(os.path.join(RAW, "elements_%s.txt" % label), encoding="utf-8") as f:
            text = f.read()
        el = parse_elements(text)
        sites = [{"name": n, "lat": la, "lon": lo} for n, la, lo in SITES[label]]
        results = run_nasa_calculator(text, [(s["lat"], s["lon"]) for s in sites])
        out_sites = []
        for s, r in zip(sites, results):
            rec = dict(s)
            rec.update(r)
            out_sites.append(rec)
        eclipses.append({"label": label, "source": GOOGLE.format(id=pid), "elements": el, "sites": out_sites})
    doc = {"description": "Local circumstances computed by NASA's SEcirc.js (GSFC eclipse map calculator) on the "
                          "Besselian elements of the same NASA page; sea-level observers. utSeconds = seconds "
                          "after 00:00 UT of the label date, unrounded; *Display = strings NASA shows.",
           "eclipses": eclipses}
    with open(os.path.join(HERE, "solar_local.json"), "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1)
    print("solar_local.json", sum(len(e["sites"]) for e in eclipses), "sites")


def hms(s):
    p = s.split(":")
    return int(p[0]) * 3600 + int(p[1]) * 60 + float(p[2])


def lunar():
    out = []
    for e in LUNAR:
        rec = dict(e)
        for k in ["P1", "U1", "U2", "U3", "U4", "P4", "greatest", "greatestTD"]:
            if k in rec:
                rec[k + "Seconds"] = hms(rec[k])
        out.append(rec)
    doc = {"description": "NASA GSFC lunar eclipse figures (F. Espenak), contacts in UT, seconds after 00:00 UT of "
                          "the date; ΔT = 75 s, Danjon shadow rule, VSOP87/ELP2000-85.",
           "source": "https://eclipse.gsfc.nasa.gov/LEplot/LEplot2001/LE<date><T>.pdf", "eclipses": out}
    with open(os.path.join(HERE, "lunar_eclipses.json"), "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1)
    print("lunar_eclipses.json", len(out))


def transits():
    out = []
    for planet, date in TRANSITS:
        with open(os.path.join(RAW, "transit_%s_rows.txt" % planet), encoding="utf-8") as f:
            rows = [l for l in f if not l.startswith("#")]
        row = next(l for l in rows if l.strip().startswith(date))
        parts = row.split()
        year, mon, day = int(parts[0]), MONTHS.index(parts[1]) + 1, int(parts[2])
        times = parts[3:8]
        sep = float(parts[8])
        out.append({"planet": planet, "date": "%04d-%02d-%02d" % (year, mon, day),
                    "I": times[0], "II": times[1], "greatest": times[2], "III": times[3], "IV": times[4],
                    "minimumSeparationArcsec": sep})
    doc = {"description": "NASA GSFC transit catalogs: geocentric contact times (UT, to the minute) and minimum "
                          "separation. The date is that of greatest transit; a time earlier than 'greatest' that is "
                          "later in the day than it belongs to the previous day (and vice versa).",
           "source": TRANSIT_CATALOGS, "transits": out}
    with open(os.path.join(HERE, "transits.json"), "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1)
    print("transits.json", len(out))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "fetch":
        fetch()
    elif cmd == "generate":
        solar()
        lunar()
        transits()
    else:
        raise SystemExit(__doc__)
