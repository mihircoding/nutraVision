import Anthropic from "npm:@anthropic-ai/sdk@0.137.0";
import { MODEL, OUTPUT_SCHEMA, SYSTEM_PROMPT, parseClaudeFood } from "../_shared/claude.ts";
import { firstSuccessful, handleAnalyzeFood, type CallClaude } from "../_shared/analyze.ts";
import { GEMINI_MODEL, geminiCaller } from "../_shared/gemini.ts";
import { claimScanVia } from "../_shared/quota.ts";

function claudeCaller(apiKey: string): CallClaude {
  const client = new Anthropic({ apiKey });
  return async (data, mediaType) => {
    const res = await client.beta.messages.create({
      model: MODEL, max_tokens: 16000,
      betas: ["server-side-fallback-2026-07-01"], fallbacks: "default",
      output_config: { effort: "low", format: { type: "json_schema", schema: OUTPUT_SCHEMA } },
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: [
        { type: "image", source: { type: "base64", media_type: mediaType, data } },
        { type: "text", text: "Identify the food in this photo." },
      ] }],
    });
    if (res.stop_reason === "refusal") throw new Error("refused");
    const text = res.content.find((b) => b.type === "text");
    return parseClaudeFood(text && "text" in text ? text.text : "");
  };
}

// Claude when an Anthropic key is set, then Gemini (free tier) when a Gemini key is set: either works alone.
// Clients are only built for keys that exist, so a missing key never stops the function from starting.
const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
const geminiKey = Deno.env.get("GEMINI_API_KEY");
const vision = firstSuccessful([
  ...(anthropicKey ? [claudeCaller(anthropicKey)] : []),
  ...(geminiKey ? [geminiCaller(geminiKey, fetch, Deno.env.get("GEMINI_MODEL") || GEMINI_MODEL)] : []),
]);

const claimScan = claimScanVia(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, fetch);
Deno.serve((req) => handleAnalyzeFood(req, { fdcKey: Deno.env.get("FDC_API_KEY") || "DEMO_KEY", fetchFn: fetch, callClaude: vision, claimScan }));
