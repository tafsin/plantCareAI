export const SCHEMA_VERSION = 1 as const;
export const DATASET_VERSION = "2026-09-03-v2" as const;
export const APPROVED_PROJECT_ID = "plantcare-ai-dev-tasnimalam" as const;

export const CANONICAL_PLANT_KEYS = [
  "tomato",
  "pumpkin",
  "pothos",
  "snake_plant",
  "peace_lily",
] as const;

export const KNOWLEDGE_CATEGORIES = [
  "identity",
  "basic_care",
  "watering",
  "soil",
  "sunlight",
  "temperature",
  "humidity",
  "nutrient_guidance",
  "nutrient_deficiency",
  "fungal_disease",
  "bacterial_disease",
  "viral_disease",
  "pests",
  "overwatering",
  "underwatering",
  "heat_stress",
  "cold_stress",
  "toxicity",
  "prevention",
] as const;

export const ENVIRONMENTS = ["indoor", "outdoor"] as const;
export const AFFECTED_PARTS = [
  "leaf",
  "stem",
  "flower",
  "fruit",
  "root",
  "whole_plant",
  "unknown",
] as const;
export const GROWTH_STAGES = [
  "seedling",
  "vegetative",
  "flowering",
  "fruiting",
  "mature",
] as const;
export const SOURCE_TYPES = [
  "government",
  "university_extension",
  "botanical_garden",
  "peer_reviewed",
  "institutional_horticulture",
] as const;
