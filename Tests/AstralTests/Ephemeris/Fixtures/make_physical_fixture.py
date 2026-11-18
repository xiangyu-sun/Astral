// swiftlint:disable no_direct_standard_out_logs
#!/usr/bin/env python3
"""Fetch JPL Horizons OBSERVER-table quantities and write physical.json (committed; tests run offline).

Run with:  python3 -I make_physical_fixture.py      (standard library only, needs network)

Observer: geocentre ('500@399'). Times: TT, given as Julian dates (TLIST). Quantities requested:
  9  APmag, S-brt         apparent visual magnitude and surface brightness
  10 Illu%                illuminated fraction of the (circular) disk, percent
  13 Ang-diam             equatorial angular diameter, arcseconds
  14 ObsSub-LON, -LAT     sub-observer longitude / latitude (planetographic), degrees
  15 SunSub-LON, -LAT     sub-solar longitude / latitude (planetographic), degrees
  20 delta, deldot        apparent (light-time corrected) range, AU
  23 S-O-T                Sun-Observer-Target solar elongation, degrees
  24 S-T-O                Sun-Target-Observer angle (phase angle), degrees
Nothing is edited: numbers are copied from the responses; "n.a." becomes null.
"""
import json
import pathlib
import urllib.parse
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
API = "https://ssd.jpl.nasa.gov/api/horizons.api"

BODIES = {
    "sun": "10", "mercury": "199", "venus": "299", "moon": "301", "mars": "499",
    "jupiter": "599", "saturn": "699", "uranus": "799", "neptune": "899", "pluto": "999",
}
# 12:00 TT on these dates (JD ending in .0), spread over 1900-2050 so that every planet is seen at
# a range of phase angles and distances.
EPOCHS = [
    2415021.0,  # 1900-01-01
    2424011.0,
    2433283.0,  # 1950-01-01
    2442457.0,
    2448564.0,
    2451545.0,  # 2000-01-01
    2453556.0,
    2455998.0,
    2458327.0,
    2459922.0,
    2461359.0,  # 2026-11-14
    2464968.0,
    2467530.0,
    2469807.0,
]


def fetch(command):
    params = {
        "format": "json", "COMMAND": f"'{command}'", "OBJ_DATA": "'NO'", "MAKE_EPHEM": "'YES'",
        "EPHEM_TYPE": "'OBSERVER'", "CENTER": "'500@399'", "TLIST_TYPE": "'JD'", "TIME_TYPE": "'TT'",
        "TLIST": "'" + "\n".join(f"{jd:.1f}" for jd in EPOCHS) + "'",
        "QUANTITIES": "'9,10,13,14,15,20,23,24'", "CSV_FORMAT": "'YES'", "ANG_FORMAT": "'DEG'",
    }
    url = API + "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)["result"]


def number(text):
    text = text.strip()
    if text in ("", "n.a."):
        return None
    return float(text)


def parse(result):
    lines = result.splitlines()
    soe = lines.index("$$SOE")
    eoe = lines.index("$$EOE")
    header = [c.strip() for c in lines[soe - 2].split(",")]
    model_notes = [l.strip() for l in lines if l.startswith(("Target radii", "Target pole"))]
    rows = []
    for line in lines[soe + 1:eoe]:
        cells = [c.strip() for c in line.split(",")]
        rows.append(dict(zip(header, cells)))
    return rows, model_notes


def main():
    out = {
        "source": "NASA/JPL Horizons API, OBSERVER table, geocentric (500@399)",
        "timescale": "TT, requested as JD; the model treats its Julian date as TT",
        "note": "Horizons values are apparent (light-time corrected); phaseDeg is S-T-O",
        "bodies": {},
    }
    for name, command in BODIES.items():
        rows, notes = parse(fetch(command))
        entries = []
        for jd, row in zip(EPOCHS, rows):
            entries.append({
                "jd": jd,
                "apmag": number(row.get("APmag", "n.a.")),
                "illuPercent": number(row["Illu%"]),
                "angDiamArcsec": number(row["Ang-diam"]),
                "rangeAU": number(row["delta"]),
                "elongationDeg": number(row["S-O-T"]),
                "phaseDeg": number(row["S-T-O"]),
                "obsSubLonDeg": number(row.get("ObsSub-LON", "n.a.")),
                "obsSubLatDeg": number(row.get("ObsSub-LAT", "n.a.")),
                "sunSubLonDeg": number(row.get("SunSub-LON", "n.a.")),
                "sunSubLatDeg": number(row.get("SunSub-LAT", "n.a.")),
            })
        out["bodies"][name] = entries
        print(name, len(entries), notes)
    (HERE / "physical.json").write_text(json.dumps(out, indent=1) + "\n")


if __name__ == "__main__":
    main()
