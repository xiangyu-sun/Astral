---
name: bump-dependents
description: After releasing a new version of a local Swift package (e.g. Astral), find every local repo that depends on it (directly or transitively), and bump them one by one in dependency order, releasing and pushing each, using parallel Sonnet subagents per level. Use when the user says a package "bumped its version" and their local projects/apps need to follow.
---

# bump-dependents

Propagate a released Swift package version down the user's local dependency tree.
Default workspace: `~/Documents/GitHub`. Args: the package name (default: the repo you are in).

## 1. Map the tree
```bash
python3 -I .claude/skills/bump-dependents/scripts/dependents.py <PackageName> [workspace-root]
```
Prints levels (L1 = depends directly; higher = further downstream), library vs app, branch, latest tag
(shows the tag convention: `v1.2.3` vs `1.2.3`, or none), dirty state, each declared requirement and the pinned version.
Also `git fetch --tags` in each repo: local clones are often behind (CAC was 10 commits behind).
Confirm the root package's new tag is on the remote: `git ls-remote --tags <url> refs/tags/<tag>`.
Repos that never appear in the output do not depend on it: leave them alone.

## 2. Bump level by level
Levels are sequential (a level needs the previous level's tags on the remote), repos inside one level are parallel.
- **L1 (usually one repo): do it yourself** so you learn the repo's conventions (CHANGELOG, CLAUDE.md that mentions the
  pinned version, README snippets).
- **Libraries in a level: one background Sonnet subagent each** (`Agent` with `model: "sonnet"`, `run_in_background`).
  Brief each with: repo path, branch, tag convention, the exact new version of the dependency, and the steps below.
- **Apps (Xcode projects): last level**, same fan-out, but no tags (apps have none) and the extra rules below.
- After each hand-back, verify the tag exists on the remote (`git ls-remote --tags <url> refs/tags/<tag>`).
  Use a loop with `r=${p%%:*}`; never word-split a `"$1 $2"` into a URL.

### Library steps (per repo)
1. `git pull --ff-only`; never stage `.claude/`, `.DS_Store`, or pre-existing dirty files.
2. Raise the requirement in `Package.swift` (`from: "X"`) plus every doc mention (CLAUDE.md, README, CHANGELOG entry).
3. `swift package update`; `Package.resolved` must show the new dependency versions. If `Package.resolved` is gitignored, do not commit it.
4. `swift build && swift test` must pass. Fix only genuine API breakage; never loosen test tolerances.
5. Version: patch bump for a pure requirement bump, minor if code changed. Match the repo's tag convention.
   An untagged library gets `1.0.0` (say so in the report).
6. Commit `<version>: require <Dep> <X>` with the Co-Authored-By trailer, annotated tag, `git push origin <branch> <tag>`.
   If branch protection rejects it: push a branch and open a PR with `gh`. Never force-push.

### App steps (Xcode projects)
1. Same hygiene as above. Stage only `project.pbxproj` and the tracked
   `*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
2. Edit `minimumVersion` in the `XCRemoteSwiftPackageReference` block of the changed package. Match the block, not a
   line number (`sed -i ''` on a line number is fragile).
3. `xcodebuild -resolvePackageDependencies -project <App>.xcodeproj`. Version-range pins move by themselves.
4. **Branch-pinned packages do NOT move** (even with `-scmProvider system`, and deleting the pin just re-adds the old
   one). Get the new commit with `git ls-remote <url> refs/heads/<branch>`, edit that pin's `revision` in
   `Package.resolved` with `sed -i ''`, then re-run resolve; it prints `Checking out <branch> (<sha>)`.
5. Verify with `xcodebuild -scheme <S> -destination 'generic/platform=iOS Simulator' build`, then
   `xcodebuild test -scheme <S> -destination 'platform=iOS Simulator,id=<UDID>' -only-testing:<S>Tests`.
   Names like `iPhone 17` can be ambiguous across OS versions, and a CLAUDE.md destination may no longer exist: take
   the `id=` from `xcodebuild -scheme <S> -showdestinations`. macOS/watchOS builds and UI tests are skipped unless asked.
6. Commit and push (no tag) to the app's branch.

## 3. Finish
Re-run `dependents.py`: every pin should equal the new versions. Report a table: repo, new version, dependency
versions resolved, tests, push result, and anything skipped (platform builds, snapshot tests, dirty files left alone).
Treat subagent reports as claims: spot-check the remote tags and the final script output.

## Known quirks from the Astral 1.4.0 run
- `from: "1.3.0"` already admits 1.4.0; the bump still matters to raise the floor and refresh pins/CHANGELOGs.
- Package name in `.product(package:)` is the lowercase repo name (`astral`), unaffected by the URL's `.git` suffix.
- Repos can hold `.claude/worktrees/*` copies with their own Package.swift; the script ignores them.
