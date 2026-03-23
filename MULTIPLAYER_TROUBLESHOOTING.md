# Multiplayer Backend Troubleshooting Guide

## Issue: Falling Back to Cloudflare

If multiplayer matches are falling back to Cloudflare instead of using the local backend, follow these steps:

### Step 1: Verify Backend is Running

```bash
cd node-backend
npm start
```

Expected output:
```
🚀 Server running on port 3000
📡 WebSocket server ready
🏏 Match engine ready
```

### Step 2: Test Backend Health

```bash
curl http://localhost:3000/health
```

Expected response:
```json
{"status":"ok","timestamp":"2024-..."}
```

### Step 3: Check Redis is Running

```bash
redis-cli ping
```

Expected response:
```
PONG
```

If Redis is not running:
```bash
# Windows (if installed via Chocolatey or MSI)
redis-server

# Or use Docker
docker run -d -p 6379:6379 redis:latest
```

### Step 4: Verify Environment Variables

Check `node-backend/.env` file exists and contains:
```env
PORT=3000
REDIS_URL=redis://localhost:6379
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
```

### Step 5: Test Multiplayer Endpoint

```bash
cd node-backend
node test-multiplayer.js
```

This will test:
- Health check
- Match start
- Match state retrieval
- Match stop
- Active matches list

### Step 6: Check Flutter Logs

When starting a multiplayer match, look for these logs in Flutter console:

```
🚀 Local Backend: Starting multiplayer match <match-id>
📦 Config: {homeTeamId: ..., awayTeamId: ...}
📡 Local Backend response: 200
📄 Response body: {"success":true,"matchId":"..."}
✅ Local Backend success: {success: true, matchId: ...}
```

If you see:
```
❌ Local Backend error: ...
❌ Local backend failed, trying Cloudflare fallback...
```

Then the backend is not reachable.

### Common Issues and Solutions

#### Issue 1: Connection Refused
**Error**: `Connection refused` or `Failed to connect`

**Solution**: 
- Ensure backend is running on port 3000
- Check if another process is using port 3000
- Verify firewall is not blocking localhost connections

#### Issue 2: Timeout
**Error**: `TimeoutException after 10 seconds`

**Solution**:
- Backend might be starting but taking too long
- Check backend logs for errors
- Increase timeout in `local_multiplayer_service.dart` if needed

#### Issue 3: 500 Internal Server Error
**Error**: `Local Backend failed: 500`

**Solution**:
- Check backend logs for detailed error
- Verify Supabase credentials are correct
- Ensure team IDs exist in database
- Check squad_players table has data

#### Issue 4: Missing Team Data
**Error**: `Failed to fetch team data`

**Solution**:
- Verify `homeTeamId` and `awayTeamId` are correct
- Check `squad_players` table has entries for these team IDs
- Ensure `player_cards` table has the referenced players
- Run this query in Supabase SQL editor:
  ```sql
  SELECT sp.*, pc.name, pc.role, pc.batting, pc.bowling, pc.fielding
  FROM squad_players sp
  JOIN player_cards pc ON sp.user_card_id = pc.user_card_id
  WHERE sp.squad_id = 'your-team-id'
  ORDER BY sp.position
  LIMIT 11;
  ```

#### Issue 5: Redis Connection Error
**Error**: `Redis connection failed`

**Solution**:
- Start Redis server
- Check Redis URL in `.env` is correct
- Test Redis connection: `redis-cli ping`

### Step 7: Enable Detailed Logging

Add more logging to backend route:

```javascript
// In routes/multiplayer.js, add at the start of /start endpoint:
logger.info('Received multiplayer start request:', { matchId, config });
```

### Step 8: Check Network Configuration

If using Android emulator:
- Use `http://10.0.2.2:3000` instead of `http://localhost:3000`
- Update `LocalMultiplayerService.baseUrl` in Flutter

If using iOS simulator:
- `http://localhost:3000` should work
- If not, use your machine's IP address

### Step 9: Verify Match Flow

1. Backend receives request
2. Fetches team data from Supabase
3. Creates match engine
4. Starts simulation
5. Updates Supabase database every ball
6. Flutter watches Supabase realtime for updates

Check each step:
```bash
# Backend logs should show:
📥 POST /api/multiplayer/start from ::1
✅ Multiplayer match <match-id> started
🏏 Match <match-id> started
```

### Step 10: Manual Test

Test the endpoint manually:

```bash
curl -X POST http://localhost:3000/api/multiplayer/start \
  -H "Content-Type: application/json" \
  -d '{
    "matchId": "test-123",
    "config": {
      "homeTeamId": "your-home-team-id",
      "awayTeamId": "your-away-team-id",
      "homeTeamName": "Home Team",
      "awayTeamName": "Away Team",
      "matchOvers": 5,
      "matchFormat": "t20",
      "homeBatsFirst": true
    }
  }'
```

Expected response:
```json
{"success":true,"matchId":"test-123"}
```

### Quick Fix Checklist

- [ ] Backend is running (`npm start`)
- [ ] Redis is running (`redis-cli ping`)
- [ ] `.env` file exists with correct values
- [ ] Port 3000 is not blocked
- [ ] Health endpoint works (`curl http://localhost:3000/health`)
- [ ] Team IDs exist in database
- [ ] Squad has at least 11 players
- [ ] Flutter logs show connection attempt
- [ ] Backend logs show request received

### Still Not Working?

1. Stop the backend
2. Clear Redis: `redis-cli FLUSHALL`
3. Restart backend: `npm start`
4. Check backend logs carefully
5. Try the test script: `node test-multiplayer.js`
6. Share backend logs for further debugging
