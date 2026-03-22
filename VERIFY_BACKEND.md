# How to Verify Which Backend Is Running Your Match

## Quick Check

Look for these log messages when starting a match:

### Node.js Backend (✅ What you want)
```
🎯 PRIMARY: Trying Node.js backend first...
🚀 Attempting Node.js backend match simulation...
📝 Match ID: <uuid>
👥 Home XI: 11 players
👥 Away XI: 11 players
⚙️ Config prepared, calling Node.js backend...
✅ Node.js backend match started successfully!
✅ SUCCESS: Using Node.js backend for match simulation
⚡ Ball update received from Node.js
```

### Cloudflare Backend (Fallback)
```
🎯 PRIMARY: Trying Node.js backend first...
❌ Node.js backend match start exception: <error>
⚠️ FALLBACK: Node.js backend failed, trying Cloudflare...
🚀 Attempting Cloudflare match simulation...
✅ Cloudflare match started successfully!
```

## Why Node.js Might Fail on Web

When running `flutter run -d chrome`, the app runs in a browser. The browser enforces CORS (Cross-Origin Resource Sharing) policies.

### Issue
- Flutter web app runs on `http://localhost:<port>` (e.g., `http://localhost:54321`)
- Node.js backend runs on `http://localhost:3000`
- Browser blocks requests between different ports (CORS)

### Solution 1: Update Backend CORS (Recommended)

The backend is already configured with `CORS_ORIGIN=*` which should allow all origins. But let's verify:

```bash
# Check backend logs
cd node-backend
docker-compose logs -f backend
```

Look for CORS errors like:
```
Access to XMLHttpRequest at 'http://localhost:3000/api/match/start' 
from origin 'http://localhost:54321' has been blocked by CORS policy
```

### Solution 2: Run on Mobile/Desktop Instead

Node.js backend works perfectly on:
- ✅ Android (`flutter run -d android`)
- ✅ iOS (`flutter run -d ios`)
- ✅ Windows (`flutter run -d windows`)
- ✅ macOS (`flutter run -d macos`)
- ⚠️ Web (requires CORS configuration)

### Solution 3: Force Node.js Backend

Add this to your Flutter app logs to see the exact error:

In `lib/core/node_backend_service.dart`, the `startMatch` method already logs errors. Check the console for:
```
❌ Node.js match start error: <detailed error>
```

## Test Backend Connection

### From Command Line
```bash
# Test health
curl http://localhost:3000/health

# Test match start
curl -X POST http://localhost:3000/api/match/start \
  -H "Content-Type: application/json" \
  -d '{"matchId":"test","config":{}}'
```

### From Flutter
Run the app and check logs. You should see:
```
🎯 PRIMARY: Trying Node.js backend first...
```

If you see this followed by Cloudflare logs, Node.js failed.

## Current Configuration

In `lib/providers/match_provider.dart`:
```dart
bool _useNodeBackend = true;  // ✅ Enabled
bool _useCloudflare = false;  // Disabled (only fallback)
```

## Recommended: Test on Android

```bash
# Run on Android (no CORS issues)
flutter run -d android

# Or Windows
flutter run -d windows
```

You should see Node.js backend logs instead of Cloudflare logs.

## Verify Backend is Running

```bash
# Check Docker containers
docker ps

# Should show:
# - cricket-backend (port 3000)
# - cricket-redis (port 6379)

# Check backend health
curl http://localhost:3000/health

# Check active matches
curl http://localhost:3000/api/match/active/list
```

## Summary

**If you see Cloudflare logs**: Node.js backend connection failed (likely CORS on web)

**Solution**: Run on Android/Windows instead of Chrome:
```bash
flutter run -d windows
# or
flutter run -d android
```

This will use Node.js backend successfully! 🚀
