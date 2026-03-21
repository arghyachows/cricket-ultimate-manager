# AI Commentary Status

## Current Issue
Cloudflare Workers AI (Llama 3 8B) is too slow for real-time match simulation:
- AI response time: 1-3 seconds per request
- Edge Function timeout: Requests are being canceled after 800ms-2s
- Match simulation requires ~40-50 AI calls (for fours, sixes, wickets)
- Total AI time: 40-150 seconds just for commentary

## Solutions

### Option 1: Disable AI Commentary (Recommended for now)
Remove the `CLOUDFLARE_AI_WORKER_URL` environment variable:
```bash
supabase secrets unset CLOUDFLARE_AI_WORKER_URL
```

This will use the original fallback commentary which is fast and reliable.

### Option 2: Use Faster AI Model
Switch to a faster model in `commentary-ai.js`:
```javascript
// Replace @cf/meta/llama-3-8b-instruct with:
await env.AI.run('@cf/meta/llama-2-7b-chat-int8', {
  // Faster but lower quality
})
```

### Option 3: Pre-generate Commentary (Future)
- Generate all possible commentary variations upfront
- Store in database
- Select appropriate one based on context
- No AI latency during match

### Option 4: Async Commentary (Future Phase 2)
- Simulate match without waiting for AI
- Generate AI commentary asynchronously
- Update commentary in database after generation
- Users see fallback first, then AI replaces it

### Option 5: Use OpenAI/Anthropic (Paid)
Faster models but requires API keys and costs money:
- OpenAI GPT-3.5-turbo: ~500ms response
- Anthropic Claude Haiku: ~300ms response
- Cost: ~$0.001 per commentary

## Recommendation

**For Production**: Use Option 1 (disable AI) until Phase 2 implementation with async commentary.

**For Testing**: Keep AI enabled but expect slower simulations (2-3 minutes per T20 match instead of 30 seconds).

## Current Configuration

- AI Commentary: Only for fours, sixes, wickets (not dots/singles/doubles)
- Timeout: 2 seconds per request
- Delay between balls: 100ms
- Fallback: Always uses original commentary on timeout/error
