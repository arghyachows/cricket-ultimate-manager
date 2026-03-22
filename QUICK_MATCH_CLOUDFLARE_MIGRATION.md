# Quick Match Migration to Cloudflare Durable Objects

## Overview
Quick matches now use Cloudflare Durable Objects for server-side simulation instead of client-side Flutter engine. This provides:
- Consistent simulation across all devices
- Reduced battery/CPU usage on mobile
- Faster simulation (500ms per ball vs 1000ms)
- Centralized match state management
- No cheating possible (client can't manipulate results)

## Architecture

### Before (Client-Side)
```
Flutter App
└── MatchEngine (Dart)
    └── Simulates ball-by-ball locally
    └── Updates local state
    └── Saves to Supabase when complete
```

### After (Server-Side)
```
Flutter App
└── CloudflareQuickMatchService
    └── Calls Cloudflare Worker
        └── Routes to Durable Object
            └── MatchEngine (JavaScript)
                └── Simulates ball-by-ball
                └── Stores state in DO storage
                └── Returns state to Flutter via polling
```

## Files Created/Modified

### New Files
1. **`lib/core/cloudflare_quick_match_service.dart`**
   - Flutter service to communicate with Cloudflare Worker
   - Methods: `startQuickMatch()`, `getMatchState()`, `stopMatch()`

### Modified Files
1. **`cloudflare-worker/src/index.js`**
   - Added `/api/quick-match/start` endpoint
   - Added `/api/quick-match/state/:matchId` endpoint
   - Added `/api/quick-match/stop/:matchId` endpoint
   - Uses `quick_` prefix for DO namespace separation

2. **`cloudflare-worker/src/durable-object.js`**
   - Added `handleStartQuick()` method
   - Added `runSimulationQuick()` method
   - Added `isQuickMatch` flag
   - Quick matches don't update Supabase
   - Faster simulation speed (500ms vs 1000ms per ball)

## API Endpoints

### Start Quick Match
```
POST /api/quick-match/start
Body: {
  "matchId": "unique-match-id",
  "config": {
    "homeXI": [...],
    "awayXI": [...],
    "homeChemistry": 50,
    "awayChemistry": 50,
    "maxOvers": 20,
    "pitchCondition": "balanced",
    "homeTeamName": "Home Team",
    "awayTeamName": "Away Team",
    "homeBatsFirst": true
  }
}

Response: {
  "success": true,
  "matchId": "unique-match-id"
}
```

### Get Match State
```
GET /api/quick-match/state/:matchId

Response: {
  "matchId": "unique-match-id",
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

### Stop Match
```
POST /api/quick-match/stop/:matchId

Response: {
  "success": true
}
```

## Flutter Integration

### Usage Example
```dart
import 'package:cricket_ultimate_manager/core/cloudflare_quick_match_service.dart';

// Start match
final matchId = uuid.v4();
final config = {
  'homeXI': homeTeamPlayers,
  'awayXI': awayTeamPlayers,
  'homeChemistry': 75,
  'awayChemistry': 60,
  'maxOvers': 20,
  'pitchCondition': 'balanced',
  'homeTeamName': 'My Team',
  'awayTeamName': 'Opponent',
  'homeBatsFirst': true,
};

final started = await CloudflareQuickMatchService.startQuickMatch(
  matchId: matchId,
  matchConfig: config,
);

if (started) {
  // Poll for state updates
  Timer.periodic(Duration(seconds: 1), (timer) async {
    final state = await CloudflareQuickMatchService.getMatchState(matchId);
    
    if (state != null) {
      // Update UI with state
      updateMatchUI(state);
      
      if (state['matchComplete'] == true) {
        timer.cancel();
        showMatchResult(state);
      }
    }
  });
}
```

## Key Differences: Quick Match vs Multiplayer Match

| Feature | Quick Match | Multiplayer Match |
|---------|-------------|-------------------|
| Supabase Updates | ❌ No | ✅ Yes |
| Ball Delay | 500ms | 1000ms |
| Rewards | Client-side | Server-side |
| Realtime Sync | Polling | Supabase Realtime |
| DO Namespace | `quick_{matchId}` | `{matchId}` |
| User Count | 1 (solo) | 2 (PvP) |

## Benefits

### Performance
- **50% faster simulation**: 500ms per ball vs 1000ms
- **Reduced mobile battery**: No CPU-intensive simulation on device
- **Consistent speed**: Not affected by device performance

### Security
- **No client manipulation**: Match results can't be tampered with
- **Server-side validation**: All outcomes are server-generated
- **Fair gameplay**: Same engine for all players

### Scalability
- **Durable Objects**: Automatic state persistence
- **Edge computing**: Low latency worldwide
- **Concurrent matches**: Each match in separate DO instance

## Migration Steps for Flutter App

1. **Update match_provider.dart**:
   - Replace local `MatchEngine` simulation
   - Call `CloudflareQuickMatchService.startQuickMatch()`
   - Poll `getMatchState()` every second
   - Update UI with received state

2. **Update environment config**:
   - Add `CLOUDFLARE_WORKER_URL` to environment variables
   - Update `cloudflare_quick_match_service.dart` with actual URL

3. **Handle fallback**:
   - If Cloudflare fails, fall back to local engine
   - Show error message to user
   - Retry logic for network issues

## Testing

### Local Testing
```bash
# Start Cloudflare Worker locally
cd cloudflare-worker
npx wrangler dev

# Test endpoints
curl -X POST http://localhost:8787/api/quick-match/start \
  -H "Content-Type: application/json" \
  -d '{"matchId":"test-123","config":{...}}'

curl http://localhost:8787/api/quick-match/state/test-123
```

### Production Deployment
```bash
# Deploy to Cloudflare
cd cloudflare-worker
npx wrangler deploy

# Update Flutter app with production URL
# Update cloudflare_quick_match_service.dart:
# static const String workerUrl = 'https://cricket-match-sim.YOUR_SUBDOMAIN.workers.dev';
```

## Future Enhancements

1. **WebSocket Support**: Replace polling with WebSocket for real-time updates
2. **Match Replay**: Store full match data for replay functionality
3. **Statistics Tracking**: Aggregate match statistics across all quick matches
4. **AI Difficulty Levels**: Adjust opponent strength based on difficulty setting
5. **Tournament Mode**: Chain multiple quick matches together
