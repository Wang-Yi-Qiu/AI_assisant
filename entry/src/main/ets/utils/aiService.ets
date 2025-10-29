// AI service wrapper to call Edge Function generate_chart_qwen

let lastGeneratedConfig: any = null;

export async function generateChart(userData: unknown): Promise<any> {
  const url = getEdgeUrl();
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(userData),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Edge error: ${res.status} ${text}`);
  }
  const config = await res.json();
  lastGeneratedConfig = config;
  // TODO: persist to Supabase charts table (requires auth token)
  // await saveChartRecord(config);
  return config;
}

export function getLastGeneratedConfig(): any {
  return lastGeneratedConfig;
}

function getEdgeUrl(): string {
  // TODO: read from configuration; placeholder for EDGE_GENERATE_CHART_URL
  return 'https://your-project.supabase.co/functions/v1/generate_chart';
}


