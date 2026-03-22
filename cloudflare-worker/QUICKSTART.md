# Quick Start - Cloudflare Durable Objects

## 5-Minute Setup

### 1. Install & Login
```bash
npm install -g wrangler
wrangler login
```

### 2. Configure
```bash
cd cloudflare-worker
npm install

# Edit wrangler.toml - set your Supabase URL
# Set secret
wrangler secret put SUPABASE_SERVICE_KEY
```

### 3. Deploy
```bash
wrangler deploy
```

### 4. Update Flutter
Copy the Worker URL from deploy output, then edit:
```dart
// lib/core/cloudflare_match_service.dart
static const String workerUrl = 'https://YOUR-WORKER-URL.workers.dev';
```

### 5. Test
```bash
# Health check
curl https://YOUR-WORKER-URL.workers.dev/health

# Should return: {"status":"ok","service":"cricket-match-simulator"}
```

Done! Your multiplayer matches now run on Cloudflare Durable Objects.

## Verify It's Working

1. Start a multiplayer match in Flutter
2. Check Cloudflare logs:
   ```bash
   wrangler tail
   ```
3. You should see:
   - "Starting simulation for match..."
   - "Ball X: score updates..."
   - "Match completed: result..."

## Common Issues

**"Module not found"**
```bash
cd cloudflare-worker
npm install
wrangler deploy
```

**"Unauthorized"**
```bash
wrangler login
```

**"Supabase updates not working"**
```bash
wrangler secret put SUPABASE_SERVICE_KEY
# Paste your service role key
```

## Need Help?

See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for detailed instructions.
