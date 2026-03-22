# Fix Node.js Backend for Chrome

## Problem
Chrome blocks Flutter web from connecting to `localhost:3000` or `127.0.0.1:3000` due to browser security policies.

## Solution: Run Backend Without Docker

Docker binds to `0.0.0.0:3000` which Chrome may block. Running directly on Windows makes it accessible.

### Steps:

1. **Stop Docker backend:**
   ```bash
   docker-compose down
   ```

2. **Install Redis on Windows** (if not installed):
   - Download from: https://github.com/microsoftarchive/redis/releases
   - Or use Chocolatey: `choco install redis-64`
   - Start Redis: `redis-server`

3. **Run Node.js backend directly:**
   ```bash
   cd node-backend
   npm install
   npm run dev
   ```

4. **Verify it's accessible from Chrome:**
   - Open Chrome DevTools (F12) → Console
   - Run:
     ```javascript
     fetch('http://127.0.0.1:3000/test')
       .then(r => r.json())
       .then(d => console.log('✅ Connected:', d))
       .catch(e => console.error('❌ Failed:', e))
     ```

5. **Hot restart Flutter app** (press `R` in terminal)

6. **Start a match** and check logs:
   ```bash
   # In node-backend directory
   # Logs will show in the terminal where you ran `npm run dev`
   ```

## Alternative: Use Windows Desktop

If the above doesn't work, Chrome has strict security policies. Use Windows desktop instead:

```bash
flutter run -d windows
```

Windows desktop apps don't have browser restrictions and will connect successfully.
