// swiftlint:disable no_direct_standard_out_logs
#!/usr/bin/env python3
"""Fetch planet rise / transit / set times and az/el samples from JPL Horizons into horizons_rts.json.

Run with `python3 -I make_rts_fixture.py [--cache DIR]` (stdlib only; needs network). `--cache DIR` keeps the raw
API responses so that a re-run is offline. The committed JSON is the only thing the tests read.

For every (planet, observer, UTC date) three things are requested from
https://ssd.jpl.nasa.gov/api/horizons.api (EPHEM_TYPE=OBSERVER, CENTER='coord@399', SITE_COORD):

1. R_T_S_ONLY=YES, 1 minute step, APPARENT=REFRACTED: JPL's own rise / transit / set flags. Their accuracy is
   "twice the requested step"; they include the horizon dip of the site altitude. They are stored as `jplFlags`
   and, at sea-level sites, used to cross-check step 2.
2. A full 1 minute table of refracted apparent azimuth / elevation and local apparent hour angle over the UTC day.
   Rise and set are the linear-interpolated crossings of refracted elevation = 0 (JPL's default RTS cut-off,
   which makes rise/set mean "true horizon, yellow-light refraction included"); transit is the crossing of the
   local apparent hour angle through 0. Resolution is a few seconds.
3. APPARENT=AIRLESS azimuth / elevation every 4 hours, next to the refracted values of step 2 at the same times,
   to test position without the refraction model and with it.

Nothing is edited: numbers come from the responses; event times are interpolated as described above.
Times are UT (JPL "TIME_ZONE=+00:00"); the Astral model treats UTC as TT.
"""
import datetime as dt
import json
import pathlib
import sys
import time
import urllib.parse
import urllib.request

API = "https://ssd.jpl.nasa.gov/api/horizons.api"
HERE = pathlib.Path(__file__).resolve().parent

BODIES = {
    "mercury": "199", "venus": "299", "mars": "499", "jupiter": "599",
    "saturn": "699", "uranus": "799", "neptune": "899", "pluto": "999",
}


def dms(deg, minutes, seconds, negative):
    value = deg + minutes / 60.0 + seconds / 3600.0
    return -value if negative else value


# Coordinates of Observer.london / .wellington / .riyadh (Sources/Astral/Observer.swift).
# NOTE: Observer.wellington is declared as " 41° 17' 11.256'' S" / "174° 46' 34.4496'' E", but Astral's DMS parser
# (a) ignores seconds that are not ended by ″ or " and (b) then misses the hemisphere letter, so today the Observer
# actually holds +41.2833 (north!) / 174.7667. The fixture uses the intended place (41°17'11.256" S, 174°46'34.4496" E),
# the only southern-hemisphere site; the tests build that Observer from the fixture numbers.
OBSERVERS = {
    "london": {"lat": 51.4733, "lon": -0.0008333, "elevation_m": 0.0},
    "wellington": {
        "lat": dms(41, 17, 11.256, True), "lon": dms(174, 46, 34.4496, False), "elevation_m": 13.0,
    },
    "riyadh": {"lat": 25.0, "lon": 46.7, "elevation_m": 620.0},
}

DATES = ["2000-01-01", "2024-06-21", "2026-11-17"]


def request(params, cache):
    query = urllib.parse.urlencode(params)
    key = None
    if cache is not None:
        import hashlib
        key = cache / (hashlib.sha1(query.encode()).hexdigest() + ".json")
        if key.exists():
            return json.loads(key.read_text())["result"]
    last = None
    for attempt in range(6):
        try:
            with urllib.request.urlopen(f"{API}?{query}", timeout=90) as response:
                payload = json.loads(response.read().decode())
            if "result" in payload and "$$SOE" in payload["result"]:
                if key is not None:
                    cache.mkdir(parents=True, exist_ok=True)
                    key.write_text(json.dumps(payload))
                time.sleep(0.15)
                return payload["result"]
            last = payload.get("error") or payload.get("result", "")[-300:]
        except Exception as exc:  # network hiccup: retry
            last = repr(exc)
        time.sleep(2 + 3 * attempt)
    raise RuntimeError(f"Horizons request failed: {params} -> {last}")


def base_params(body, observer, start, stop, step, quantities, apparent, rts):
    site = OBSERVERS[observer]
    params = {
        "format": "json", "COMMAND": f"'{BODIES[body]}'", "EPHEM_TYPE": "'OBSERVER'",
        "CENTER": "'coord@399'",
        "SITE_COORD": f"'{site['lon']!r},{site['lat']!r},{site['elevation_m'] / 1000.0!r}'",
        "START_TIME": f"'{start}'", "STOP_TIME": f"'{stop}'", "STEP_SIZE": f"'{step}'",
        "QUANTITIES": f"'{quantities}'", "APPARENT": f"'{apparent}'", "ANG_FORMAT": "'DEG'",
        "TIME_ZONE": "'+00:00'", "CSV_FORMAT": "'YES'", "CAL_FORMAT": "'CAL'",
    }
    if rts:
        params["R_T_S_ONLY"] = "'YES'"
    return params


