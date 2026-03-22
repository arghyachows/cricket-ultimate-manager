// ─── AI Commentary Generator ─────────────────────────────────────────

export class AICommentaryGenerator {
  constructor(env) {
    this.env = env;
    this.cache = new Map();
  }

  async generateCommentary(context) {
    const {
      eventType,
      runs,
      batsmanName,
      bowlerName,
      innings,
      overNumber,
      ballNumber,
      currentScore,
      currentWickets,
      target,
      wicketType,
      fielderName,
      isFreeHit,
      isSuperOver,
    } = context;

    // Create cache key based on event type and situation
    const cacheKey = this.buildCacheKey(eventType, innings, currentScore, currentWickets, target, wicketType, isSuperOver);
    
    // Check cache first
    if (this.cache.has(cacheKey)) {
      const cached = this.cache.get(cacheKey);
      // Personalize cached commentary with player names
      let commentary = cached
        .replace(/BATSMAN/g, batsmanName)
        .replace(/BOWLER/g, bowlerName)
        .replace(/FIELDER/g, fielderName || 'fielder');
      
      if (isFreeHit && eventType !== 'no_ball') {
        commentary += ' (Free Hit)';
      }
      return commentary;
    }

    // Build context for AI
    const matchContext = this.buildMatchContext(context);
    const prompt = this.buildPrompt(eventType, matchContext, context);

    try {
      // Use Cloudflare Workers AI with a faster model
      const response = await this.env.AI.run('@cf/meta/llama-3-8b-instruct', {
        messages: [
          {
            role: 'system',
            content: 'You are an energetic cricket commentator. Generate a single short commentary line (max 15 words) for the cricket ball described. Be exciting and natural. Do not use quotes or extra formatting. Use BATSMAN for batsman name, BOWLER for bowler name, FIELDER for fielder name.',
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        max_tokens: 50,
        temperature: 0.9,
      });

      let commentary = response.response?.trim() || this.getFallbackCommentary(eventType, context);
      
      // Clean up AI response
      commentary = commentary.replace(/^["']|["']$/g, '').trim();
      
      // Cache the generic version (with placeholders)
      this.cache.set(cacheKey, commentary);
      
      // Limit cache size to 50 entries
      if (this.cache.size > 50) {
        const firstKey = this.cache.keys().next().value;
        this.cache.delete(firstKey);
      }
      
      // Personalize with actual names
      commentary = commentary
        .replace(/BATSMAN/g, batsmanName)
        .replace(/BOWLER/g, bowlerName)
        .replace(/FIELDER/g, fielderName || 'fielder');
      
      // Add free hit indicator
      if (isFreeHit && eventType !== 'no_ball') {
        commentary += ' (Free Hit)';
      }

      return commentary;
    } catch (error) {
      console.error('AI commentary error:', error);
      return this.getFallbackCommentary(eventType, context);
    }
  }

  buildCacheKey(eventType, innings, currentScore, currentWickets, target, wicketType, isSuperOver) {
    // Create a cache key based on situation, not specific players
    let situation = '';
    
    if (isSuperOver) {
      situation = 'SO';
    } else if (innings === 1) {
      situation = 'I1';
    } else {
      const runsNeeded = target + 1 - currentScore;
      if (runsNeeded <= 10) {
        situation = 'CLOSE';
      } else if (runsNeeded <= 30) {
        situation = 'CHASE';
      } else {
        situation = 'I2';
      }
    }
    
    const wicketSituation = currentWickets >= 7 ? 'TAIL' : currentWickets <= 2 ? 'TOP' : 'MID';
    
    return `${eventType}_${situation}_${wicketSituation}_${wicketType || 'none'}`;
  }

  buildMatchContext(context) {
    const {
      innings,
      overNumber,
      ballNumber,
      currentScore,
      currentWickets,
      target,
      isSuperOver,
    } = context;

    let situation = '';
    
    if (isSuperOver) {
      situation = 'SUPER OVER';
    } else if (innings === 1) {
      situation = 'First innings';
    } else {
      const runsNeeded = target + 1 - currentScore;
      if (runsNeeded <= 10) {
        situation = `${runsNeeded} runs needed to win`;
      } else if (runsNeeded <= 30) {
        situation = 'Chasing the target';
      } else {
        situation = 'Second innings';
      }
    }

    return `${situation}. Score: ${currentScore}/${currentWickets}. Over ${overNumber}.${ballNumber}`;
  }

  buildPrompt(eventType, matchContext, context) {
    const { batsmanName, bowlerName, runs, wicketType, fielderName } = context;

    switch (eventType) {
      case 'dot_ball':
        return `${matchContext}. BOWLER bowls to BATSMAN. Dot ball, no run scored. Commentary:`;
      
      case 'single':
        return `${matchContext}. BATSMAN takes a quick single off BOWLER. Commentary:`;
      
      case 'double':
        return `${matchContext}. BATSMAN pushes for two runs off BOWLER. Commentary:`;
      
      case 'triple':
        return `${matchContext}. BATSMAN runs three off BOWLER. Commentary:`;
      
      case 'four':
        return `${matchContext}. BATSMAN hits a FOUR off BOWLER! Commentary:`;
      
      case 'six':
        return `${matchContext}. BATSMAN smashes a SIX off BOWLER! Commentary:`;
      
      case 'wicket':
        const dismissal = this.formatWicketType(wicketType, 'FIELDER');
        return `${matchContext}. WICKET! BATSMAN is out ${dismissal} off BOWLER. Commentary:`;
      
      case 'wide':
        return `${matchContext}. BOWLER bowls a WIDE. Extra run. Commentary:`;
      
      case 'no_ball':
        return `${matchContext}. NO BALL by BOWLER! Free hit next. Commentary:`;
      
      default:
        return `${matchContext}. BOWLER to BATSMAN. Commentary:`;
    }
  }

  formatWicketType(wicketType, fielderName) {
    switch (wicketType) {
      case 'bowled': return 'bowled';
      case 'caught': return `caught by ${fielderName || 'fielder'}`;
      case 'caught_behind': return `caught behind by ${fielderName || 'keeper'}`;
      case 'lbw': return 'LBW';
      case 'run_out': return `run out by ${fielderName || 'fielder'}`;
      case 'stumped': return `stumped by ${fielderName || 'keeper'}`;
      default: return 'out';
    }
  }

  getFallbackCommentary(eventType, context) {
    const { batsmanName, bowlerName, wicketType, fielderName } = context;

    switch (eventType) {
      case 'dot_ball':
        return pick([
          `${bowlerName} keeps it tight, dot ball.`,
          `Good length from ${bowlerName}, ${batsmanName} defends.`,
          `Beaten! ${bowlerName} just misses the edge.`,
        ]);
      
      case 'single':
        return pick([
          `${batsmanName} pushes for a quick single.`,
          `Good running! They scamper through for one.`,
        ]);
      
      case 'double':
        return pick([
          `${batsmanName} drives through the gap for two.`,
          `Well placed! They come back for the second.`,
        ]);
      
      case 'triple':
        return pick([
          `${batsmanName} finds the gap, they run three!`,
          `Excellent running! Three runs taken!`,
        ]);
      
      case 'four':
        return pick([
          `${batsmanName} punches it through cover for FOUR!`,
          `FOUR! ${batsmanName} drives beautifully!`,
        ]);
      
      case 'six':
        return pick([
          `SIX! ${batsmanName} launches it into the stands!`,
          `MASSIVE SIX! ${batsmanName} clears the boundary!`,
        ]);
      
      case 'wicket':
        return `OUT! ${bowlerName} strikes! ${batsmanName} has to walk back.`;
      
      case 'wide':
        return `Wide ball from ${bowlerName}. Extra run.`;
      
      case 'no_ball':
        return `No ball! Free hit coming up.`;
      
      default:
        return `${bowlerName} to ${batsmanName}.`;
    }
  }
}

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}
