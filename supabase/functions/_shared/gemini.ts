// Food photo analysis with Google's Gemini API (Interactions endpoint), the free-tier alternative to Claude.
// Same prompt and the same JSON shape as claude.ts, so parseClaudeFood validates the answer.
import { OUTPUT_SCHEMA, SYSTEM_PROMPT, parseClaudeFood } from "./claude.ts";
import type { CallClaude } from "./analyze.ts";
import type { FetchFn } from "./fdc.ts";

/** A stable Flash model on Gemini's free tier. Override with the GEMINI_MODEL secret. */
export const GEMINI_MODEL = "gemini-3.8-flash";

const ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/interactions";

// The docs don't list `anyOf` with a null branch as supported, so `package` becomes an optional object
// instead of object-or-null; parseClaudeFood already treats a missing package as none.
const { package: pkg, ...otherProps } = OUTPUT_SCHEMA.properties;
export const GEMINI_SCHEMA = {
  ...OUTPUT_SCHEMA,
  properties: { ...otherProps, package: pkg.anyOf.find((s) => s.type === "object")! },
  required: OUTPUT_SCHEMA.required.filter((k) => k !== "package"),
};

type Interaction = {
  status?: string;
  steps?: { type?: string; content?: { type?: string; text?: string }[] }[];
  errors?: { code?: unknown; message?: string }[];
};

/** Thrown like the Anthropic SDK's APIError (status + error.error.type) so the app shows e.g. "(429 RESOURCE_EXHAUSTED)". */
function apiError(status: number, body: string): Error {
  let type: string | undefined;
  let message = body.slice(0, 500);
  try {
    const e = JSON.parse(body)?.error;
    if (typeof e?.status === "string") type = e.status;
    if (typeof e?.message === "string") message = e.message;
  } catch { /* not JSON: keep the raw text */ }
  return Object.assign(new Error(`Gemini ${status}: ${message}`), { status, error: { error: { type } } });
}

export function geminiCaller(apiKey: string, fetchFn: FetchFn, model = GEMINI_MODEL): CallClaude {
  return async (imageB64, mediaType) => {
    const res = await fetchFn(ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        model,
        system_instruction: SYSTEM_PROMPT,
        input: [
          { type: "text", text: "Identify the food in this photo." },
          { type: "image", data: imageB64, mime_type: mediaType },
        ],
        response_format: { type: "text", mime_type: "application/json", schema: GEMINI_SCHEMA },
        generation_config: { thinking_level: "low" },  // a quick look is enough; lower latency
        store: false,  // don't keep the photo or answer on Google's side
      }),
    });
    const text = await res.text();
    if (!res.ok) throw apiError(res.status, text);

    const interaction = JSON.parse(text) as Interaction;
    if (interaction.status !== "completed") {
      const why = interaction.errors?.map((e) => e.message).join("; ") || interaction.status || "no status";
      throw new Error(`Gemini interaction ${why}`);
    }
    const answer = (interaction.steps ?? [])
      .filter((s) => s.type === "model_output")
      .flatMap((s) => s.content ?? [])
      .filter((c) => c.type === "text" && typeof c.text === "string")
      .map((c) => c.text)
      .join("");
    if (!answer) throw new Error("Gemini returned no text");
    return parseClaudeFood(answer);
  };
}
