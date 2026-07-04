// =====================================================================
// DOG_LoadingScreens - custom loading screens
// Content : tips, tricks, and server info text over operator screenshots.
// Phase   : scaffold only. Populate after inspecting the deobfuscated
//           DUG loadingscreens.pbo for the config pattern and the
//           .edds/.paa format + resolution it uses.
// Assets  : data/ (gitkept empty until screenshot selection is done)
// =====================================================================

class CfgPatches
{
    class DOG_LoadingScreens
    {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] =
        {
            "DOG_Core",
            "DZ_Data"
        };
    };
};

// Loading screen config class goes here once the DUG reference pattern
// is confirmed (CfgLoadingScreens / mission-side cfg varies by approach).
