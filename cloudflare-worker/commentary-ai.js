export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      });
    }

    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    try {
      const { context } = await request.json();

      const prompt = `You are a cricket commentator. Generate exciting, realistic cricket commentary for the following match situation:

Match Context:
- Batting Team: ${context.battingTeam}
- Bowling Team: ${context.bowlingTeam}
- Batsman: ${context.batsman}
- Bowler: ${context.bowler}
- Event: ${context.eventType}
- Runs: ${context.runs}
- Current Score: ${context.battingTeam} ${context.score}/${context.wickets}
- Overs: ${context.overs}
- Match Phase: ${context.phase}
${context.wicketType ? `- Wicket Type: ${context.wicketType}` : ''}
${context.fielder ? `- Fielder: ${context.fielder}` : ''}

Generate a single line of exciting commentary (max 150 characters). Be dramatic for boundaries and wickets, analytical for dots.`;

      const response = await env.AI.run('@cf/meta/llama-3.1-8b-instruct-fast', {
        prompt: `Cricket commentary for: ${context.batsman} vs ${context.bowler}, ${context.eventType}, ${context.runs} runs. Reply in 10 words max:`,
        max_tokens: 25,
      });

      const commentary = response.response?.trim() || context.fallbackCommentary;

      return new Response(JSON.stringify({ commentary }), {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    } catch (error) {
      return new Response(JSON.stringify({ 
        error: error.message,
        commentary: null 
      }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }
  },
};
