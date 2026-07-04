// =====================================================================
// Placeholder so the registered 4_World module compiles non-empty.
// Phase 3 replaces this with:
//   - modded meat base storing m_DOG_SeasoningType (int) and
//     m_DOG_Cured (bool) via OnStoreSave/OnStoreLoad (versioned)
//   - decay override when SeasoningType == SALT && FoodStage == RAW && Cured
//   - consumption hook rolling cure chance against active agents
// Phase 4 adds the Season (light drain) and Cure (heavy drain) actions.
// =====================================================================

class DOG_SeasoningsModuleMarker
{
    static const string MODULE = "DOG_Seasonings";
}
