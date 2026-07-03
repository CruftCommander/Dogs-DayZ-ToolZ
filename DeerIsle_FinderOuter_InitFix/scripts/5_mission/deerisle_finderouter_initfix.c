// =============================================================================
// DeerIsle_FinderOuter_InitFix - deerisle_finderouter_initfix.c
// Purpose : DeerIsle_FinderOuter calls InitializeItemsForSearchManager()
//           synchronously from the MissionServer constructor - before
//           CreateCustomMission() returns and before GetGame().GetMission()
//           / weather globals exist. Every Edible_Base item it spawns
//           (Rice, SpaghettiCan, BakedBeansCan, SardinesCan, TunaCan) throws
//           "NULL pointer to instance" in vanilla InitTemperature.
//           This override defers the spawn to OnMissionStart, after vanilla
//           mission init completes. Loot outcome is identical - same
//           containers, same config, same counts - just later in boot.
// Owner   : Outer Heaven - Organic RP 1PP
// Created : 2026-07-03
// Depends : DeerIsle_FinderOuter (requiredAddons enforces load order)
// Verify  : next RPT - zero InitTemperature NPEs at init; no compile errors
//           referencing this PBO; 4x JMC_tcontainer created post-mission-start.
// Rollback: remove @DeerIsle_FinderOuter_InitFix from -servermod=, restart.
// =============================================================================

modded class MissionServer
{
	protected bool m_InitFix_SpawnPending;

	// FinderOuter's constructor calls this. Swallow the call, mark pending.
	override void InitializeItemsForSearchManager()
	{
		m_InitFix_SpawnPending = true;
	}

	// Engine-invoked after mission construction completes - mission/weather
	// globals are available here.
	// UNVERIFIED assumption: OnMissionStart() exists on vanilla MissionServer
	// in 1.29. If the RPT shows a compile error on this override at boot,
	// use the CallLater fallback below instead.
	override void OnMissionStart()
	{
		super.OnMissionStart();

		if (m_InitFix_SpawnPending)
		{
			m_InitFix_SpawnPending = false;
			super.InitializeItemsForSearchManager();
		}
	}
};

// -----------------------------------------------------------------------------
// FALLBACK VARIANT - use only if the OnMissionStart override above fails to
// compile (RPT SCRIPT (E) referencing this file at boot). Replace the entire
// modded class above with this version, repack, redeploy. The 5000ms delay is
// empirical, not derived from a vanilla readiness signal - validate via RPT.
// -----------------------------------------------------------------------------
/*
modded class MissionServer
{
	override void InitializeItemsForSearchManager()
	{
		GetGame().GetCallQueue(CALL_CATEGORY_GAMEPLAY).CallLater(InitFix_DeferredSpawn, 5000, false);
	}

	void InitFix_DeferredSpawn()
	{
		super.InitializeItemsForSearchManager();
	}
};
*/
