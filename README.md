# DeerIsle_FinderOuter_InitFix

Server-only hotfix PBO. Defers DeerIsle_FinderOuter's constructor-time loot spawn to OnMissionStart, eliminating the init-time InitTemperature NULL pointer exceptions (Rice / SpaghettiCan / BakedBeansCan). No client download, no .bisign, no third-party files modified.

## Pack

1. Copy this `DeerIsle_FinderOuter_InitFix\` folder into your pack workspace. Commit to `D:\GitHub\Dogs DayZ ToolZ\` first.
2. Pack with Mikero PboProject or BI AddonBuilder (DayZ Tools, Steam App ID 830720).
   - Addon prefix MUST be `DeerIsle_FinderOuter_InitFix` (matches `dir` and the `files[]` script path in config.cpp).
   - Output: `@DeerIsle_FinderOuter_InitFix\addons\DeerIsle_FinderOuter_InitFix.pbo`
3. No signing step - servermod PBOs are exempt from client signature checks.

## Deploy (production launch-config change - do in a pre-restart window)

1. WinSCP: upload `@DeerIsle_FinderOuter_InitFix\` to the server root, alongside the other `@Mod` folders.
2. HostHavoc panel: set `-servermod=@DeerIsle_FinderOuter_InitFix` (currently empty). Do NOT add to `-mod=`.
3. Let the next scheduled 4h reboot pick it up, or restart manually.

## Verify (next RPT)

1. No `SCRIPT (E)` compile errors referencing `DeerIsle_FinderOuter_InitFix`.
   - If present: the OnMissionStart override failed to compile against 1.29. Swap in the CallLater fallback (commented block at the bottom of the .c file), repack, redeploy.
2. Zero `InitTemperature` / `NULL pointer to instance` exceptions at init.
3. 4x `JMC_tcontainer` created after mission start, not inside `CreateCustomMission`.
4. In-game via COT: locate one container, confirm 26 items (1 elite + 25 normal).
5. Confirm `$profile:Deerisle/DivingLootConfig.json` unchanged (config load still happens in the constructor - only the spawn is deferred).
6. Update the Notion action item with pass/fail.

## Rollback

1. HostHavoc panel: clear `-servermod=`.
2. Restart.

No FinderOuter, DeerIsle, or mission files are touched by this mod - rollback is a launch-parameter edit only.
