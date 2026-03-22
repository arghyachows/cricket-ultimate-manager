import { MatchSimulator } from './durable-object.js';

export { MatchSimulator };

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // Route: POST /api/match/start
      if (url.pathname === '/api/match/start' && request.method === 'POST') {
        const body = await request.json();
        const matchId = body.match_id;

        if (!matchId) {
          return new Response(JSON.stringify({ error: 'match_id required' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        // Get Durable Object instance for this match
        const id = env.MATCH_SIMULATOR.idFromName(matchId);
        const stub = env.MATCH_SIMULATOR.get(id);

        // Forward request to Durable Object
        const doResponse = await stub.fetch(new Request('http://do/start', {
          method: 'POST',
          body: JSON.stringify({ matchId }),
          headers: { 'Content-Type': 'application/json' },
        }));

        const result = await doResponse.json();

        return new Response(JSON.stringify(result), {
          status: doResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Route: GET /api/match/state/:matchId
      if (url.pathname.startsWith('/api/match/state/') && request.method === 'GET') {
        const matchId = url.pathname.split('/').pop();

        if (!matchId) {
          return new Response(JSON.stringify({ error: 'match_id required' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        // Get Durable Object instance
        const id = env.MATCH_SIMULATOR.idFromName(matchId);
        const stub = env.MATCH_SIMULATOR.get(id);

        const doResponse = await stub.fetch(new Request('http://do/state', {
          method: 'GET',
        }));

        const result = await doResponse.json();

        return new Response(JSON.stringify(result), {
          status: doResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Route: POST /api/match/stop/:matchId
      if (url.pathname.startsWith('/api/match/stop/') && request.method === 'POST') {
        const matchId = url.pathname.split('/').pop();

        if (!matchId) {
          return new Response(JSON.stringify({ error: 'match_id required' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        // Get Durable Object instance
        const id = env.MATCH_SIMULATOR.idFromName(matchId);
        const stub = env.MATCH_SIMULATOR.get(id);

        const doResponse = await stub.fetch(new Request('http://do/stop', {
          method: 'POST',
        }));

        const result = await doResponse.json();

        return new Response(JSON.stringify(result), {
          status: doResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Route: POST /api/quick-match/start
      if (url.pathname === '/api/quick-match/start' && request.method === 'POST') {
        const body = await request.json();
        const matchId = body.matchId;

        if (!matchId) {
          return new Response(JSON.stringify({ error: 'matchId required' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        // Use different namespace for quick matches
        const id = env.MATCH_SIMULATOR.idFromName(`quick_${matchId}`);
        const stub = env.MATCH_SIMULATOR.get(id);

        const doResponse = await stub.fetch(new Request('http://do/start-quick', {
          method: 'POST',
          body: JSON.stringify(body),
          headers: { 'Content-Type': 'application/json' },
        }));

        const result = await doResponse.json();

        return new Response(JSON.stringify(result), {
          status: doResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Route: GET /api/quick-match/state/:matchId
      if (url.pathname.startsWith('/api/quick-match/state/') && request.method === 'GET') {
        const matchId = url.pathname.split('/').pop();

        if (!matchId) {
          return new Response(JSON.stringify({ error: 'matchId required' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        const id = env.MATCH_SIMULATOR.idFromName(`quick_${matchId}`);
        const stub = env.MATCH_SIMULATOR.get(id);

        const doResponse = await stub.fetch(new Request('http://do/state', {
          method: 'GET',
        }));

        const result = await doResponse.json();

        return new Response(JSON.stringify(result), {
          status: doResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Route: POST /api/quick-match/stop/:matchId
      if (url.pathname.startsWith('/api/quick-match/stop/') && request.method === 'POST') {
        const matchId = url.pathname.split('/').pop();

        if (!matchId) {
          return new Response(JSON.stringify({ error: 'matchId required' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        const id = env.MATCH_SIMULATOR.idFromName(`quick_${matchId}`);
        const stub = env.MATCH_SIMULATOR.get(id);

        const doResponse = await stub.fetch(new Request('http://do/stop', {
          method: 'POST',
        }));

        const result = await doResponse.json();

        return new Response(JSON.stringify(result), {
          status: doResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Health check
      if (url.pathname === '/health') {
        return new Response(JSON.stringify({ status: 'ok', service: 'cricket-match-simulator' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      return new Response(JSON.stringify({ error: 'Not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });

    } catch (error) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  },
};
