# Multiplayer Match Local Backend Integration

## Overview
Multiplayer matches now use the local Node.js backend for match simulation, similar to quick matches. This provides better control, debugging capabilities, and eliminates dependency on Cloudflare Workers for multiplayer matches.

## Changes Made

### 1. New Service: `local_multiplayer_service.dart`
Created a new service to communicate with the local Node.js backend for multiplayer matches.

**Location**: `lib/core/local_multiplayer_service.dart`

**Features**:
- Start multiplayer match simulation
- Get match state
- Stop running matches
- Connects to `http://localhost:3000`

### 2. Updated `multiplayer_match_screen.dart`
Modified the `_invokeServerSimulation()` method to:
- Call local backend first
- Fallback to Cloudflare Workers if local backend fails
- Pass match configuration including team IDs and match settings

### 3. Enhanced Backend Route: `routes/multiplayer.js`
Updated the `/api/multiplayer/start` endpoint to:
- Fetch team data from Supabase using team IDs
- Transform squad data to match engine format
- Calculate team chemistry
- Start match simulation with proper configuration

**Key Features**:
- Fetches squad players and player cards from Supabase
- Transforms data to match engine format (homeXI, awayXI)
- Supports configurable match overs and formats
- Runs simulation in background with error handling

## Architecture Flow

```
Flutter App (multiplayer_match_screen.dart)
    ↓
    ↓ HTTP POST /api/multiplayer/start
    ↓
Node.js Backend (routes/multiplayer.js)
    ↓
    ↓ Fetch team data
    ↓
Supabase (squad_players, player_cards)
    ↓
    ↓ Transform & configure
    ↓
Match Engine (services/matchEngine.js)
    ↓
    ↓ Ball-by-ball simulation
    ↓
Socket.IO + Supabase Realtime
    ↓
    ↓ Live updates
    ↓
Flutter App (watches Supabase realtime)
```

## Configuration Required

### Backend `.env` file
Ensure these variables are set:
```env
PORT=3000
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
REDIS_URL=redis://localhost:6379
```

### Flutter Service
The service connects to `http://localhost:3000` by default. Update `LocalMultiplayerService.baseUrl` if your backend runs on a different port.

## Usage

### Starting a Multiplayer Match

1. User initiates match from Flutter app
2. Toss is completed and decision is made
3. `_invokeServerSimulation()` is called with match configuration:
   ```dart
   final config = {
     'homeTeamId': data['home_team_id'],
     'awayTeamId': data['away_team_id'],
     'homeTeamName': _state.homeTeamName,
     'awayTeamName': _state.awayTeamName,
     'matchOvers': _state.matchOvers,
     'matchFormat': _state.matchFormat,
     'homeBatsFirst': _state.homeBatsFirst,
   };
   ```
4. Backend fetches team data and starts simulation
5. Both users watch live updates via Supabase realtime

### Monitoring Active Matches

Check active matches:
```bash
curl http://localhost:3000/api/multiplayer/active/list
```

Get match state:
```bash
curl http://localhost:3000/api/multiplayer/{matchId}
```

Stop a match:
```bash
curl -X POST http://localhost:3000/api/multiplayer/stop \
  -H "Content-Type: application/json" \
  -d '{"matchId": "your-match-id"}'
```

## Benefits

1. **Better Debugging**: Full access to logs and state
2. **No External Dependencies**: Works without Cloudflare Workers
3. **Consistent Architecture**: Same pattern as quick matches
4. **Real-time Updates**: Both users see live ball-by-ball updates
5. **Fallback Support**: Still falls back to Cloudflare if local backend unavailable

## Testing

1. Start the backend:
   ```bash
   cd node-backend
   npm start
   ```

2. Start Redis (required for state management):
   ```bash
   redis-server
   ```

3. Run the Flutter app and initiate a multiplayer match

4. Monitor backend logs for simulation progress

## Troubleshooting

### Backend not starting match
- Check backend logs for errors
- Verify Supabase credentials in `.env`
- Ensure Redis is running (`redis-cli ping`)
- Verify team IDs exist in database
- Run test script: `node test-multiplayer.js`

### Quick Start
```bash
cd node-backend

# Windows
start-backend.bat

# Manual start
redis-server  # In separate terminal
npm start
```

### Verify Backend is Working
```bash
# Test health
curl http://localhost:3000/health

# Test multiplayer endpoint
node test-multiplayer.js
```

### Check Flutter Logs
Look for these messages:
```
🚀 Local Backend: Starting multiplayer match <id>
📦 Config: {...}
📡 Local Backend response: 200
✅ Local Backend success
```

If you see `❌ Local backend failed, trying Cloudflare fallback...`, see [MULTIPLAYER_TROUBLESHOOTING.md](MULTIPLAYER_TROUBLESHOOTING.md) for detailed debugging steps.

### No live updates in Flutter
- Check Supabase realtime subscription
- Verify match ID is correct
- Check network connectivity

### Match simulation errors
- Check player data completeness (batting, bowling, fielding stats)
- Verify squad has at least 11 players
- Check backend logs for detailed error messages

## Future Enhancements

- [ ] Add WebSocket direct connection for even faster updates
- [ ] Implement match pause/resume functionality
- [ ] Add spectator mode for non-participants
- [ ] Support tournament brackets with multiple matches
- [ ] Add match replay functionality
