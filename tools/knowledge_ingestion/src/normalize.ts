const canonicalNames = new Map<string, string>([
  ["tomato", "tomato"],
  ["solanum lycopersicum", "tomato"],
  ["lycopersicon esculentum", "tomato"],
  ["lycopersicon lycopersicum", "tomato"],
  ["pumpkin", "pumpkin"],
  ["cucurbita pepo", "pumpkin"],
  ["pothos", "pothos"],
  ["golden pothos", "pothos"],
  ["devils ivy", "pothos"],
  ["epipremnum aureum", "pothos"],
  ["scindapsus aureus", "pothos"],
  ["snake plant", "snake_plant"],
  ["mother in laws tongue", "snake_plant"],
  ["dracaena trifasciata", "snake_plant"],
  ["sansevieria trifasciata", "snake_plant"],
  ["peace lily", "peace_lily"],
  ["spathiphyllum wallisii", "peace_lily"],
]);

export function normalizePlantName(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[\u2018\u2019\u02bc]/g, "'")
    .replace(/'/g, "")
    .toLowerCase()
    .trim()
    .replace(/[._,/\\()[\]{}:;!?-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function canonicalPlantKeyFor(value: string): string | undefined {
  return canonicalNames.get(normalizePlantName(value));
}
