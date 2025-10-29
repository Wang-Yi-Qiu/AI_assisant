// Deno-style test to validate schemas with sample payloads (no network calls)
// deno-lint-ignore-file no-explicit-any
import { Ajv } from "https://esm.sh/ajv";
import userDataSchema from "../../specs/001-ai-chart-mvp/contracts/schemas/userData.schema.json" assert { type: "json" };
import chartConfigSchema from "../../specs/001-ai-chart-mvp/contracts/schemas/chartConfig.schema.json" assert { type: "json" };

const ajv = new Ajv({ allErrors: true });
const validateIn = ajv.compile(userDataSchema as any);
const validateOut = ajv.compile(chartConfigSchema as any);

Deno.test('contract: valid user data passes input schema', () => {
  const input = [{ x: 'a', y: 1 }];
  if (!validateIn(input)) {
    throw new Error(JSON.stringify(validateIn.errors));
  }
});

Deno.test('contract: valid chart config passes output schema', () => {
  const option = { title: { text: 'ok' }, series: [{ type: 'line', data: [] }] };
  if (!validateOut(option)) {
    throw new Error(JSON.stringify(validateOut.errors));
  }
});

Deno.test('contract: invalid output triggers schema error', () => {
  const bad = { title: { text: 'x' } }; // missing series
  const ok = validateOut(bad);
  if (ok) {
    throw new Error('expected schema to fail for missing series');
  }
});


