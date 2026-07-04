// =====================================================================
// DOG_Seasonings - seasoning items + seasoned meat system
// Design  : docs/seasonings-design.md (canonical spec in Notion)
// Phase   : 1 (scaffold) - CfgPatches + script module registration only.
//           Phase 2 uncomment/expand the CfgVehicles stubs below.
// Depends : DOG_Core (load order), DZ_Data, DZ_Scripts
// =====================================================================

class CfgPatches
{
    class DOG_Seasonings
    {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] =
        {
            "DOG_Core",
            "DZ_Data",
            "DZ_Scripts"
        };
    };
};

class CfgMods
{
    class DOG_Seasonings
    {
        dir = "OuterHeaven";
        name = "Outer Heaven - Seasonings";
        author = "Outer Heaven";
        version = "0.1.0";
        type = "mod";
        dependencies[] = {"World"};

        class defs
        {
            class worldScriptModule
            {
                value = "";
                files[] = {"DOG/Seasonings/scripts/4_World"};
            };
        };
    };
};

// =====================================================================
// PHASE 2 STUBS - uncomment and complete when item work begins.
// Placeholder models keep scripting unblocked until real .p3d assets
// exist (Phase 5 swaps model= paths and adds hiddenSelections).
// =====================================================================
/*
class CfgVehicles
{
    class Edible_Base;

    // ---- Seasoning containers (percentage-based, disinfectant-style drain)
    class DOG_Seasoning_Base : Edible_Base
    {
        scope = 0;
        displayName = "Seasoning";
        descriptionShort = "A container of seasoning.";
        model = "\dz\gear\consumables\Marmalade.p3d";   // PLACEHOLDER - replace in Phase 5
        weight = 200;
        itemSize[] = {1,2};
        varQuantityInit = 100;
        varQuantityMin = 0;
        varQuantityMax = 100;
        varQuantityDestroyOnMin = 1;
        stackedUnit = "percentage";
    };

    class DOG_Seasoning_Salt   : DOG_Seasoning_Base { scope = 2; displayName = "Salt"; };
    class DOG_Seasoning_Herbs  : DOG_Seasoning_Base { scope = 2; displayName = "Dried Herbs"; };
    class DOG_Seasoning_Spices : DOG_Seasoning_Base { scope = 2; displayName = "Spice Mix"; };

    // ---- Seasoned meat pattern (ONE class per meat; food stages inherited,
    //      seasoning type + cured flag persisted in script, see 4_World)
    // class ChickenBreastMeat;
    // class DOG_SeasonedChickenBreastMeat : ChickenBreastMeat
    // {
    //     scope = 2;
    //     displayName = "Seasoned Chicken Breast";
    //     // hiddenSelectionsTextures[] = {"DOG\Seasonings\data\chicken_seasoned_co.paa"}; // Phase 5
    // };
};
*/
