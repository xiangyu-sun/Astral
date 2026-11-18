// swiftlint:disable no_direct_standard_out_logs
#!/usr/bin/env python3
"""Builds smallbodies.json: JPL SBDB osculating elements + JPL Horizons heliocentric state vectors.

Standard library only; run it isolated:

    python3 -I make_smallbody_fixture.py            # fetch (network) and rebuild
    python3 -I make_smallbody_fixture.py --offline  # rebuild smallbodies.json from raw/ only

Sources
  * SBDB API  https://ssd-api.jpl.nasa.gov/sbdb.api?sstr=<id>&full-prec=1   -> raw/<key>.sbdb.json (verbatim)
  * Horizons  https://ssd.jpl.nasa.gov/api/horizons.api  EPHEM_TYPE=VECTORS, CENTER='500@10' (Sun body centre),
    REF_PLANE=ECLIPTIC (ecliptic and equinox of J2000), OUT_UNITS=AU-D, TLIST in JD TDB  -> raw/<key>.horizons.txt

Horizons integrates the full N-body problem (planetary perturbations, and the non-gravitational terms of the
JPL orbit solution for comets); the fixture is therefore the reference against which a pure two-body propagation
of the SBDB elements is compared. Nothing is edited or invented: numbers are copied verbatim.

Each target's Horizons solution is checked against the SBDB one (same element epoch and eccentricity, or, when the
cached Horizons epoch differs, the same solution date), so both sources describe the same orbit.
"""
import json
import pathlib
import re
import sys
import urllib.parse
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
RAW = HERE / "raw"
SBDB = "https://ssd-api.jpl.nasa.gov/sbdb.api"
HORIZONS = "https://ssd.jpl.nasa.gov/api/horizons.api"

# Offsets (days) from the SBDB element epoch at which Horizons states are sampled.
OFFSETS = [-365, -60, -10, 0, 10, 60, 365]

# key, SBDB search string, Horizons COMMAND (CAP: the apparition closest to the epoch, for comets)
TARGETS = [
    ("ceres", "1", "DES=2000001;"),
    ("vesta", "4", "DES=2000004;"),
    ("eros", "433", "DES=2000433;"),
    ("apophis", "99942", "DES=2099942;"),
    ("halley", "1P", "DES=1P;CAP"),
    ("encke", "2P", "DES=2P;CAP"),
    ("neowise", "C/2020 F3", "DES=1003667;"),
    ("oumuamua", "1I", "DES=2017 U1;"),
]

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def get(url):
    with urllib.request.urlopen(url, timeout=90) as response:
        return response.read().decode("utf-8")


def fetch(key, sstr, command):
    sbdb_text = get(SBDB + "?" + urllib.parse.urlencode({"sstr": sstr, "full-prec": "1"}))
    sbdb = json.loads(sbdb_text)
    epoch = float(sbdb["orbit"]["epoch"])
    jds = " ".join(repr(epoch + d) for d in OFFSETS)
    params = {
        "format": "text", "COMMAND": "'%s'" % command, "EPHEM_TYPE": "VECTORS", "CENTER": "'500@10'",
        "REF_PLANE": "ECLIPTIC", "OUT_UNITS": "AU-D", "VEC_TABLE": "2", "CSV_FORMAT": "YES",
        "TLIST": "'%s'" % jds, "TLIST_TYPE": "JD", "TIME_TYPE": "TDB",
    }
    horizons_text = get(HORIZONS + "?" + urllib.parse.urlencode(params))
    (RAW / (key + ".sbdb.json")).write_text(json.dumps(sbdb, indent=1, sort_keys=True) + "\n")
    (RAW / (key + ".horizons.txt")).write_text(horizons_text)


def number(pattern, text):
    m = re.search(pattern + r"\s*=?\s*([-+0-9.Ee]+)", text)
    return float(m.group(1)) if m else None


def horizons_solution_date(text):
    """'2021-Apr-13_11:04:44' -> '2021-04-13 11:04:44'."""
    m = re.search(r"Soln\.date:\s*(\d{4})-([A-Za-z]{3})-(\d{2})_(\S+)", text)
    if not m:
        return None
    return "%s-%02d-%s %s" % (m.group(1), MONTHS.index(m.group(2)) + 1, m.group(3), m.group(4))


def check_same_solution(key, sbdb, text):
    """Fails loudly unless Horizons and SBDB describe the same orbit solution."""
    epoch = float(sbdb["orbit"]["epoch"])
    h_epoch = number(r"EPOCH", text)
    elements = {e["name"]: e["value"] for e in sbdb["orbit"]["elements"]}
    if h_epoch is not None and abs(h_epoch - epoch) < 1e-6:
        h_e = number(r"EC", text)
        assert abs(h_e - float(elements["e"])) < 1e-9, (key, "eccentricity differs", h_e, elements["e"])
    else:
        assert horizons_solution_date(text) == sbdb["orbit"]["soln_date"], (
            key, "solution date differs", horizons_solution_date(text), sbdb["orbit"]["soln_date"])


def parse_rows(text):
    block = text.split("$$SOE")[1].split("$$EOE")[0]
    rows = []
    for line in block.strip().splitlines():
        parts = [p.strip() for p in line.strip().rstrip(",").split(",")]
        jd, cal, x, y, z, vx, vy, vz = parts
        rows.append({"jd": float(jd), "date": cal, "x": float(x), "y": float(y), "z": float(z),
                     "vx": float(vx), "vy": float(vy), "vz": float(vz)})
    return rows


def build():
    bodies = []
    for key, sstr, command in TARGETS:
        sbdb = json.loads((RAW / (key + ".sbdb.json")).read_text())
        text = (RAW / (key + ".horizons.txt")).read_text()
        check_same_solution(key, sbdb, text)
        rows = parse_rows(text)
        assert len(rows) == len(OFFSETS), (key, len(rows))
        bodies.append({"key": key, "name": sbdb["object"]["fullname"], "horizonsCommand": command,
                       "sbdb": sbdb, "rows": rows})
    out = {
        "source": "JPL SBDB API (full-prec=1) elements; NASA/JPL Horizons API geometric vectors",
        "center": "Sun body centre (500@10)",
        "frame": "Ecliptic and mean equinox of J2000.0",
        "units": "AU, AU/day",
        "timescale": "TDB",
        "offsetsDays": OFFSETS,
        "bodies": bodies,
    }
    (HERE / "smallbodies.json").write_text(json.dumps(out, indent=1, sort_keys=True) + "\n")
    print("wrote smallbodies.json:", [b["key"] for b in bodies])


if __name__ == "__main__":
    RAW.mkdir(exist_ok=True)
    if "--offline" not in sys.argv:
        for key, sstr, command in TARGETS:
            print("fetching", key)
            fetch(key, sstr, command)
    build()
