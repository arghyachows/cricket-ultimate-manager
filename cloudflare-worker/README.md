# Cricket Commentary AI - Cloudflare Worker

AI-powered cricket commentary generation using Cloudflare Workers AI (Llama 3).

## Setup

1. **Install Wrangler CLI**
   ```bash
   npm install
   ```

2. **Login to Cloudflare**
   ```bash
   npx wrangler login
   ```

3. **Deploy Worker**
   ```bash
   npm run deploy
   ```

4. **Test Locally**
   ```bash
   npm run dev
   ```

## Usage

**Endpoint**: `POST https://cricket-commentary-ai.YOUR_SUBDOMAIN.workers.dev`

**Request Body**:
```json
{
  "context": {
    "batsman": "V. Kohli",
    "bowler": "J. Bumrah",
    "eventType": "four",
    "runs": 4,
    "score": 145,
    "wickets": 3,
    "overs": "15.2",
    "phase": "death",
    "fallbackCommentary": "FOUR! Kohli drives through covers!"
  }
}
```

**Response**:
```json
{
  "commentary": "Magnificent cover drive by Kohli! That races to the boundary!"
}
```

## Features

- ✅ AI-generated contextual commentary
- ✅ Fallback to default commentary on error
- ✅ CORS enabled for cross-origin requests
- ✅ Fast response times (<500ms)
- ✅ Free tier: 10,000 requests/day

## Cost

Cloudflare Workers AI Free Tier:
- 10,000 neurons/day (approximately 10,000 commentary generations)
- Perfect for development and moderate usage
