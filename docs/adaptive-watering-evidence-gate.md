# Adaptive watering guidance: evidence-gate report

Date: 2026-09-05

## 1. Evidence audit

Production dataset `2026-09-03-v2` contains 15 reviewed sources and 50 chunks.
Its plant-specific watering evidence is:

| Plant | Production watering evidence | Related evidence |
| --- | --- | --- |
| Tomato | `tomato__watering__consistent_deep_watering` | `tomato__sunlight__full_sun_site` |
| Pumpkin | `pumpkin__watering__deep_root_zone_watering` | none with a bounded recheck interval |
| Pothos | `pothos__watering__dry_between_watering` | `pothos__soil__well_drained_medium`, `pothos__overwatering__root_rot_risk`, `pothos__sunlight__bright_indirect_light` |
| Snake plant | `snake_plant__watering__dry_between_watering` | `snake_plant__soil__fast_drainage`, `snake_plant__overwatering__root_rot_risk`, `snake_plant__sunlight__adaptable_indirect_light` |
| Peace lily | `peace_lily__watering__even_moisture` | `peace_lily__soil__organic_well_drained_medium`, `peace_lily__sunlight__filtered_light` |

V2 supports all five plants' broad moisture preferences, soil-led decisions,
drainage cautions, and several overwatering risks. Pothos and snake-plant text
names pot size and light among factors that change drying, but gives no
directional or bounded rule. V2 does not adequately support container-versus-
ground modifiers, directional pot-size modifiers, bounded recheck timing, or a
rule connecting current moisture to the latest watering log. Indoor and
outdoor coverage is plant-specific and does not establish a shared timing
policy.

## 2. Evidence-gate decision

The adaptive policy did **not** pass the evidence gate. The requested policy,
persistence, UI, reminders, watering-log integration, DI, and Security Rules
changes were therefore not implemented or enabled. Production V2 remains
unchanged.

A validation-only overlay, `2026-09-05-v3-candidate`, adds four reviewed
university-extension sources and ten paraphrased chunks. The full in-memory
candidate has 19 sources and 60 chunks. It is not reachable from the production
ingestion CLI.

Candidate sources:

- Iowa State University Extension and Outreach, *Care of Plants Growing in Containers*
- University of Maryland Extension, *Growing Vegetables in Containers and Salad Tables*
- Iowa State University Extension and Outreach, *Watering Tips for the Garden, Lawn, and Landscape*
- University of Maryland Extension, *Garden Planning: Growing and Maintaining a Vegetable Garden*

## 3. Candidate decision table

This table records evidence that may support a later pure-Dart policy. It is not
an active decision engine.

| Context | Candidate evidence boundary | Potential structured action |
| --- | --- | --- |
| Current wet or moist soil | Current soil controls; old or missing history cannot prove need | `wait` |
| Current slightly moist soil | Recheck rather than infer a watering need | `check_again` |
| Dry or very dry soil | Apply the existing plant-specific threshold; snake plant retains its more complete dry-down behavior | `water_now` or `check_again` |
| Unsupported plant | No plant-specific interval is justified | `unsupported_plant` |
| Future-dated watering history | Input chronology is invalid | `inconsistent_input` |
| Missing required profile context | Do not guess a modifier | `insufficient_information` |

## 4. Candidate modifier and suggested-date rules

- For indoor houseplants with wet soil, the reviewed source supports checking
  again in one or two days. This is a recheck window, not a watering date.
- For established outdoor garden plants, about every two days is a monitoring
  cadence. Seedlings require closer observation, without an invented interval.
- Outdoor containers should be checked at least daily. Small containers and
  full sun support moving a check earlier within that broad cadence.
- Small pots generally dry faster than large pots. Brighter light tends to
  increase drying. These are directional factors only and cannot replace a new
  soil reading.
- Rainfall, weather, wind, container material, medium, root density, plant size,
  humidity, and temperature remain unobserved or incompletely observed.
- No candidate chunk specifies a watering quantity, clock time, automatic
  watering cadence, or universal schedule.

## 5. Versions

- Active watering policy: `manual-watering-v1` (unchanged)
- Existing soil-check record schema: 1 (unchanged)
- Production knowledge dataset: `2026-09-03-v2` (unchanged)
- Validation-only overlay: `2026-09-05-v3-candidate`
- Proposed promoted dataset after approval and final review: `2026-09-05-v3`

## 6. Architecture changes

Only the standalone TypeScript knowledge-ingestion tool and documentation were
changed. A candidate loader composes V2 with the overlay in memory, applies the
existing strict schema and source-reference validation, and rewrites the
version only after validation. A dedicated CLI performs validation and
in-memory planning with production writes disabled.

No Dart package, application route, dependency injection graph, Firebase
adapter, or cross-package boundary changed for this milestone.

## 7. Persistence and backward compatibility

There are no persistence changes. Historical `manual-watering-v1` records and
existing reminders remain readable and untouched. No Firestore record was
created, updated, deleted, or rewritten.

## 8. Reminder and watering-log behavior

Existing behavior is unchanged. No reminder is created from the candidate and
no care log affects a watering decision. The later policy should treat the
latest watering log as context, reject future chronology, preserve current
moisture as the strongest signal, and require confirmation before reminder
creation.

## 9. Tests and verification

Candidate tests cover full-overlay validation, production-version isolation,
both adaptive evidence claims for every supported plant, complete source
references, bounded recheck wording, no watering schedule, no water quantity,
no exact clock precision, and zero dry-run writes. Exact command results are
reported with the task completion response.

## 10. Awaiting approval

Production ingestion is awaiting explicit user approval. No Security Rules
deployment is needed because the evidence gate stopped the task before any
schema or Rules change.

## 11. Known limitations

- The candidate provides evidence boundaries, not an implemented policy.
- It does not establish safe exact hours, quantities, or universal intervals.
- The application does not observe rainfall or weather.
- Directional pot-size and light modifiers do not capture container material,
  medium, roots, humidity, temperature, wind, or plant size.
- DST conversion, persistence retry, reminder confirmation, and UI behavior
  cannot be tested until the policy milestone is authorized after ingestion.

## 12. Recommended fertilizer-guidance milestone

No fertilizer change is recommended as part of this watering milestone. The
existing `deterministic-fertilizer-v1` and production V2 evidence should remain
unchanged. After adaptive watering is reviewed, ingested, implemented, and
verified, fertilizer work should be limited to a separate evidence-gated UX
review of the existing deterministic assessment and its label-directed safety
language.
