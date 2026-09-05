# Dataset V3 zero-downtime compatibility bridge

Date: 2026-09-05

## Read-only V2-to-V3 comparison

The comparison used the source-controlled production dataset
`2026-09-03-v2` and the complete candidate promoted in memory to
`2026-09-05-v3`. It did not connect to Firebase. The command is
`npm run candidate:v3:compare` in `tools/knowledge_ingestion`.

The current flat-collection plan would update 65 existing documents, create 14
documents, and leave zero missing or stale IDs. This plan is unsafe for a live
rollout because existing IDs would be overwritten before the complete release
was available.

### Existing IDs that the flat plan would update

All 15 current source IDs:

- `knowledgeSources/illinois_houseplant_care`
- `knowledgeSources/iowa_extreme_heat_garden`
- `knowledgeSources/iowa_houseplant_care`
- `knowledgeSources/kew_cucurbita_pepo`
- `knowledgeSources/mobot_peace_lily`
- `knowledgeSources/mobot_snake_plant`
- `knowledgeSources/ncsu_fertilize_houseplants`
- `knowledgeSources/ncsu_peace_lily`
- `knowledgeSources/ncsu_pothos`
- `knowledgeSources/ncsu_snake_plant`
- `knowledgeSources/ucanr_snake_plant`
- `knowledgeSources/umd_squash_problems`
- `knowledgeSources/umd_tomato_problems`
- `knowledgeSources/umn_growing_tomatoes`
- `knowledgeSources/usu_growing_pumpkins`

All 50 current chunk IDs:

- `knowledgeChunks/peace_lily__cold_stress__cold_and_drafts`
- `knowledgeChunks/peace_lily__identity__species_identity`
- `knowledgeChunks/peace_lily__nutrient_guidance__fertilizer_active_growth_stress_and_repot`
- `knowledgeChunks/peace_lily__nutrient_guidance__low_fertility_needs`
- `knowledgeChunks/peace_lily__pests__mealybugs_and_scale`
- `knowledgeChunks/peace_lily__soil__organic_well_drained_medium`
- `knowledgeChunks/peace_lily__sunlight__filtered_light`
- `knowledgeChunks/peace_lily__toxicity__calcium_oxalate`
- `knowledgeChunks/peace_lily__watering__even_moisture`
- `knowledgeChunks/pothos__humidity__indoor_humidity`
- `knowledgeChunks/pothos__identity__species_identity`
- `knowledgeChunks/pothos__nutrient_guidance__fertilizer_active_growth_interval`
- `knowledgeChunks/pothos__nutrient_guidance__fertilizer_stress_and_repot_wait`
- `knowledgeChunks/pothos__overwatering__root_rot_risk`
- `knowledgeChunks/pothos__pests__mealybugs_and_scale`
- `knowledgeChunks/pothos__soil__well_drained_medium`
- `knowledgeChunks/pothos__sunlight__bright_indirect_light`
- `knowledgeChunks/pothos__toxicity__calcium_oxalate`
- `knowledgeChunks/pothos__watering__dry_between_watering`
- `knowledgeChunks/pumpkin__bacterial_disease__bacterial_wilt_pattern`
- `knowledgeChunks/pumpkin__basic_care__warm_site_and_space`
- `knowledgeChunks/pumpkin__fungal_disease__downy_mildew_pattern`
- `knowledgeChunks/pumpkin__fungal_disease__powdery_mildew_pattern`
- `knowledgeChunks/pumpkin__identity__species_identity`
- `knowledgeChunks/pumpkin__nutrient_guidance__fertilizer_soil_test_and_runners`
- `knowledgeChunks/pumpkin__nutrient_guidance__fertilizer_wait_while_stressed`
- `knowledgeChunks/pumpkin__pests__cucumber_beetle_signs`
- `knowledgeChunks/pumpkin__pests__squash_vine_borer_signs`
- `knowledgeChunks/pumpkin__viral_disease__mosaic_virus_pattern`
- `knowledgeChunks/pumpkin__watering__deep_root_zone_watering`
- `knowledgeChunks/snake_plant__identity__species_identity`
- `knowledgeChunks/snake_plant__nutrient_guidance__fertilizer_stress_and_repot_wait`
- `knowledgeChunks/snake_plant__nutrient_guidance__minimal_fertilizer_active_season`
- `knowledgeChunks/snake_plant__overwatering__root_rot_risk`
- `knowledgeChunks/snake_plant__pests__mealybugs_and_spider_mites`
- `knowledgeChunks/snake_plant__soil__fast_drainage`
- `knowledgeChunks/snake_plant__sunlight__adaptable_indirect_light`
- `knowledgeChunks/snake_plant__temperature__warm_conditions`
- `knowledgeChunks/snake_plant__toxicity__saponins`
- `knowledgeChunks/snake_plant__watering__dry_between_watering`
- `knowledgeChunks/tomato__bacterial_disease__bacterial_spot_pattern`
- `knowledgeChunks/tomato__fungal_disease__early_blight_pattern`
- `knowledgeChunks/tomato__fungal_disease__septoria_leaf_spot`
- `knowledgeChunks/tomato__identity__species_identity`
- `knowledgeChunks/tomato__nutrient_guidance__fertilizer_soil_test_and_fruiting`
- `knowledgeChunks/tomato__nutrient_guidance__fertilizer_wait_while_stressed`
- `knowledgeChunks/tomato__pests__aphid_signs`
- `knowledgeChunks/tomato__sunlight__full_sun_site`
- `knowledgeChunks/tomato__viral_disease__mosaic_virus_pattern`
- `knowledgeChunks/tomato__watering__consistent_deep_watering`

