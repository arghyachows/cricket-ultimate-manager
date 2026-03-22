# Check Backend Connection

## Steps to Verify Node.js Backend Connection in Chrome

1. **Start a match in Flutter web (Chrome)**

2. **Immediately run this command to see backend logs:**
   ```bash
   docker logs cricket-backend --tail 50 -f
   ```

3. **What to look for:**
   - ✅ If you see logs like `📥 POST /api/match/start from ::ffff:...` → Node.js backend is working
   - ❌ If you see NO new logs → Flutter web is NOT reaching Node.js backend

4. **If NO logs appear, the issue is:**
   - Browser is blocking the connection due to CORS/network policy
   - Flutter web cannot connect to `localhost:3000` from the browser
   - App is falling back to Cloudflare

## Solution: Test Connection Manually

Open Chrome DevTools (F12) → Console tab → Run:
```javascript
fetch('http://localhost:3000/health')
  .then(r => r.json())
  .then(d => console.log('✅ Backend reachable:', d))
  .catch(e => console.error('❌ Backend NOT reachable:', e))
```

If this fails with CORS or network error, **Chrome cannot reach the Node.js backend**.

## Why This Happens

Flutter web runs on a random port (e.g., `http://localhost:54321`), and browsers block cross-origin requests even between different localhost ports unless:
1. CORS headers are properly set (already done: `Access-Control-Allow-Origin: *`)
2. The request is not blocked by browser security policies

## Workaround

Run Flutter on native platform instead of web:
```bash
flutter run -d windows
# or
flutter run -d android
```

Native platforms don't have browser CORS restrictions and will connect to Node.js backend successfully.
