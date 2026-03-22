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

    // Build context for AI
    const matchContext = this.buildMatchContext(context);
    const prompt = this.buildPrompt(eventType, matchContext);

    try {
      // Use Cloudflare Workers AI
      const response = await this.env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
        messages: [
          {
            role: 'system',
            content: 'You are an energetic cricket commentator. Generate a single short commentary line (max 15 words) for the cricket ball described. Be exciting and natural. Do not use quotes or extra formatting.',
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

  buildPrompt(eventType, matchContext) {
    const { batsmanName, bowlerName, runs, wicketType, fielderName } = arguments[1];

    switch (eventType) {
      case 'dot_ball':
        return `${matchContext}. ${bowlerName} bowls to ${batsmanName}. Dot ball, no run scored. Commentary:`;
      
      case 'single':
        return `${matchContext}. ${batsmanName} takes a quick single off ${bowlerName}. Commentary:`;
      
      case 'double':
        return `${matchContext}. ${batsmanName} pushes for two runs off ${bowlerName}. Commentary:`;
      
      case 'triple':
        return `${matchContext}. ${batsmanName} runs three off ${bowlerName}. Commentary:`;
      
      case 'four':
        return `${matchContext}. ${batsmanName} hits a FOUR off ${bowlerName}! Commentary:`;
      
      case 'six':
        return `${matchContext}. ${batsmanName} smashes a SIX off ${bowlerName}! Commentary:`;
      
      case 'wicket':
        const dismissal = this.formatWicketType(wicketType, fielderName);
        return `${matchContext}. WICKET! ${batsmanName} is out ${dismissal} off ${bowlerName}. Commentary:`;
      
      case 'wide':
        return `${matchContext}. ${bowlerName} bowls a WIDE. Extra run. Commentary:`;
      
      case 'no_ball':
        return `${matchContext}. NO BALL by ${bowlerName}! Free hit next. Commentary:`;
      
      default:
        return `${matchContext}. ${bowlerName} to ${batsmanName}. Commentary:`;
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
