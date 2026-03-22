# Quick Deployment Guide

## 🚀 Deploy in 5 Minutes

### Step 1: Deploy Cloudflare Worker
```bash
cd d:\Vibe\cricket-ultimate-manager\cloudflare-worker
npx wrangler deploy
```

**Expected Output:**
```
✨ Successfully published your script to
 https://cricket-match-sim.YOUR_SUBDOMAIN.workers.dev
```

### Step 2: Update Flutter Configuration
Edit `lib/core/cloudflare_quick_match_service.dart`:
```dart
// Line 5: Replace with your deployed URL
static const String workerUrl = 'https://cricket-match-sim.YOUR_SUBDOMAIN.workers.dev';
```

### Step 3: Test
```bash
# Run Flutter app
flutter run -d chrome

# Start a quick match and watch console for:
# "Using Cloudflare Durable Objects for match simulation"
```

### Step 4: Verify
```bash
# Test health endpoint
curl https://YOUR_WORKER_URL/health

# Should return:
# {"status":"ok","service":"cricket-match-simulator"}
```

## ✅ Done!

Your quick matches now run on Cloudflare Durable Objects with:
- 75% faster simulation (500ms vs 2000ms per ball)
- Automatic fallback to local engine
- Free hit on no ball
- Super over for tied matches

## 🔧 Local Testing (Optional)

```bash
# Terminal 1: Start worker locally
cd cloudflare-worker
npx wrangler dev

# Terminal 2: Update Flutter to use localhost
# Edit cloudflare_quick_match_service.dart:
# static const String workerUrl = 'http://localhost:8787';

# Run Flutter
flutter run -d chrome
```

## 📊 Monitor

```bash
# View Cloudflare logs
npx wrangler tail

# View Flutter logs
# Check console for "Using Cloudflare..." or "falling back to local engine"
```

## 🐛 Troubleshooting

**Worker not deploying?**
```bash
npx wrangler login
npx wrangler deploy
```

**Flutter not connecting?**
- Check worker URL is correct
- Test health endpoint: `curl YOUR_WORKER_URL/health`
- Check CORS is enabled (already configured)

**Always falling back to local?**
- Verify worker is deployed: `curl YOUR_WORKER_URL/health`
- Check Flutter console for error messages
- Ensure worker URL doesn't have trailing slash

## 🎯 Quick Commands

```bash
# Deploy
cd cloudflare-worker && npx wrangler deploy

# View logs
npx wrangler tail

# Test health
curl https://YOUR_WORKER_URL/health

# Run Flutter
flutter run -d chrome
```

That's it! 🎉
