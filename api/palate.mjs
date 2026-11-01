const schema = {
  type: "object",
  additionalProperties: false,
  required: ["identity", "summary", "story", "sensory", "tastingPrompts", "preparation", "personalization", "discovery", "caveats"],
  properties: {
    identity: { type: "object", additionalProperties: false, required: ["snapshot", "confidence", "evidence"], properties: { snapshot: { type: "string" }, confidence: { type: "integer" }, evidence: { type: "string" } } },
    summary: { type: "string" },
    story: { type: "string" },
    sensory: { type: "array", items: { type: "object", additionalProperties: false, required: ["name", "notes", "basis"], properties: { name: { type: "string" }, notes: { type: "array", items: { type: "string" } }, basis: { type: "string" } } } },
    tastingPrompts: { type: "array", items: { type: "string" } },
    preparation: { type: "array", items: { type: "string" } },
    personalization: { type: "string" },
    discovery: { type: "string" },
    caveats: { type: "array", items: { type: "string" } }
  }
};

const labelSchema = {
  type: "object",
  additionalProperties: false,
  required: ["fields", "caveats"],
  properties: {
    fields: { type: "array", items: { type: "object", additionalProperties: false, required: ["label", "value", "confidence", "basis"], properties: { label: { type: "string" }, value: { type: "string" }, confidence: { type: "integer" }, basis: { type: "string" } } } },
    caveats: { type: "array", items: { type: "string" } }
  }
};

const instructions = `You are Palate, an expert, warm sommelier and specialty coffee educator.
Build a concise but insightful profile from the supplied, user-confirmed product data, recent tasting history, and optional label image.

Rules:
- Treat user-supplied product fields as label-derived, not independently verified facts.
- Do not invent product facts, price, producer history, origin, vintage, roast date, processing, published notes, or user preferences. If absent or uncertain, say so plainly in caveats.
- Identity confidence reflects how confidently the supplied data and image identify the exact product. Evidence must say label-derived, image-supported, or uncertain; do not claim web verification.
- Distinguish published/label notes from sensory inference in each sensory group's basis.
- Personalization may only discuss concrete signals from recentTastings. With no useful history, return an empty string.
- Give coffee a practical starting recipe only when sufficient method/equipment data exists; otherwise give a conditional starting range and explain how taste and drawdown should change grind direction.
- Give wine practical service guidance only when it is warranted by the provided style clues; otherwise phrase as a general starting point.
- Never imply there is one correct tasting answer. Prompts should invite observation.
- Do not make health claims or encourage alcohol consumption.
- Keep all arrays short, practical, and legible in a mobile interface.`;

function send(res, status, body) {
  res.status(status).setHeader("Content-Type", "application/json").send(JSON.stringify(body));
}

function outputText(response) {
  if (typeof response.output_text === "string") return response.output_text;
  return (response.output || [])
    .filter((item) => item.type === "message")
    .flatMap((item) => item.content || [])
    .filter((item) => item.type === "output_text" && typeof item.text === "string")
    .map((item) => item.text)
    .join("");
}

export default async function handler(req, res) {
  if (req.method !== "POST") return send(res, 405, { error: "Use POST." });
  if (!process.env.OPENAI_API_KEY) return send(res, 500, { error: "Palate Intelligence is not configured." });

  const input = req.body;
  if (input?.mode === "enrich_label") return enrichLabel(input, res);
  if (!input?.category || !input?.productName || !input?.producer) return send(res, 400, { error: "A category, product name, and producer are required." });
  if (input.labelImageBase64 && input.labelImageBase64.length > 9_000_000) return send(res, 413, { error: "The label image is too large. Please use a smaller photo." });

  const context = { ...input, labelImageBase64: undefined };
  const content = [{ type: "input_text", text: `Create a Palate profile from this JSON:\n${JSON.stringify(context)}` }];
  if (input.labelImageBase64) content.push({ type: "input_image", image_url: `data:image/jpeg;base64,${input.labelImageBase64}` });

  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
      body: JSON.stringify({
        model: process.env.PALATE_MODEL || "gpt-6-luna",
        instructions,
        input: [{ role: "user", content }],
        text: { format: { type: "json_schema", name: "palate_profile", strict: true, schema } }
      })
    });
    const result = await response.json();
    if (!response.ok) return send(res, response.status, { error: result?.error?.message || "Profile generation failed." });
    const profile = JSON.parse(outputText(result));
    return send(res, 200, profile);
  } catch (error) {
    return send(res, 502, { error: "Palate Intelligence could not generate a profile. Please try again." });
  }
}

async function enrichLabel(input, res) {
  if (!input.category || !input.labelImageBase64) return send(res, 400, { error: "A label image and category are required." });
  if (input.labelImageBase64.length > 9_000_000) return send(res, 413, { error: "The label image is too large. Please use a smaller photo." });
  const fields = input.category === "coffee"
    ? ["Roaster", "Coffee name", "Origin", "Process", "Roast date"]
    : input.category === "wine"
      ? ["Producer", "Wine name", "Vintage", "Grape", "Region"]
      : ["Distillery", "Expression", "Age statement", "Region", "Cask", "ABV"];
  const instructions = `Extract only legible, image-supported label data for a ${input.category}. Return zero or more of exactly these field labels: ${fields.join(", ")}.
Do not infer or complete missing text. Confidence is 0-100 and basis briefly explains whether it came from visible label text or OCR support. Return caveats for ambiguity.`;
  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
      body: JSON.stringify({
        model: process.env.PALATE_MODEL || "gpt-6-luna",
        instructions,
        input: [{ role: "user", content: [
          { type: "input_text", text: `OCR text (may be noisy):\n${(input.recognizedLines || []).join("\n")}` },
          { type: "input_image", image_url: `data:image/jpeg;base64,${input.labelImageBase64}` }
        ] }],
        text: { format: { type: "json_schema", name: "label_enrichment", strict: true, schema: labelSchema } }
      })
    });
    const result = await response.json();
    if (!response.ok) return send(res, response.status, { error: result?.error?.message || "Label enrichment failed." });
    return send(res, 200, JSON.parse(outputText(result)));
  } catch {
    return send(res, 502, { error: "Palate Intelligence could not enhance this label. Please try again." });
  }
}
