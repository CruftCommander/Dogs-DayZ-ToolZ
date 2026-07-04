# DOG_Seasonings - Design (locked 2026-07-04)

Canonical source of truth: Notion project page action item. This file mirrors it for the repo.

## Locked decisions

- 2-3 seasoning variants: `DOG_Seasoning_Salt`, `DOG_Seasoning_Herbs`, `DOG_Seasoning_Spices` - distinct cure targets.
- Both raw and cooked meat can be seasoned.
- Percentage-based consumption (quantity drain per use, disinfectant-style).
- Salt has TWO actions: light **Season** (small % drain - nutrition + cure roll) and heavy **Cure**
  (large % drain, raw meat only - preservation). Both write seasoning type = salt; Cure also sets a cured flag.

## Architecture

- ONE seasoned classname per meat type (e.g. `DOG_SeasonedChickenBreastMeat : ChickenBreastMeat`).
  Vanilla food stages (RAW/BAKED/BOILED/DRIED) are inherited - seasoning survives cooking because
  the classname never changes.
- Applied-seasoning type stored as a persisted int + cured bool via OnStoreSave/OnStoreLoad
  (versioned). Avoids classname explosion (N meats x 1 instead of N x 2 x 3).
- Cure roll on consumption reads the stored seasoning type against active agents.
- Salt preservation: when seasoning type == SALT and food stage == RAW and cured flag set,
  override the decay/spoilage timer. Life-extension multiplier TBD.
- Visuals: retexture vanilla meat models via hiddenSelections (new .paa only).
  2-3 new .p3d models needed only for the seasoning containers.

## Proposed defaults (pending operator approval)

| Parameter | Default |
|---|---|
| Cure table | salt: cholera + salmonella; herbs: influenza + cold; spices: wound infection |
| Cure chance | 15-25% per consumption |
| Nutrition delta | +10-15% energy/nutritionalIndex vs unseasoned |
| Decay | normal food-stage rates, except salt-cured raw meat (extended, multiplier TBD) |
| Season drain | small (TBD %) |
| Cure drain | large (TBD %) |

## Phases

1. Scaffold (this repo state) - CfgPatches + module registration, builds and loads clean.
2. Config skeleton - uncomment CfgVehicles stubs, placeholder models, verify spawnable via COT.
3. Stored-state scripting - persisted seasoning type + cured flag, decay override.
4. Actions - Season + Cure recipes with distinct prompts and drain amounts.
5. Assets - container .p3d models, meat retexture .paa files.
6. Server integration - types.xml + cfgspawnabletypes entries, deploy, RPT verify.
