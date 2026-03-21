# Phase 1: AI Commentary Integration Guide

## Overview
Keep Supabase simulation, add Cloudflare Workers AI for commentary only.

## Implementation Steps

### 1. Deploy Cloudflare Worker

```bash
cd cloudflare-worker
npm install
npx wrangler login
npm run deploy
```

After deployment, you'll get a URL like:
`https://cricket-commentary-ai.YOUR_SUBDOMAIN.workers.dev`

### 2. Add Environment Variable to Supabase

Add to your Supabase Edge Function secrets:

```bash
supabase secrets set CLOUDFLARE_AI_WORKER_URL=https://cricket-commentary-ai.YOUR_SUBDOMAIN.workers.dev
```

### 3. Modify Edge Function

In `supabase/functions/simulate-multiplayer/index.ts`, add AI commentary generation:

**Import the helper** (add at top):
```typescript
import { generateAICommentary } from './ai-commentary.ts';
```

**Get worker URL** (add after supabase client creation):
```typescript
const aiWorkerUrl = Deno.env.get('CLOUDFLARE_AI_WORKER_URL');
const useAI = !!aiWorkerUrl; // Enable AI if URL is set
```

**Replace commentary generation** (in simulateNextBall switch statement):

```typescript
// Example for "four" case:
case "four":
  runs = 4;
  isBoundary = true;
  eventType = "four";
  const fallbackFour = this.fourCommentary(batsmanName, bowlerName);
  
  if (useAI) {
    commentary = await generateAICommentary({
      batsman: batsmanName,
      bowler: bowlerName,
      eventType: 'four',
      runs: 4,
      score: this.isFirstInnings ? this.score1 : this.score2,
      wickets: this.currentWickets,
      overs: `${this.overNumber}.${this.ballNumber}`,
      phase: this.overNumber >= middleOversEnd ? 'death' : 
             this.overNumber < powerplayEnd ? 'powerplay' : 'middle',
    }, fallbackFour, aiWorkerUrl!);
  } else {
    commentary = fallbackFour;
  }
  break;
```

### 4. Make simulateNextBall Async

Change method signature:
```typescript
async simulateNextBall(): Promise<BallResult | null> {
  // ... existing code
}
```

Update the simulation loop:
```typescript
while (!engine.matchComplete) {
  const result = await engine.simulateNextBall(); // Add await
  if (!result) break;
  // ... rest of code
}
```

## Benefits

✅ **No Breaking Changes**: Simulation logic stays the same
✅ **Graceful Fallback**: Uses original commentary if AI fails
✅ **Easy Toggle**: Enable/disable AI via environment variable
✅ **Cost Effective**: Free tier covers 10,000 requests/day
✅ **Fast**: AI generation adds ~200-500ms per ball

## Testing

### Test Cloudflare Worker Locally
```bash
cd cloudflare-worker
npm run dev
```

### Test with curl
```bash
curl -X POST http://localhost:8787 \
  -H "Content-Type: application/json" \
  -d '{
    "context": {
      "batsman": "V. Kohli",
      "bowler": "J. Bumrah",
      "eventType": "six",
      "runs": 6,
      "score": 145,
      "wickets": 3,
      "overs": "15.2",
      "phase": "death",
      "fallbackCommentary": "SIX! Kohli launches it!"
    }
  }'
```

## Cost Analysis

**Cloudflare Workers AI Free Tier:**
- 10,000 neurons/day
- 1 commentary = ~1 neuron
- Supports ~10,000 balls/day
- Average T20 match = 240 balls
- **~40 matches/day free**

**Paid Tier (if needed):**
- $0.011 per 1,000 neurons
- 1,000 matches = ~$2.64

## Rollback Plan

If issues occur, simply remove the environment variable:
```bash
supabase secrets unset CLOUDFLARE_AI_WORKER_URL
```

The Edge Function will automatically fall back to original commentary.

## Next Steps (Future Phases)

- Phase 2: Move full simulation to Cloudflare Workers
- Phase 3: Add real-time streaming with WebSockets
- Phase 4: Multi-model AI (different models for different events)
