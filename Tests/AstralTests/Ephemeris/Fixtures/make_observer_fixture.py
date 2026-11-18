// swiftlint:disable no_direct_standard_out_logs
#!/usr/bin/env python3
"""Build horizons_observer.json: topocentric Sun/Moon data from NASA/JPL Horizons.

Run with `python3 -I make_observer_fixture.py`            -> parse raw_observer/*.txt into horizons_observer.json
Run with `python3 -I make_observer_fixture.py --fetch`    -> (re)download raw_observer/*.txt first (needs network)

Python standard library only. Every number in the JSON is copied from a Horizons response, except the
"refined" rise/set/transit times, which are interpolated between two Horizons rows (see below).

Query design (Horizons API, EPHEM_TYPE=OBSERVER, CENTER='coord@399', SITE_COORD=lon,lat,elev_km, UTC):
  1. Rise/transit/set pass: one query per (body, observer, UTC day), R_T_S_ONLY='TVH', 1-minute steps.
     Horizons reports each event on the first 1-minute step AFTER it happened. The flag letters are
     r = rise, t = meridian transit, s = set (e = maximum elevation is ignored).
  2. Sample pass: one TLIST query per (body, observer, APPARENT in AIRLESS/REFRACTED) for
       - 6 fixed instants per day (00/04/08/12/16/20 UTC) used to test azimuth/elevation,
       - the 1-minute steps around each flagged event, used to refine it to sub-minute precision.
     QUANTITIES = 2 (apparent RA/Dec), 4 (apparent az/el), 13 (angular diameter), 20 (range, deldot).
  3. Geocentric pass (Moon only): CENTER='500@399', QUANTITIES=2,20 at the fixed instants, to test the
     Moon's geocentric RA/Dec independently of parallax.

Refinement of rise/set: linear interpolation between the two Horizons rows that bracket the flagged
step, of the AIRLESS apparent centre elevation crossing -(34' + angular semi-diameter + horizon dip), where
the dip is acos(R/(R+h)) for the site elevation h (Riyadh 620 m, Wellington 13 m; Horizons does apply a
dip). This is the threshold Horizons' own flags are consistent with (34' standard refraction plus the
semi-diameter of the disc, i.e. upper limb on a refracted horizon); the script asserts that every crossing lands inside the
interval ending at the flagged step, which validates the inference on every event.
Refinement of transit: linear interpolation of the azimuth crossing 180 deg (or 0 deg for a Sun that
culminates north of the zenith) between the two rows that bracket the flagged step.
"""
import datetime
import json
import math
import pathlib
import re
import sys
import time
import urllib.parse
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
RAW = HERE / "raw_observer"
API = "https://ssd.jpl.nasa.gov/api/horizons.api"

# Same coordinates as Observer.london / newDelhi / riyadh / wellington / barcelona (Observer.swift).
OBSERVERS = {
    "london": {"latitude": 51.4733, "longitude": -0.0008333, "elevationMeters": 0.0},
    "newDelhi": {"latitude": 28.6139, "longitude": 77.2090, "elevationMeters": 0.0},
    "riyadh": {"latitude": 25.0, "longitude": 46.7, "elevationMeters": 620.0},
    # " 41° 17' 11.256'' S", "174° 46' 34.4496'' E"
    "wellington": {"latitude": -(41 + 17 / 60 + 11.256 / 3600), "longitude": 174 + 46 / 60 + 34.4496 / 3600,
                   "elevationMeters": 13.0},
    # "41° 23' 24.7380'' N", "2° 9' 14.4252'' E"
    "barcelona": {"latitude": 41 + 23 / 60 + 24.738 / 3600, "longitude": 2 + 9 / 60 + 14.4252 / 3600,
                  "elevationMeters": 0.0},
}
BODIES = {"sun": "10", "moon": "301"}
DATES = ["2024-06-20", "2024-12-21", "2025-03-20", "2025-06-21",
         "2025-09-22", "2025-12-21", "2026-03-20", "2026-09-23"]
