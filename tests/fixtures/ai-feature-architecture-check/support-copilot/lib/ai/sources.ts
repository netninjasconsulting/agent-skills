// Test fixture. The sources retrieval may read, each with its owner.
export const SOURCES = [
  { name: "help-centre-articles", owner: "support-content@example.com" },
  { name: "resolved-tickets", owner: "support-ops@example.com" },
] as const;

export const SOURCE_NAMES = SOURCES.map((source) => source.name);
