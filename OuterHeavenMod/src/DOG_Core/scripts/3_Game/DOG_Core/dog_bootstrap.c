// =====================================================================
// dog_bootstrap.c - one-line startup banner
// Purpose: prints the package version into the RPT at script compile /
// game init so every deploy is verifiable from the log alone, matching
// the existing "RPT is ground truth" verification workflow.
// =====================================================================

modded class DayZGame
{
    void DayZGame()
    {
        Print("[DOG] Outer Heaven package loaded - version " + DOG_Constants.PACKAGE_VERSION);
    }
}