### New IDs in the flat plan

- `knowledgeSources/iowa_container_plant_care`
- `knowledgeSources/iowa_garden_watering_tips`
- `knowledgeSources/maryland_container_vegetables`
- `knowledgeSources/maryland_garden_planning`
- `knowledgeChunks/peace_lily__watering__adaptive_recheck_context`
- `knowledgeChunks/peace_lily__watering__container_drying_modifiers`
- `knowledgeChunks/pothos__watering__adaptive_recheck_context`
- `knowledgeChunks/pothos__watering__container_drying_modifiers`
- `knowledgeChunks/pumpkin__watering__adaptive_recheck_context`
- `knowledgeChunks/pumpkin__watering__container_drying_modifiers`
- `knowledgeChunks/snake_plant__watering__adaptive_recheck_context`
- `knowledgeChunks/snake_plant__watering__container_drying_modifiers`
- `knowledgeChunks/tomato__watering__adaptive_recheck_context`
- `knowledgeChunks/tomato__watering__container_drying_modifiers`

Missing or stale IDs: none.

## Exact V2 dependencies before the bridge

| Area | Exact V2 dependency | Bridge behavior |
| --- | --- | --- |
| Firestore knowledge query | `FirebaseKnowledgeRepository.loadChunksForPlant` filtered `knowledgeChunks.datasetVersion == 2026-09-03-v2` | Existing method stays fixed to V2 for current watering and fertilizer policies. Diagnosis retrieval uses the atomic preferred-evidence method. |
| Knowledge decoder | `KnowledgeVersions.supportedDatasets` accepted historical V1 and V2 | It now accepts V3 knowledge documents as well. |
| Retrieval BLoC | `KnowledgeRetrievalBloc` stamped results with V2 | It now uses the atomically selected evidence-set version. |
| Diagnosis BLoC | `PlantDiagnosisBloc` loaded chunks and sources separately and stamped V2 | It now receives one internally complete evidence set and retains its selected version. |
| Diagnosis service | `FirebaseAiPlantDiagnosisService._validateGrounding` required V2 | It accepts complete, single-version V2 or V3 diagnosis evidence. |
| Saved diagnosis decoder | Dataset text was retained but not checked against the supported set | It now validates and retains historical V1/V2 and compatible V3 versions. |
| Manual watering | `SoilCheckVersions`, `SoilEvidenceValidator`, and `SoilCheckCodec` use V2 | Unchanged; `manual-watering-v1` remains V2-only. |
| Fertilizer | `FertilizerAssessmentVersions`, `FertilizerEvidenceValidator`, and `FertilizerAssessmentCodec` use V2 | Unchanged; `deterministic-fertilizer-v1` remains V2-only. |
| Security Rules | New grounded diagnoses required V2 exactly | New diagnoses accept V2 or V3; historical reads remain owner-readable. Manual watering and fertilizer creation remain V2-only. |
| Knowledge Rules | Only flat `knowledgeChunks` and `knowledgeSources` were readable | Authenticated read-only access now includes the versioned release document and its nested evidence. |

## Compatibility decision

Ingesting V3 into the existing flat collections now would cause the deployed
web app to lose usable evidence. Each updated chunk would stop matching its V2
query. Source documents fetched by stable ID would carry V3 and be rejected by
the deployed decoder. New V3 diagnoses would also be rejected by the deployed
Security Rules. The loss would occur incrementally during ingestion.

The bridge reserves this immutable release layout:

```text
knowledgeDatasets/2026-09-05-v3
knowledgeDatasets/2026-09-05-v3/chunks/{logicalChunkId}
knowledgeDatasets/2026-09-05-v3/sources/{logicalSourceId}
```

The release document is a completion marker written only after all nested
documents have been validated. It must contain schema 1, status `complete`,
dataset version `2026-09-05-v3`, totals of 19 sources and 60 chunks, the exact
per-plant counts 12/13/12/12/11, and a server verification timestamp.

The client prefers V3 only when that marker is exact and the requested plant
slice has its expected count, contains no malformed documents, references only
present sources, and every chunk and source is V3. Otherwise it loads and
validates the complete flat V2 plant slice. It never combines versions. If V2
is also incomplete, retrieval exposes no partial evidence.

## Safe production order

1. Deploy the compatibility Security Rules first. Verify authenticated reads
   and denied client writes on the empty V3 release path, then deploy the web
   application. This order matters because the bridge checks the V3 release
   document before falling back to V2. Do not create the V3 completion marker
   or any V3 evidence during this step.
2. Verify signed-in V2 retrieval, diagnosis creation, historical diagnosis
   display, manual watering, and fertilizer assessment in production. Confirm
   V3 is absent and the app deterministically selects V2.
3. Ingest all 19 sources and 60 chunks into the nested V3 release path. Leave
   flat V2 documents unchanged. Do not write the completion marker yet.
4. Read back and strictly validate every V3 document, its logical ID, version,
   source references, totals, per-plant counts, and idempotent second plan. Only
   after those checks pass, write the completion marker last. Verify the web app
   selects V3 for diagnosis retrieval and still reads historical V2 results.
5. Implement, test, and separately deploy `adaptive-watering-v2`. Its enablement
   must require the same verified complete V3 release. Keep
   `manual-watering-v1` and historical records readable.

No deployment, ingestion, production read, migration, stale deletion, or
production modification was performed while building this bridge.
