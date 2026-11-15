// Test fixture. Nothing in CI runs this.
import cases from "./cases.json";
import { buildDraftPrompt } from "../lib/ai/prompt";
import { draftReply } from "../lib/ai/draft";

let passed = 0;
for (const testCase of cases) {
  const prompt = buildDraftPrompt(testCase.customer, testCase.ticket, []);
  const draft = await draftReply(`eval-${testCase.id}`, prompt, []);
  if (testCase.mustMention.every((phrase: string) => draft.includes(phrase))) passed += 1;
}
console.log(`${passed} of ${cases.length} cases passed`);
