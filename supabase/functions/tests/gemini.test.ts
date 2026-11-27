import { test } from "node:test";
import assert from "node:assert/strict";
import { GEMINI_MODEL, geminiCaller } from "../_shared/gemini.ts";
import { firstSuccessful } from "../_shared/analyze.ts";
import type { ClaudeFood } from "../_shared/claude.ts";

const est = { kcal: 200, protein_g: 4, carbs_g: 44, fat_g: 0.4, sat_fat_g: 0.1, sodium_mg: 2, fiber_g: 0.6, sugar_g: 0 };
const answer = {
  is_food: true, notes: "A bowl of rice.",
  items: [{ name: "Rice", fdc_query: "Rice, white, cooked", grams: 180, cooking_method: "boiled", confidence: "high", estimate: est }],
};

/** Captures the one request and answers with `body` (an Interactions resource) or an error. */
function capture(body: unknown, status = 200) {
  const seen: { url?: string; init?: RequestInit } = {};
  const fetchFn = (async (url: string | URL | Request, init?: RequestInit) => {
    seen.url = String(url);
    seen.init = init;
    return new Response(JSON.stringify(body), { status });
  }) as typeof fetch;
  return { seen, fetchFn };
}

const interaction = (text: string, status = "completed") => ({
  id: "v1_x", status, created: "", updated: "",
  steps: [
    { type: "thought", content: [] },
    { type: "model_output", content: [{ type: "text", text }] },
  ],
});

test("gemini: sends the photo, schema and key; parses the model's JSON", async () => {
  const { seen, fetchFn } = capture(interaction(JSON.stringify(answer)));
  const food = await geminiCaller("test-key", fetchFn)("QUJD", "image/jpeg");

  assert.equal(food.is_food, true);
  assert.equal(food.items[0].name, "Rice");
  assert.equal(food.items[0].grams, 180);
  assert.equal(food.package, null);  // optional for Gemini; absent means none

  assert.equal(seen.url, "https://generativelanguage.googleapis.com/v1beta/interactions");
  const headers = seen.init!.headers as Record<string, string>;
  assert.equal(headers["x-goog-api-key"], "test-key");
  const body = JSON.parse(String(seen.init!.body));
  assert.equal(body.model, GEMINI_MODEL);
  assert.equal(body.store, false);  // photos are not kept on Google's side
  assert.ok(typeof body.system_instruction === "string" && body.system_instruction.length > 50);
  assert.deepEqual(body.input[1], { type: "image", data: "QUJD", mime_type: "image/jpeg" });
  assert.equal(body.response_format.mime_type, "application/json");
  // No anyOf/null union (not documented as supported): package is an optional object instead.
  assert.equal(JSON.stringify(body.response_format.schema).includes("anyOf"), false);
  assert.equal(body.response_format.schema.required.includes("package"), false);
});

test("gemini: an API error keeps its HTTP status and Google status for the app's message", async () => {
  const { fetchFn } = capture({ error: { code: 429, message: "Quota exceeded", status: "RESOURCE_EXHAUSTED" } }, 429);
  await assert.rejects(geminiCaller("k", fetchFn)("QUJD", "image/jpeg"), (e: unknown) => {
    const err = e as { status?: number; error?: { error?: { type?: string } } };
    return err.status === 429 && err.error?.error?.type === "RESOURCE_EXHAUSTED";
  });
});

test("gemini: an unfinished or empty interaction is an error, not an empty result", async () => {
  await assert.rejects(geminiCaller("k", capture(interaction("{}", "failed")).fetchFn)("QUJD", "image/jpeg"));
  await assert.rejects(geminiCaller("k", capture({ id: "x", status: "completed", steps: [] }).fetchFn)("QUJD", "image/jpeg"));
});

test("firstSuccessful: tries each model in order and reports the last failure", async () => {
  const ok: ClaudeFood = { is_food: false, notes: "", package: null, items: [] };
  const fail = (msg: string) => async () => { throw new Error(msg); };
  let calls = 0;
  const counted = async () => { calls++; return ok; };

  assert.equal(await firstSuccessful([fail("no credit"), counted])("A", "image/jpeg"), ok);
  assert.equal(calls, 1);
  await assert.rejects(firstSuccessful([fail("first"), fail("second")])("A", "image/jpeg"), /second/);
  await assert.rejects(firstSuccessful([])("A", "image/jpeg"), /No AI key/);
});
