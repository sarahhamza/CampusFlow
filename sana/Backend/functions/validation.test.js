const { test } = require("node:test");
const assert = require("node:assert/strict");
const { validateInput, validatePlan } = require("./validation");
const input = { subjects: "Algebra", days: 7, minutes: 60, language: "ar" };
const session = { title: "Recall", course: "Algebra", day: 1, minutes: 30, instructions: "Practice problems" };
test("rejects unsupported languages and unbounded requests", () => {
  for (const change of [{ language: "xx" }, { days: 29 }, { minutes: -1 }, { subjects: "" }, { days: 1.5 }]) assert.throws(() => validateInput({ ...input, ...change }));
});
test("assigns stable unique session IDs and orders days", () => {
  const plan = validatePlan({ summary: "Plan", sessions: [{ ...session, day: 2 }, session] }, input);
  assert.deepEqual(plan.sessions.map(s => s.day), [1, 2]);
  assert.notEqual(plan.sessions[0].id, plan.sessions[1].id);
});
test("rejects excessive daily study and invalid model output", () => {
  for (const sessions of [[session, session, session], [{ ...session, day: 8 }], [{ ...session, minutes: 0 }], []]) assert.throws(() => validatePlan({ summary: "Plan", sessions }, input));
});
