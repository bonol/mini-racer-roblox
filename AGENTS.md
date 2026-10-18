# Agent contract

- **Current law:** [docs/ROADMAP.md](docs/ROADMAP.md) Rules — must match `ReplicatedStorage/Constants.luau`.
- **Live todos:** [docs/ROADMAP.md](docs/ROADMAP.md) Status — v2 playable (3 laps, multi-racer); Creator Hub listing leftover; next is v3 racer experience.
- **Product decision:** append [docs/DECISIONS.md](docs/DECISIONS.md) in the same turn; patch ROADMAP Rules if law changed. Do not rewrite `docs/v2/` catalogs for a tunable.
- **Commit:** include a [docs/TRACE.md](docs/TRACE.md) entry in the same commit. Git subject stays 1–2 sentences of why.
- **Play:** if Roblox Studio MCP is connected, start Play and exercise the changed loop before calling gameplay work done. Preferred place: **Mini Racer [testing]**, PlaceId `98798376352087`. Disk Sources must be in that DataModel; after TrackService changes destroy `Workspace.MiniRacerTrack`. If MCP is down, say so.

Cursor always-on rules: `.cursor/rules/product-decisions.mdc`, `commit-trace.mdc`, `studio-play-verify.mdc`.
