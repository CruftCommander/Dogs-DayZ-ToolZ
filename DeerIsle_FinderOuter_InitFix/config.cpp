// =============================================================================
// DeerIsle_FinderOuter_InitFix - config.cpp
// Purpose : Server-only hotfix for DeerIsle_FinderOuter init-time NPE.
//           Defers InitializeItemsForSearchManager() out of the MissionServer
//           constructor (fires before mission/weather globals exist, NPEs in
//           vanilla InitTemperature for every Edible_Base item spawned).
// Owner   : Outer Heaven - Organic RP 1PP (Jeffery / Trendkill)
// Created : 2026-07-03
// Deploy  : -servermod=@DeerIsle_FinderOuter_InitFix (server-side only,
//           no client download, no .bisign required)
// Rollback: remove from -servermod=, restart. No third-party files touched.
// =============================================================================

class CfgPatches
{
	class DeerIsle_FinderOuter_InitFix
	{
		units[] = {};
		weapons[] = {};
		requiredVersion = 0.1;
		requiredAddons[] =
		{
			"DZ_Data",
			"DZ_Scripts",
			"deerisle",
			"JMC_DeerIsle_Scripts",
			"DeerIsle_FinderOuter"	// forces load AFTER FinderOuter so our modded MissionServer chains onto theirs
		};
	};
};

class CfgMods
{
	class DeerIsle_FinderOuter_InitFix
	{
		dir = "DeerIsle_FinderOuter_InitFix";
		name = "DeerIsle FinderOuter - Init Timing Fix";
		author = "Outer Heaven";
		type = "mod";
		dependencies[] = {"Game", "World", "Mission"};
		class defs
		{
			class missionScriptModule
			{
				value = "";
				files[] = {"DeerIsle_FinderOuter_InitFix/scripts/5_mission"};
			};
		};
	};
};
