# Changelog

## v0.4.0 Build 5 (2026-10-15)

- SQLite v4, safe migration from v1-v3, 12 new service fields, indexed service event history.
- Modern Service Center tabs and service intake form with 3 tab steps.
- Service payment and status editing, service timeline, copy + Bluetooth print ticket.
- New Account & Shop Settings with local profile and receipt footer.
- SQLite JSON backup/restore with SHA-256 checksum, preview, destructive-action confirmation, atomic table restore.
- Paired Bluetooth Classic thermal printer support, ESC/POS text, 58/80 mm, test print, receipt output.
- SQLite diagnostics page, About page, animated settings header and menu cards.
- CI: generate Android platform, inject Bluetooth manifest permissions, remove incompatible generated Flutter counter test, analyze, format, basic unit test, build artifact.
- Caveat: Needs Flutter CI and physical-device validation. No production release signing yet.
