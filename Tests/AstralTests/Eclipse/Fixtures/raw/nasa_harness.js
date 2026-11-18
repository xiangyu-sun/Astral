// Runs NASA's SEcirc.js (GSFC solar eclipse map calculator) offline.
// usage: node nasa_harness.js <path to SEcirc.js>   (JSON on stdin: {elements: "<var elements = ...>", sites: [[lat, lonEast], ...]})
const fs = require("fs");
const vm = require("vm");

const circPath = process.argv[2];
const input = JSON.parse(fs.readFileSync(0, "utf8"));
const ctx = vm.createContext({ Math, console });
vm.runInContext(input.elements, ctx);
vm.runInContext(fs.readFileSync(circPath, "utf8"), ctx);

const harness = `
function snapshot(c) {
  return { t: c[1], altitudeDeg: c[31] * R2D, azimuthDeg: ((c[32] * R2D) % 360 + 360) % 360,
           timeDisplay: gettime(c), altDisplay: getalt(c), aziDisplay: getazi(c) };
}
function runSite(lat, lon) {
  readdata(lat, lon);
  getall();
  const type = mid[36];
  const out = { jsType: type };
  if (type === 0) { out.type = "none"; return out; }
  out.mid = snapshot(mid);
  out.magnitude = mid[34];
  out.magnitudeDisplay = Math.round(mid[34] * 1000) / 1000.0;
  out.obscurationDisplay = getcoverage();
  out.c1 = snapshot(c1);
  out.c4 = snapshot(c4);
  let kind = type === 1 ? "partial" : (type === 2 ? "annular" : "total");
  if (type > 1) {
    out.c2 = snapshot(c2);
    out.c3 = snapshot(c3);
    out.durationDisplay = getduration();
  }
  if (c1[31] <= 0 && c4[31] <= 0) { out.type = "none"; return out; }
  if (type > 1 && c2[31] <= 0 && c3[31] <= 0) { kind = "partial"; delete out.c2; delete out.c3; delete out.durationDisplay; }
  out.type = kind;
  // obscuration as a fraction (what getcoverage prints, without rounding)
  out.obscuration = parseFloat(getcoverage()) / 100;
  return out;
}
`;
vm.runInContext(harness, ctx);
const dT = vm.runInContext("elements[4]", ctx);
const t0 = vm.runInContext("elements[1]", ctx);
const results = input.sites.map(([lat, lon]) => {
  ctx.__lat = lat; ctx.__lon = lon;
  const r = vm.runInContext("runSite(__lat, __lon)", ctx);
  const toSeconds = (s) => s ? (s.t + t0 - dT / 3600) * 3600 : undefined;
  for (const k of ["mid", "c1", "c2", "c3", "c4"]) {
    if (r[k]) { r[k].utSeconds = toSeconds(r[k]); delete r[k].t; }
  }
  return r;
});
process.stdout.write(JSON.stringify(results));
