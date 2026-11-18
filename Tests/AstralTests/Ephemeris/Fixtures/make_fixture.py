// swiftlint:disable no_direct_standard_out_logs
#!/usr/bin/env python3
"""Parse raw JPL Horizons API responses in raw/*.txt into horizons.json.

Frame: heliocentric (Sun body centre), ecliptic J2000, AU. Times are TDB.
Rows between $$SOE and $$EOE: JD, calendar date, X, Y, Z. Nothing is edited
or invented; numbers are copied verbatim from the responses.
"""
import json, pathlib, re

HERE = pathlib.Path(__file__).resolve().parent
RAW = HERE / "raw"
NAMES = {
    "199": "mercury", "299": "venus", "3": "emb", "399": "earth", "301": "moon",
    "4": "mars", "5": "jupiter", "6": "saturn", "7": "uranus", "8": "neptune", "9": "pluto",
}

bodies = {}
for code, name in NAMES.items():
    text = (RAW / f"{code}.txt").read_text()
    block = text.split("$$SOE")[1].split("$$EOE")[0]
    rows = []
    for line in block.strip().splitlines():
        parts = [p.strip() for p in line.strip().rstrip(",").split(",")]
        jd, cal, x, y, z = parts
        rows.append({"jd": float(jd), "date": cal, "x": float(x), "y": float(y), "z": float(z)})
    bodies[name] = rows

out = {
    "source": "NASA/JPL Horizons API (DE441), GEOMETRIC cartesian states",
    "center": "Sun body centre (500@10)",
    "frame": "Ecliptic of J2000.0",
    "units": "AU",
    "timescale": "TDB (treated as equal to UTC by OrbitKit)",
    "note": "mars..pluto, emb are system barycentres; mercury/venus/earth/moon are body centres",
    "bodies": bodies,
}
(HERE / "horizons.json").write_text(json.dumps(out, indent=1) + "\n")
print("wrote", len(bodies), "bodies,", {k: len(v) for k, v in bodies.items()})
