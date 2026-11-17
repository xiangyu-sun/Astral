#!/usr/bin/env python3
"""Sample NASA SVS "Moon Phase and Libration" hourly tables into svs_libration.json.

Source tables (public domain, NASA Scientific Visualization Studio, DE421 based, geocentric, hourly, UT):
  2025: https://svs.gsfc.nasa.gov/5415/  ->  .../a005415/mooninfo_2025.json
  2026: https://svs.gsfc.nasa.gov/5587/  ->  .../a005587/mooninfo_2026.json

Usage (stdlib only; run in isolated mode, with the downloaded tables outside the repository):
    python3 -I make_svs_libration_fixture.py mooninfo_2025.json mooninfo_2026.json

The output is written next to this script. Rows are taken at a fixed stride of 194 hours from each table
(8 days 2 hours, so the hour of day cycles and the whole lunation, perigee/apogee and node cycles are covered).
Numbers are copied verbatim from the tables; nothing is edited or invented.

Fields in the output (SVS naming in brackets):
  utc          row time, ISO 8601, UT
  jd           Julian date of that time (UT, no delta-T applied)
  phasePercent illuminated fraction in percent [phase]
  ageDays      lunar age [age]
  distanceKm   centre-to-centre distance [distance]
  subSolarLon/Lat   selenographic longitude/latitude of the sub-solar point [subsolar]
  libLon/libLat     selenographic longitude/latitude of the sub-Earth point = total libration [subearth]
  axisPA       position angle of the Moon's axis from celestial north [posangle]
  raHours/decDeg    J2000 right ascension (hours) / declination (degrees) [j2000]
"""
import datetime
import json
import pathlib
import sys

STRIDE_HOURS = 194
HERE = pathlib.Path(__file__).resolve().parent
URLS = {
    "2025": "https://svs.gsfc.nasa.gov/vis/a000000/a005400/a005415/mooninfo_2025.json",
    "2026": "https://svs.gsfc.nasa.gov/vis/a000000/a005500/a005587/mooninfo_2026.json",
}
EPOCH_JD = 2440587.5  # JD of 1970-01-01 00:00 UT


def parse_time(text):
    # "01 Jan 2025 00:00 UT"
    when = datetime.datetime.strptime(text.replace(" UT", ""), "%d %b %Y %H:%M")
    when = when.replace(tzinfo=datetime.timezone.utc)
    return when, EPOCH_JD + when.timestamp() / 86400.0


def main(paths):
    rows = []
    for path in paths:
        table = json.loads(pathlib.Path(path).read_text())
        for index in range(0, len(table), STRIDE_HOURS):
            row = table[index]
            when, jd = parse_time(row["time"])
            rows.append({
                "utc": when.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "jd": round(jd, 6),
                "phasePercent": row["phase"],
                "ageDays": row["age"],
                "distanceKm": row["distance"],
                "subSolarLon": row["subsolar"]["lon"],
                "subSolarLat": row["subsolar"]["lat"],
                "libLon": row["subearth"]["lon"],
                "libLat": row["subearth"]["lat"],
                "axisPA": row["posangle"],
                "raHours": row["j2000"]["ra"],
                "decDeg": row["j2000"]["dec"],
            })
    out = {
        "source": "NASA Scientific Visualization Studio, Moon Phase and Libration (JPL DE421), geocentric, UT",
        "urls": URLS,
        "strideHours": STRIDE_HOURS,
        "rows": rows,
    }
    (HERE / "svs_libration.json").write_text(json.dumps(out, indent=1) + "\n")
    print(f"wrote {len(rows)} rows")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