SAMPLE_HOURS = [0, 4, 8, 12, 16, 20]
REFRACTION_ARCMIN = 34.0


def dip_deg(o):
    """Horizon dip for an observer above sea level: acos(R / (R + h)), R = 6371 km."""
    h = o["elevationMeters"]
    return 0.0 if h <= 0 else math.degrees(math.acos(6371000.0 / (6371000.0 + h)))


def site(o):
    return f"{o['longitude']:.9f},{o['latitude']:.9f},{o['elevationMeters'] / 1000:.6f}"


def query(**params):
    p = {"format": "text", "EPHEM_TYPE": "OBSERVER", "CENTER": "coord@399", "ANG_FORMAT": "DEG",
         "EXTRA_PREC": "YES"}
    p.update(params)
    qs = urllib.parse.urlencode({k: (v if k == "format" else f"'{v}'") for k, v in p.items()}, safe="'")
    for attempt in range(5):
        try:
            if len(qs) > 1500:  # long TLIST: the GET URL would be too long, POST the same form instead
                text = urllib.request.urlopen(API, data=qs.encode(), timeout=120).read().decode()
            else:
                text = urllib.request.urlopen(f"{API}?{qs}", timeout=120).read().decode()
            if "$$SOE" in text and "$$EOE" in text:
                return text
            if "No ephemeris for target" in text or "no rise" in text.lower():
                return text
            print("unexpected response, retrying:", text[:300].replace("\n", " "))
        except Exception as e:  # noqa: BLE001
            print("request failed, retrying:", e)
        time.sleep(3 * (attempt + 1))
    raise SystemExit("giving up on " + qs)


def jd_of(dt):
    return (dt - datetime.datetime(2000, 1, 1, 12)).total_seconds() / 86400 + 2451545.0


def day_start(date):
    return datetime.datetime.strptime(date, "%Y-%m-%d")


def minute_instants(date, events):
    """Instants (datetimes, sorted, unique) needed for one (body, observer): samples + event neighbourhoods."""
    out = set()
    for d in DATES:
        for h in SAMPLE_HOURS:
            out.add(day_start(d) + datetime.timedelta(hours=h))
    for t, kind in events:
        out.add(t - datetime.timedelta(minutes=1))
        out.add(t)
        if kind == "t":
            out.add(t + datetime.timedelta(minutes=1))
    return sorted(out)


# --------------------------------------------------------------------------- parsing

ROW = re.compile(r"^\s*(\d{4}-[A-Za-z]{3}-\d{2} \d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?)\s+(.*)$")


def parse_time(s):
    for fmt in ("%Y-%b-%d %H:%M:%S.%f", "%Y-%b-%d %H:%M:%S", "%Y-%b-%d %H:%M"):
        try:
            return datetime.datetime.strptime(s, fmt)
        except ValueError:
            pass
    raise ValueError(s)


def parse_rows(text):
    """-> list of (datetime, flags string, [floats])"""
    if "$$SOE" not in text:
        return []
    block = text.split("$$SOE")[1].split("$$EOE")[0]
    rows = []
    for line in block.splitlines():
        m = ROW.match(line)
        if not m:
            continue
        toks = m.group(2).split()
        flags, nums = "", []
        for tok in toks:
            try:
                nums.append(float(tok))
            except ValueError:
                flags += tok
        rows.append((parse_time(m.group(1)), flags, nums))
    return rows


# --------------------------------------------------------------------------- fetching

CHUNK = 60  # Horizons truncates a TLIST at 80 entries, so every query carries at most 60 instants


def chunks(items):
    return [items[i:i + CHUNK] for i in range(0, len(items), CHUNK)]


def read_chunks(prefix):
    rows = []
    for path in sorted(RAW.glob(prefix + "_*.txt"), key=lambda p: int(p.stem.rsplit("_", 1)[1])):
        rows += parse_rows(path.read_text())
    return rows

