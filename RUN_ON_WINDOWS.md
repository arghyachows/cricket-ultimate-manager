# Run on Windows Instead of Chrome

## Problem
Chrome blocks Flutter web from connecting to `localhost:3000` or `127.0.0.1:3000` due to browser security policies (CORS/mixed content/network isolation).

## Solution
Run Flutter on Windows desktop instead:

```bash
# Stop Chrome app (Ctrl+C in terminal)

# Run on Windows
flutter run -d windows
```

## Why This Works
- Native Windows app doesn't have browser security restrictions
- Can connect directly to `localhost:3000` or `127.0.0.1:3000`
- Node.js backend will work perfectly

## Verify It's Working
After starting a match on Windows, check logs:
```bash
docker logs cricket-backend --tail 50
```

You should see:
```
📥 POST /api/match/start from ::ffff:127.0.0.1
🔌 Client connected: xyz123
👤 xyz123 joined match: match_id
```

## Alternative: Android
```bash
flutter run -d android
```

Both Windows and Android will successfully connect to Node.js backend.
