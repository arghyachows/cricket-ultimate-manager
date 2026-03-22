# Cricket Match Simulator - Cloudflare Durable Objects

Stateful multiplayer cricket match simulation using Cloudflare Durable Objects.

## Architecture

- **Worker**: Routes requests to Durable Objects
- **Durable Object**: Maintains match state, runs simulation engine
- **Match Engine**: Ball-by-ball cricket simulation with realistic probabilities
- **Supabase Integration**: Syncs match state to database for real-time Flutter updates

## Features

- ✅ Stateful match simulation (survives restarts)
- ✅ Ball-by-ball updates to Supabase
- ✅ Realistic cricket mechanics (batting/bowling ratings, pitch conditions, match phases)
- ✅ Automatic rewards distribution
- ✅ Concurrent match support (one Durable Object per match)

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

Set your Supabase credentials:

```bash
wrangler secret put SUPABASE_URL
# Enter: https://your-project.supabase.co

wrangler secret put SUPABASE_SERVICE_KEY
# Enter: your-service-role-key
```

Or update `wrangler.toml` with your values (not recommended for production).

### 3. Deploy to Cloudflare

```bash
npm run deploy
```

This will:
- Deploy the Worker to Cloudflare's edge network
- Create the Durable Object class
- Generate a Worker URL (e.g., `https://cricket-match-simulator.your-subdomain.workers.dev`)

## API Endpoints

### Start Match Simulation

```bash
POST /api/match/start
Content-Type: application/json

{
  "match_id": "uuid-of-match"
}
```

**Response:**
```json
{
  "success": true,
  "matchId": "uuid-of-match"
}
```

### Get Match State

```bash
GET /api/match/state/{matchId}
```

**Response:**
```json
{
  "matchId": "uuid",
  "isSimulating": true,
  "matchComplete": false,
  "innings": 1,
  "score1": 45,
  "wickets1": 2,
  "score2": 0,
  "wickets2": 0,
  "overNumber": 7,
  "ballNumber": 3,
  "target": 0,
  "batsmanStats": {...},
  "bowlerStats": {...},
  "commentaryLog": [...]
}
```

### Stop Match Simulation

```bash
POST /api/match/stop/{matchId}
```

## Flutter Integration

Update your Flutter app to call the Cloudflare Worker instead of Supabase Edge Function:

```dart
// In multiplayer_match_screen.dart

void _invokeServerSimulation() {
  final workerUrl = 'https://cricket-match-simulator.your-subdomain.workers.dev';
  
  http.post(
    Uri.parse('$workerUrl/api/match/start'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'match_id': widget.matchId}),
  ).then((response) {
    print('Worker response: ${response.statusCode}');
    if (response.statusCode >= 400) {
      print('Worker error: ${response.body}');
    }
  }).catchError((e) {
    print('Worker invocation error: $e');
  });
}
```

The Flutter app continues to subscribe to Supabase realtime for live updates - no changes needed there!

## How It Works

1. **Flutter** calls `/api/match/start` with match ID
2. **Worker** creates/fetches Durable Object for that match ID
3. **Durable Object**:
   - Loads match data from Supabase
   - Initializes MatchEngine with teams
   - Runs ball-by-ball simulation
   - Updates Supabase after each ball
   - Persists state to Durable Object storage
4. **Flutter** receives updates via Supabase realtime subscription
5. **Durable Object** completes match, awards rewards, marks as completed

## Development

Run locally:

```bash
npm run dev
```

This starts a local development server with hot reload.

## Monitoring

View logs in Cloudflare dashboard:
- Go to Workers & Pages
- Select `cricket-match-simulator`
- Click "Logs" tab

## Cost Estimation

Cloudflare Durable Objects pricing:
- **Requests**: $0.15 per million requests
- **Duration**: $12.50 per million GB-seconds
- **Storage**: $0.20 per GB-month

Typical 20-over match:
- ~240 balls × 1 second = 240 seconds
- ~240 Supabase updates
- Storage: <1 MB per match

**Estimated cost per match**: <$0.001

## Troubleshooting

### Match stuck in "in_progress"

Check Durable Object logs for errors. Restart simulation:

```bash
curl -X POST https://your-worker.workers.dev/api/match/stop/{matchId}
curl -X POST https://your-worker.workers.dev/api/match/start \
  -H "Content-Type: application/json" \
  -d '{"match_id": "{matchId}"}'
```

### Supabase updates not working

Verify environment variables:

```bash
wrangler secret list
```

Should show `SUPABASE_URL` and `SUPABASE_SERVICE_KEY`.

## Migration from Supabase Edge Functions

1. Deploy this Worker
2. Update Flutter to call Worker URL instead of `SupabaseService.client.functions.invoke('simulate-multiplayer')`
3. Keep Supabase realtime subscription unchanged
4. Optionally delete old Edge Function

## License

MIT