def fetch():
    RAW.mkdir(exist_ok=True)
    for body, cmd in BODIES.items():
        for name, o in OBSERVERS.items():
            events = []
            for d in DATES:
                start = day_start(d)
                text = query(COMMAND=cmd, SITE_COORD=site(o), START_TIME=start.strftime("%Y-%m-%d %H:%M"),
                             STOP_TIME=(start + datetime.timedelta(days=1)).strftime("%Y-%m-%d %H:%M"),
                             STEP_SIZE="1 minute", QUANTITIES="4", TIME_DIGITS="SECONDS", APPARENT="AIRLESS",
                             R_T_S_ONLY="TVH")
                (RAW / f"{body}_{name}_rts_{d}.txt").write_text(text)
                time.sleep(0.3)
            events = collect_events(body, name)
            instants = minute_instants(None, events)
            for app in ("AIRLESS", "REFRACTED"):
                for i, chunk in enumerate(chunks(instants)):
                    text = query(COMMAND=cmd, SITE_COORD=site(o), TLIST=" ".join(f"{jd_of(t):.8f}" for t in chunk),
                                 QUANTITIES="2,4,13,20", TIME_DIGITS="FRACSEC", APPARENT=app)
                    (RAW / f"{body}_{name}_samples_{app.lower()}_{i}.txt").write_text(text)
                    time.sleep(0.3)
            print("fetched", body, name, len(instants), "instants")
    instants = minute_instants(None, [])
    for i, chunk in enumerate(chunks(instants)):
        text = query(COMMAND="301", CENTER="500@399", TLIST=" ".join(f"{jd_of(t):.8f}" for t in chunk),
                     QUANTITIES="2,20", TIME_DIGITS="FRACSEC", APPARENT="AIRLESS")
        (RAW / f"moon_geocentric_{i}.txt").write_text(text)


def collect_events(body, name):
    """[(minute datetime, 'r'|'t'|'s')] for every flagged row of every RTS file of (body, observer)."""
    out = []
    for d in DATES:
        text = (RAW / f"{body}_{name}_rts_{d}.txt").read_text()
        for t, flags, nums in parse_rows(text):
            kinds = [k for k in flags if k in "rts"]
            if body == "moon":
                kinds = [k for k in kinds if k in "rs"]
            for k in kinds[:1]:
                if t.strftime("%Y-%m-%d") == d:
                    out.append((t, k))
    return out


# --------------------------------------------------------------------------- build

