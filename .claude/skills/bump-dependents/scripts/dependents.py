#!/usr/bin/env python3 -I
"""Map the local dependency tree below a Swift package.

usage: dependents.py <package-name> [workspace-root]
Prints repos (topologically ordered, level 1 = depends directly) that reference the package,
with declared requirement, resolved pin, repo kind (library/app), git tag convention and dirtiness.
Skips .build, .claude/worktrees and checkouts.
"""
import json, os, re, subprocess, sys

name = sys.argv[1]
root = os.path.expanduser(sys.argv[2] if len(sys.argv) > 2 else "~/Documents/GitHub")

def sh(*a, cwd=None):
    return subprocess.run(a, cwd=cwd, capture_output=True, text=True).stdout.strip()

repos = {}
for d in sorted(os.listdir(root)):
    p = os.path.join(root, d)
    if not os.path.isdir(os.path.join(p, ".git")):
        continue
    info = {"path": p, "deps": {}, "kind": "app" if any(x.endswith(".xcodeproj") for x in os.listdir(p)) and not os.path.exists(os.path.join(p, "Package.swift")) else "library"}
    # declared deps: Package.swift
    ps = os.path.join(p, "Package.swift")
    if os.path.exists(ps):
        s = open(ps).read()
        for m in re.finditer(r'\.package\(\s*url:\s*"([^"]+)"\s*,\s*([^)]*?)\)', s, re.S):
            info["deps"][re.sub(r'(\.git)?$', '', m.group(1)).split("/")[-1]] = ("Package.swift", " ".join(m.group(2).split()))
    # declared deps: xcodeproj
    for x in [f for f in os.listdir(p) if f.endswith(".xcodeproj")]:
        pb = os.path.join(p, x, "project.pbxproj")
        if os.path.exists(pb):
            for m in re.finditer(r'XCRemoteSwiftPackageReference[^{]*\{.*?repositoryURL = "([^"]+)";\s*requirement = \{(.*?)\};', open(pb).read(), re.S):
                req = " ".join(re.sub(r'\s+', ' ', m.group(2)).split())
                info["deps"][re.sub(r'(\.git)?$', '', m.group(1)).split("/")[-1]] = ("pbxproj", req)
    # resolved pins
    pins = {}
    cands = [os.path.join(p, "Package.resolved")]
    for x in [f for f in os.listdir(p) if f.endswith(".xcodeproj")]:
        cands.append(os.path.join(p, x, "project.xcworkspace/xcshareddata/swiftpm/Package.resolved"))
    for c in cands:
        if os.path.exists(c):
            j = json.load(open(c))
            for pin in j.get("pins", j.get("object", {}).get("pins", [])):
                loc = pin.get("location") or pin.get("repositoryURL", "")
                st = pin.get("state", {})
                pins[re.sub(r'(\.git)?$', '', loc).split("/")[-1]] = st.get("version") or ("%s@%s" % (st.get("branch"), (st.get("revision") or "")[:7]))
            info["resolved_file"] = os.path.relpath(c, p)
    info["pins"] = pins
    tags = sh("git", "tag", "--sort=-v:refname", cwd=p).splitlines()
    info["tag"] = tags[0] if tags else None
    info["branch"] = sh("git", "branch", "--show-current", cwd=p)
    info["dirty"] = [l for l in sh("git", "status", "--porcelain", cwd=p).splitlines() if ".claude/worktrees" not in l]
    repos[d] = info

# levels
level = {}
def lv(r, seen=()):
    if r in level: return level[r]
    if r in seen: return 0
    ds = [dep for dep in repos[r]["deps"] if dep in repos and dep != r]
    sub = [lv(dep, seen + (r,)) for dep in ds if dep == name or reaches(dep, set())]
    level[r] = (max(sub) + 1) if sub else 0
    return level[r]
def reaches(r, seen):
    if r == name: return True
    if r in seen or r not in repos: return False
    seen.add(r)
    return any(d == name or reaches(d, seen) for d in repos[r]["deps"])

hits = [r for r in repos if r != name and reaches(r, set())]
for r in hits: lv(r)
for r in sorted(hits, key=lambda r: (level[r], r)):
    i = repos[r]
    print(f"L{level[r]} {r}  [{i['kind']}] branch={i['branch']} latest-tag={i['tag']} dirty={i['dirty'] or 'clean'}")
    for dep, (src, req) in i["deps"].items():
        if dep in hits or dep == name:
            print(f"     {dep}: {src}: {req}  | pinned {i['pins'].get(dep)}  ({i.get('resolved_file','no Package.resolved')})")
