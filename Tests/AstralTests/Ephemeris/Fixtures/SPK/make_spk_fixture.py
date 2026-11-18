// swiftlint:disable no_direct_standard_out_logs
#!/usr/bin/env python3
"""Fetch JPL Horizons vectors for the SPK tests and write horizons_spk.json.

Usage:  python3 -I make_spk_fixture.py [--refetch]

Raw API responses are kept in raw/<case>.txt (fetched only if missing, or with --refetch); the JSON is parsed from
them verbatim. All times are TDB Julian dates inside the window of tiny.bsp (2026-07-01 .. 2026-12-31). Output is
geometric position and velocity in km and km/s.

Cases (name -> Horizons target, centre, reference plane):
  helio_ecl_*  centre Sun body centre (500@10), ecliptic and equinox of J2000 (frame ICRF)
  ssb_icrf_*   centre solar-system barycentre (500@0), ICRF equatorial axes (REF_PLANE FRAME)
  geo_ecl_*    centre Earth body centre (500@399), ecliptic J2000
Mars..Pluto are system barycentres (Horizons targets 4..9); 3 is the Earth-Moon barycentre.

Standard library only.
"""
import json
import pathlib
import sys
import urllib.parse
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
RAW = HERE / "raw"

EPOCHS = [2461230.5, 2461265.2403, 2461300.25, 2461333.123456, 2461359.0, 2461380.75, 2461400.0]

HELIO = "500@10"
SSB = "500@0"
GEO = "500@399"

CASES = {}
for name, cmd in [("mercury", "199"), ("venus", "299"), ("earth", "399"), ("moon", "301"), ("emb", "3"),
                  ("mars", "4"), ("jupiter", "5"), ("saturn", "6"), ("uranus", "7"), ("neptune", "8"),
                  ("pluto", "9")]:
    CASES["helio_ecl_" + name] = (cmd, HELIO, "ECLIPTIC")
for name, cmd in [("sun", "10"), ("earth", "399"), ("moon", "301"), ("emb", "3"), ("jupiter", "5")]:
    CASES["ssb_icrf_" + name] = (cmd, SSB, "FRAME")
CASES["geo_ecl_moon"] = ("301", GEO, "ECLIPTIC")


def fetch(command, center, plane):
    params = {
        "format": "text", "COMMAND": f"'{command}'", "OBJ_DATA": "'NO'", "MAKE_EPHEM": "'YES'",
        "EPHEM_TYPE": "'VECTORS'", "CENTER": f"'{center}'", "TLIST_TYPE": "'JD'", "TIME_TYPE": "'TDB'",
        "TLIST": "'" + " ".join(repr(t) for t in EPOCHS) + "'", "REF_PLANE": f"'{plane}'",
        "REF_SYSTEM": "'ICRF'", "OUT_UNITS": "'KM-S'", "VEC_TABLE": "'2'", "VEC_CORR": "'NONE'",
        "CSV_FORMAT": "'YES'",
    }
    url = "https://ssd.jpl.nasa.gov/api/horizons.api?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read().decode("utf-8")


def main():
    refetch = "--refetch" in sys.argv
    RAW.mkdir(exist_ok=True)
    cases = {}
    source = None
    for name, (cmd, center, plane) in CASES.items():
        path = RAW / f"{name}.txt"
        if refetch or not path.exists():
            path.write_text(fetch(cmd, center, plane))
        text = path.read_text()
        if source is None:
            source = next(l for l in text.splitlines() if l.startswith("Target body name")).split("{")[1].strip("}")
        block = text.split("$$SOE")[1].split("$$EOE")[0]
        rows = []
        for line in block.strip().splitlines():
            parts = [p.strip() for p in line.strip().rstrip(",").split(",")]
            jd, cal = float(parts[0]), parts[1]
            x, y, z, vx, vy, vz = (float(p) for p in parts[2:8])
            rows.append({"jd": jd, "date": cal, "p": [x, y, z], "v": [vx, vy, vz]})
        assert [r["jd"] for r in rows] == EPOCHS or len(rows) == len(EPOCHS), name
        cases[name] = {"target": cmd, "center": center, "plane": plane, "rows": rows}
    out = {
        "source": "NASA/JPL Horizons API " + source.replace("source: ", ""),
        "timescale": "TDB (JD)",
        "units": "km, km/s",
        "note": "ecl = ecliptic and equinox of J2000 (obliquity 84381.448 arcsec); icrf = ICRF equatorial axes",
        "cases": cases,
    }
    (HERE / "horizons_spk.json").write_text(json.dumps(out, indent=1) + "\n")
    print("wrote horizons_spk.json:", len(cases), "cases")


if __name__ == "__main__":
    main()
