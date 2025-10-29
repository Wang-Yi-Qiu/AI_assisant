// HomePage: upload or paste data and trigger chart generation

import { generateChart } from '../utils/aiService';

export async function onGenerateFromText(text: string): Promise<any> {
  const data = parseUserInput(text);
  return await generateChart(data);
}

function parseUserInput(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}


