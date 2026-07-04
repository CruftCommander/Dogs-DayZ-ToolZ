# @OuterHeaven - Server Mod Package

Custom mod package for **Outer Heaven - Organic RP 1PP** (DayZ, Deer Isle).
One mod folder, multiple PBOs - each feature is its own PBO under `Addons\`,
one `-mod=@OuterHeaven` entry on client and server.

## Conventions (locked 2026-07-04)

| Convention | Value |
|---|---|
| Classname prefix | `DOG_` (permanent once items persist on server - do not change) |
| PBO namespace | `DOG\<PBOName>` via `$PBOPREFIX$` per source folder |
| Load order | Every feature PBO lists `DOG_Core` in `requiredAddons[]` |
| Versioning | `DOG_Constants.PACKAGE_VERSION` - bump per release, verify via RPT banner |
| Distribution | Steam Workshop item preferred (players auto-update as PBOs are added) |

Note: `DOG_` is exact-match distinct from `DUG_` in the Central Economy, but
visually similar - double-check hand edits in types.xml.

## Layout

```
src/DOG_Core/            Shared base: constants, startup RPT banner. No gameplay content.
src/DOG_Seasonings/      Seasoning items + seasoned meat system (see docs/seasonings-design.md)
src/DOG_LoadingScreens/  Custom loading screens (tips/tricks/server info over screenshots)
tools/pack.ps1           Addon Builder wrapper - ALWAYS build through this
tools/include.lst        File filter with *.c;*.cpp hardcoded (empty-PBO gotcha fix)
dist/Addons/             Build output (gitignored)
docs/                    Per-PBO design docs
```

## Build

Requires DayZ Tools (Steam App ID 830720). From PowerShell:

```powershell
.\tools\pack.ps1 -Pbo Core
.\tools\pack.ps1 -Pbo All
```

After every build: ExtractPbo the output and confirm `scripts/` is present
(guards the silent-empty-PBO Addon Builder failure).

## Deploy / verify

1. Copy `dist\Addons\*.pbo` into `@OuterHeaven\Addons\` (Workshop content folder or manual distribution).
2. Server: add `@OuterHeaven` to `-mod=` in the HostHavoc panel launch params.
3. Restart, then grep the RPT for `[DOG] Outer Heaven package loaded - version X.Y.Z`
   and for CE rejections (`will be ignored`, `Type does not exist`) on any new `DOG_` classnames.
4. types.xml / cfgspawnabletypes entries for new items follow the standard
   mission-file workflow (edit local mirror, validate, FTP to `mpmissions/empty.deerisle/`).

## Adding a new feature PBO

1. `src/DOG_<Feature>/` with `$PBOPREFIX$` = `DOG\<Feature>`.
2. `config.cpp`: CfgPatches class `DOG_<Feature>` with `requiredAddons[] = {"DOG_Core", ...}`.
3. Own `CfgMods` entry registering only script module paths that actually exist.
4. Add the name to the `ValidateSet` in `tools/pack.ps1`.
5. Design doc in `docs/`.