def rows_of(result):
    block = result.split("$$SOE")[1].split("$$EOE")[0]
    rows = []
    for line in block.strip().splitlines():
        cells = [c.strip() for c in line.strip().rstrip(",").split(",")]
        when = dt.datetime.strptime(cells[0], "%Y-%b-%d %H:%M").replace(tzinfo=dt.timezone.utc)
        rows.append((when, cells[1:]))
    return rows


def crossings(times, values, level, direction):
    """Linear-interpolated times (seconds) at which `values` crosses `level` (direction +1 up, -1 down)."""
    out = []
    for i in range(1, len(values)):
        a, b = values[i - 1] - level, values[i] - level
        if direction > 0 and a < 0 <= b or direction < 0 and a >= 0 > b:
            if abs(values[i] - values[i - 1]) > 90:  # azimuth / hour-angle wrap, not a crossing
                continue
            out.append(times[i - 1] + (times[i] - times[i - 1]) * (-a) / (b - a))
    return out


def day_events(body, observer, day, cache):
    midnight = dt.datetime.fromisoformat(day).replace(tzinfo=dt.timezone.utc)
    start = (midnight - dt.timedelta(minutes=5)).strftime("%Y-%m-%d %H:%M")
    stop = (midnight + dt.timedelta(days=1, minutes=5)).strftime("%Y-%m-%d %H:%M")
    table = rows_of(request(base_params(body, observer, start, stop, "1 min", "4,42", "REFRACTED", False), cache))
    secs = [(when - midnight).total_seconds() for when, _ in table]
    az = [float(cells[2]) for _, cells in table]
    el = [float(cells[3]) for _, cells in table]
    ha = [float(cells[4]) for _, cells in table]
    ha = [h - 360.0 if h > 180 else h for h in ha]  # to (-180, 180]

    def in_day(values):
        return [round(v, 1) for v in values if 0.0 <= v < 86400.0]

    events = {
        "rise": in_day(crossings(secs, el, 0.0, +1)),
        "transit": in_day(crossings(secs, ha, 0.0, +1)),
        "set": in_day(crossings(secs, el, 0.0, -1)),
    }
    # JPL's own flags (1 min step, "accuracy <= twice the step"). They include the horizon dip of the site's
    # altitude, which the elevation table does not, so they only bracket our level-horizon refinement at sea
    # level; they are stored for every site and used by the tests as an independent 2 minute reference.
    flags = rows_of(request(base_params(body, observer, f"{day} 00:00", f"{day} 23:59", "1 min", "4", "REFRACTED", True), cache))
    flagged = {"r": [], "t": [], "s": []}
    for when, cells in flags:
        mark = cells[1]
        if mark == "e":  # JPL's elevation-maximum marker replaces the transit marker when they share a step
            mark = "t"
        if mark in flagged:
            flagged[mark].append(int((when - midnight).total_seconds()))
    jpl_flags = {"rise": flagged["r"], "transit": flagged["t"], "set": flagged["s"]}
    for mark, name in (("r", "rise"), ("t", "transit"), ("s", "set")):
        mine, theirs = events[name], flagged[mark]
        if OBSERVERS[observer]["elevation_m"] == 0.0:
            for m in mine:
                if not any(f - 120.0 <= m <= f + 60.0 for f in theirs):
                    raise RuntimeError(f"{body} {observer} {day}: {name} {m} not near JPL flags {theirs}")

    airless = rows_of(request(base_params(body, observer, f"{day} 00:00", f"{day} 23:59", "240 min", "4", "AIRLESS", False), cache))
    samples = []
    for when, cells in airless:
        seconds = (when - midnight).total_seconds()
        index = secs.index(seconds)
        samples.append({
            "t": int(seconds),
            "airlessAz": float(cells[2]), "airlessEl": float(cells[3]),
            "refractedAz": az[index], "refractedEl": el[index],
        })
    return {"body": body, "observer": observer, "date": day, "events": events, "jplFlags": jpl_flags, "samples": samples}


def main():
    cache = None
    if "--cache" in sys.argv:
        cache = pathlib.Path(sys.argv[sys.argv.index("--cache") + 1])
    cases = []
    for body in BODIES:
        for observer in OBSERVERS:
            for day in DATES:
                cases.append(day_events(body, observer, day, cache))
                print("fetched", body, observer, day, cases[-1]["events"], flush=True)
    out = {
        "source": "NASA/JPL Horizons API, OBSERVER ephemeris",
        "center": "coord@399 (topocentric, SITE_COORD east-longitude, latitude, altitude km)",
        "definition": {
            "rise_set": "refracted apparent elevation crosses 0 deg: level horizon, no dip (JPL default RTS cut-off)",
            "jplFlags": "JPL's own R_T_S_ONLY flags, 1 minute step; they include the dip of the site altitude",
            "transit": "local apparent hour angle crosses 0",
            "times": "seconds after 00:00 UT on `date`, interpolated from a 1 minute table (resolution ~1 s)",
            "samples": "airless and refracted apparent azimuth/elevation, degrees, at `t` seconds after 00:00 UT",
        },
        "observers": OBSERVERS,
        "cases": cases,
    }
    (HERE / "horizons_rts.json").write_text(json.dumps(out, indent=1) + "\n")
    print("wrote", len(cases), "cases")


if __name__ == "__main__":
    main()
