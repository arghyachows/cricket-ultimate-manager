// Optional AI commentary enhancement - falls back gracefully if unavailable
async function tryAICommentary(
  batsman: string,
  bowler: string,
  eventType: string,
  runs: number,
  fallback: string,
  workerUrl?: string
): Promise<string> {
  if (!workerUrl) return fallback;
  
  try {
    const response = await fetch(workerUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        batsman,
        bowler,
        eventType,
        runs,
        fallback
      }),
    });

    if (!response.ok) return fallback;
    const data = await response.json();
    return data.commentary || fallback;
  } catch {
    return fallback;
  }
}

export { tryAICommentary };
