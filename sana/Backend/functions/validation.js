const { randomUUID } = require("node:crypto");
function validateInput(data) {
  if (!data || typeof data.subjects !== "string" || data.subjects.trim().length < 3 || data.subjects.length > 3000 ||
      !Number.isInteger(data.days) || data.days < 1 || data.days > 28 ||
      !Number.isInteger(data.minutes) || data.minutes < 30 || data.minutes > 240 ||
      !["fr", "en", "ar"].includes(data.language)) throw new Error("Invalid input");
  return { subjects: data.subjects.trim(), days: data.days, minutes: data.minutes, language: data.language };
}
function validatePlan(plan, input) {
  const text = (value, max) => typeof value === "string" && value.trim().length > 0 && value.length <= max;
  if (!plan || !text(plan.summary, 3000) || !Array.isArray(plan.sessions) || plan.sessions.length < 1 || plan.sessions.length > input.days * 3) throw new Error("Invalid plan");
  const totals = new Map();
  const counts = new Map();
  const sessions = plan.sessions.map(s => {
    if (!text(s.title, 200) || !text(s.course, 200) || !text(s.instructions, 2000) ||
        !Number.isInteger(s.day) || s.day < 1 || s.day > input.days ||
        !Number.isInteger(s.minutes) || s.minutes < 10 || s.minutes > input.minutes) throw new Error("Invalid session");
    totals.set(s.day, (totals.get(s.day) || 0) + s.minutes);
    counts.set(s.day, (counts.get(s.day) || 0) + 1);
    if (totals.get(s.day) > input.minutes || counts.get(s.day) > 3) throw new Error("Budget exceeded");
    return { id: randomUUID(), title: s.title, course: s.course, instructions: s.instructions, day: s.day, minutes: s.minutes };
  });
  return { summary: plan.summary, sessions: sessions.sort((a, b) => a.day - b.day) };
}
module.exports = { validateInput, validatePlan };