def build():
    samples_t = [day_start(d) + datetime.timedelta(hours=h) for d in DATES for h in SAMPLE_HOURS]
    fixed = {t for t in samples_t}
    result = {
        "source": "NASA/JPL Horizons API (DE441), OBSERVER ephemeris, CENTER=coord@399, times in UTC",
        "notes": [
            "airless: APPARENT=AIRLESS (no refraction); refracted: APPARENT=REFRACTED (Horizons Earth refraction model)",
            "az measured from North towards East; az/el are topocentric apparent; ra/dec are topocentric apparent, degrees",
            "delta: observer range in AU; diameterArcsec: target angular diameter",
            "rise/set/transit: flagUTC is the Horizons RTS step (first step after the event); refinedSecondsOfDay is "
            "interpolated between Horizons rows (see make_observer_fixture.py)",
        ],
        "dates": DATES,
        "sampleHoursUTC": SAMPLE_HOURS,
        "refractionArcmin": REFRACTION_ARCMIN,
        "observers": OBSERVERS,
        "bodies": {},
    }
    worst = {"r": 0.0, "s": 0.0, "t": 0.0}
    for body in BODIES:
        result["bodies"][body] = {}
        for name in OBSERVERS:
            air = {t: (f, n) for t, f, n in read_chunks(f"{body}_{name}_samples_airless")}
            ref = {t: (f, n) for t, f, n in read_chunks(f"{body}_{name}_samples_refracted")}
            assert air.keys() == ref.keys() and air, (body, name)

            def need(t):
                key = min(air, key=lambda x: abs((x - t).total_seconds()))
                assert abs((key - t).total_seconds()) < 0.05, (body, name, t, key)
                return air[key][1]

            samples = []
            for t in samples_t:
                a = need(t)
                key = min(ref, key=lambda x: abs((x - t).total_seconds()))
                r = ref[key][1]
                samples.append({
                    "utc": t.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "ra": a[0], "dec": a[1], "az": a[2], "el": a[3], "diameterArcsec": a[4], "delta": a[5],
                    "refractedAz": r[2], "refractedEl": r[3],
                })
            events = {}
            for d in DATES:
                events[d] = {}
            for t, kind in collect_events(body, name):
                d = t.strftime("%Y-%m-%d")
                rows = [(t + datetime.timedelta(minutes=k), need(t + datetime.timedelta(minutes=k))) for k in ((-1, 0) if kind in "rs" else (-1, 0, 1))]
                if kind in "rs":
                    thr_rows = [(tt, n[3], -(REFRACTION_ARCMIN / 60 + n[4] / 3600 / 2 + dip_deg(OBSERVERS[name]))) for tt, n in rows]
                    (t0, e0, th0), (t1, e1, th1) = thr_rows
                    f0, f1 = e0 - th0, e1 - th1
                    assert f0 * f1 < 0, f"flag not bracketing a crossing: {body} {name} {t} {kind} {f0} {f1}"
                    frac = f0 / (f0 - f1)
                    refined = t0 + datetime.timedelta(seconds=60 * frac)
                    thr = th0 + (th1 - th0) * frac
                    worst[kind] = max(worst[kind], 0.0)
                    events[d]["rise" if kind == "r" else "set"] = {
                        "flagUTC": t.strftime("%Y-%m-%dT%H:%M:%SZ"),
                        "refinedSecondsOfDay": (refined - day_start(d)).total_seconds(),
                        "thresholdDeg": thr,
                    }
                else:
                    azs = [n[2] for _, n in rows]
                    target = 180.0 if abs(azs[1] - 180.0) < 90 else 0.0
                    if target == 0.0:
                        azs = [a - 360 if a > 180 else a for a in azs]
                    pair = [(tt, a - target) for (tt, _), a in zip(rows, azs)]
                    cand = None
                    for (ta, fa), (tb, fb) in zip(pair, pair[1:]):
                        if fa * fb <= 0 and fa != fb:
                            cand = ta + datetime.timedelta(seconds=60 * fa / (fa - fb))
                            break
                    assert cand is not None, f"no azimuth crossing at transit {body} {name} {t}"
                    events[d]["transit"] = {
                        "flagUTC": t.strftime("%Y-%m-%dT%H:%M:%SZ"),
                        "refinedSecondsOfDay": (cand - day_start(d)).total_seconds(),
                        "maxElevationDeg": rows[1][1][3],
                    }
            result["bodies"][body][name] = {"samples": samples, "events": events}
    # geocentric Moon RA/Dec
    geo = read_chunks("moon_geocentric")
    geo_samples = []
    for t in samples_t:
        key = min(geo, key=lambda x: abs((x[0] - t).total_seconds()))
        assert abs((key[0] - t).total_seconds()) < 0.05
        geo_samples.append({"utc": t.strftime("%Y-%m-%dT%H:%M:%SZ"), "ra": key[2][0], "dec": key[2][1], "delta": key[2][2]})
    result["moonGeocentric"] = geo_samples
    (HERE / "horizons_observer.json").write_text(json.dumps(result, indent=1) + "\n")
    n_events = sum(len(v) for b in result["bodies"].values() for o in b.values() for v in o["events"].values())
    print("wrote horizons_observer.json:", n_events, "events,", len(samples_t), "samples per (body, observer)")


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    build()
