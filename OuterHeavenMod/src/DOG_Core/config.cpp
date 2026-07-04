// =====================================================================
// DOG_Core - Outer Heaven mod package base PBO
// Purpose : Root CfgPatches entry + shared script module registration.
//           Every feature PBO in this package lists DOG_Core in its
//           requiredAddons[] to guarantee deterministic load order.
// Owner   : Jeffery / Trendkill - Outer Heaven - Organic RP 1PP
// Created : 2026-07-04 (package scaffold, session 15)
// Notes   : Contains no gameplay content by design. Shared constants,
//           logging helpers, and cross-PBO utilities live here.
// =====================================================================

class CfgPatches
{
    class DOG_Core
    {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] =
        {
            "DZ_Data",
            "DZ_Scripts"
        };
    };
};

class CfgMods
{
    class DOG_Core
    {
        dir = "OuterHeaven";
        name = "Outer Heaven - Core";
        credits = "Jeffery, Trendkill";
        author = "Outer Heaven";
        version = "0.1.0";
        type = "mod";
        dependencies[] = {"Game"};

        class defs
        {
            // Only 3_Game is registered here. Feature PBOs register their
            // own 4_World / 5_Mission paths in their own CfgMods entries -
            // registering a non-existent path causes script compile errors.
            class gameScriptModule
            {
                value = "";
                files[] = {"DOG/Core/scripts/3_Game"};
            };
        };
    };
};
