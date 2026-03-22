// ─── Match Simulation Engine ────────────────────────────────────────

import { AICommentaryGenerator } from './ai-commentary.js';

export class MatchEngine {
  constructor(config) {
    this.homeXI = config.homeXI;
    this.awayXI = config.awayXI;
    this.homeChemistry = config.homeChemistry;
    this.awayChemistry = config.awayChemistry;
    this.maxOvers = config.maxOvers;
    this.pitchCondition = config.pitchCondition;
    this.homeTeamName = config.homeTeamName;
    this.awayTeamName = config.awayTeamName;
    this.homeBatsFirst = config.homeBatsFirst;
    this.env = config.env; // For AI commentary
    this.useAICommentary = config.useAICommentary !== false; // Default true

    // Initialize AI commentary generator
    if (this.env && this.useAICommentary) {
      this.aiCommentary = new AICommentaryGenerator(this.env);
    }

    // Match state
    this.innings = 1;
    this.overNumber = 0;
    this.ballNumber = 0;
    this.score1 = 0;
    this.wickets1 = 0;
    this.score2 = 0;
    this.wickets2 = 0;
    this.target = 0;
    this.matchComplete = false;
    this.isSuperOver = false;
    this.freeHitNext = false;

    this.currentBatsmanIndex = 0;
    this.nonStrikerIndex = 1;
    this.nextBatsmanIndex = 2;
    this.currentBowlerIndex = 0;

    // Setup batting/bowling orders
    this.battingOrder1 = [...(this.homeBatsFirst ? this.homeXI : this.awayXI)];
    this.bowlingOrder1 = (this.homeBatsFirst ? this.homeXI : this.awayXI).filter(
      p => p.role === 'bowler' || p.role === 'all_rounder'
    );
    if (this.bowlingOrder1.length === 0) {
      this.bowlingOrder1 = [...(this.homeBatsFirst ? this.homeXI : this.awayXI)];
    }

    this.battingOrder2 = [...(this.homeBatsFirst ? this.awayXI : this.homeXI)];
    this.bowlingOrder2 = (this.homeBatsFirst ? this.awayXI : this.homeXI).filter(
      p => p.role === 'bowler' || p.role === 'all_rounder'
    );
    if (this.bowlingOrder2.length === 0) {
      this.bowlingOrder2 = [...(this.homeBatsFirst ? this.awayXI : this.homeXI)];
    }

    this.currentBatting = this.battingOrder1;
    this.currentBowling = this.bowlingOrder2;

    // Stats tracking
    this.batsmanStats = {};
    this.bowlerStats = {};
  }

  get isFirstInnings() {
    return this.innings === 1;
  }

  get currentWickets() {
    return this.isFirstInnings ? this.wickets1 : this.wickets2;
  }

  get currentBatsman() {
    return this.currentBatting[this.currentBatsmanIndex];
  }

  get nonStriker() {
    return this.currentBatting[this.nonStrikerIndex];
  }

  get currentBowler() {
    return this.currentBowling[this.currentBowlerIndex % this.currentBowling.length];
  }

  getName(cardId) {
    for (const p of [...this.homeXI, ...this.awayXI]) {
      if (p.userCardId === cardId) return p.name;
    }
    return 'Unknown';
  }

  async simulateNextBall() {
    if (this.matchComplete) return null;

    this.ballNumber++;
    if (this.ballNumber > 6) {
      this.ballNumber = 1;
      this.overNumber++;
      this.currentBowlerIndex++;
      this.swapStrike();
    }

    // Check innings/match end
    const maxOversForInnings = this.isSuperOver ? 1 : this.maxOvers;
    const maxWicketsForInnings = this.isSuperOver ? 2 : 10;
    
    if (this.overNumber >= maxOversForInnings || this.currentWickets >= maxWicketsForInnings) {
      if (this.isFirstInnings) {
        return this.endInnings();
      } else {
        // Check for tie and trigger super over
        if (this.score1 === this.score2 && !this.isSuperOver) {
          return this.startSuperOver();
        }
        this.matchComplete = true;
        return null;
      }
    }

    // Check target chased
    if (!this.isFirstInnings && this.score2 > this.target) {
      this.matchComplete = true;
      return null;
    }

    const batsman = this.currentBatsman;
    const bowler = this.currentBowler;
    const chemistry = this.isFirstInnings
      ? (this.homeBatsFirst ? this.homeChemistry : this.awayChemistry)
      : (this.homeBatsFirst ? this.awayChemistry : this.homeChemistry);

    const outcome = this.calculateOutcome(
      batsman.batting,
      bowler.bowling,
      chemistry,
      batsman,
      bowler
    );

    const batsmanName = batsman.name;
    const bowlerName = bowler.name;

    let runs = 0;
    let isWicket = false;
    let isBoundary = false;
    let eventType;
    let commentary;
    let wicketType = null;
    let fielderCardId = null;
    let fielderName = null;
    const isFreeHit = this.freeHitNext;

    switch (outcome) {
      case 'dot':
        runs = 0;
        eventType = 'dot_ball';
        break;
      case 'single':
        runs = 1;
        eventType = 'single';
        this.swapStrike();
        break;
      case 'double':
        runs = 2;
        eventType = 'double';
        break;
      case 'triple':
        runs = 3;
        eventType = 'triple';
        this.swapStrike();
        break;
      case 'four':
        runs = 4;
        isBoundary = true;
        eventType = 'four';
        break;
      case 'six':
        runs = 6;
        isBoundary = true;
        eventType = 'six';
        break;
      case 'wicket':
        // No wicket on free hit
        if (isFreeHit) {
          runs = 0;
          eventType = 'dot_ball';
          isWicket = false;
        } else {
          runs = 0;
          isWicket = true;
          eventType = 'wicket';
          wicketType = this.randomWicketType();
          const fielder = this.pickFielder(wicketType, bowler);
          fielderCardId = fielder?.userCardId ?? null;
          fielderName = fielder?.name;
        }
        break;
      case 'wide':
        runs = 1;
        eventType = 'wide';
        this.ballNumber--;
        break;
      case 'no_ball':
        runs = 1;
        eventType = 'no_ball';
        this.ballNumber--;
        this.freeHitNext = true;
        break;
      default:
        runs = 0;
        eventType = 'dot_ball';
    }

    // Generate AI commentary only for important events to reduce subrequests
    const useAIForThisBall = this.aiCommentary && (['wicket', 'four', 'six', 'no_ball'].includes(eventType));
    
    if (useAIForThisBall) {
      try {
        commentary = await this.aiCommentary.generateCommentary({
          eventType,
          runs,
          batsmanName,
          bowlerName,
          innings: this.innings,
          overNumber: this.overNumber,
          ballNumber: this.ballNumber,
          currentScore: this.isFirstInnings ? this.score1 : this.score2,
          currentWickets: this.currentWickets,
          target: this.target,
          wicketType,
          fielderName,
          isFreeHit,
          isSuperOver: this.isSuperOver,
        });
      } catch (error) {
        console.error('AI commentary failed, using fallback:', error);
        commentary = this.getFallbackCommentary(eventType, batsmanName, bowlerName, wicketType, fielderName, isFreeHit);
      }
    } else {
      commentary = this.getFallbackCommentary(eventType, batsmanName, bowlerName, wicketType, fielderName, isFreeHit);
    }

    // Update score
    if (this.isFirstInnings) {
      this.score1 += runs;
      if (isWicket) {
        this.wickets1++;
        this.advanceBatsman();
      }
    } else {
      this.score2 += runs;
      if (isWicket) {
        this.wickets2++;
        this.advanceBatsman();
      }
    }

    // Clear free hit flag after the ball (unless it was a wide/no-ball)
    if (eventType !== 'no_ball' && eventType !== 'wide') {
      this.freeHitNext = false;
    }

    if (!this.isFirstInnings && this.score2 > this.target) {
      this.matchComplete = true;
    }

    const result = {
      innings: this.innings,
      overNumber: this.overNumber,
      ballNumber: this.ballNumber,
      batsmanCardId: batsman.userCardId,
      bowlerCardId: bowler.userCardId,
      eventType,
      runs,
      isBoundary,
      isWicket,
      wicketType,
      fielderCardId,
      commentary,
      scoreAfter: this.isFirstInnings ? this.score1 : this.score2,
      wicketsAfter: this.isFirstInnings ? this.wickets1 : this.wickets2,
    };

    this.updateStats(result, batsmanName, bowlerName);

    return result;
  }

  updateStats(result, batsmanName, bowlerName) {
    if (result.eventType === 'innings_break') return;

    const isExtra = result.eventType === 'wide' || result.eventType === 'no_ball';
    const batKey = `${result.innings}_${result.batsmanCardId}`;
    const bowlKey = `${result.innings}_${result.bowlerCardId}`;

    if (!this.batsmanStats[batKey]) {
      const battingArr = result.innings === 1 ? this.battingOrder1 : this.battingOrder2;
      const battingPos = battingArr.findIndex(p => p.userCardId === result.batsmanCardId);
      this.batsmanStats[batKey] = {
        name: batsmanName,
        innings: result.innings,
        battingOrder: battingPos >= 0 ? battingPos + 1 : 99,
        runs: 0,
        balls: 0,
        fours: 0,
        sixes: 0,
        isOut: false,
        dismissalType: null,
      };
    }
    const bat = this.batsmanStats[batKey];
    if (result.eventType !== 'wide') bat.balls++;
    bat.runs += result.runs;
    if (result.runs === 4) bat.fours++;
    if (result.runs === 6) bat.sixes++;
    if (result.isWicket) {
      bat.isOut = true;
      bat.dismissalType = this.formatDismissal(
        result.wicketType ?? 'bowled',
        bowlerName,
        result.fielderCardId ? this.getName(result.fielderCardId) : null
      );
    }

    if (!this.bowlerStats[bowlKey]) {
      this.bowlerStats[bowlKey] = {
        name: bowlerName,
        innings: result.innings,
        balls: 0,
        runs: 0,
        wickets: 0,
        maidens: 0,
        dotBalls: 0,
      };
    }
    const bowl = this.bowlerStats[bowlKey];
    if (!isExtra) bowl.balls++;
    bowl.runs += result.runs;
    if (result.isWicket) bowl.wickets++;
    if (result.runs === 0 && !result.isWicket && !isExtra) bowl.dotBalls++;
  }

  formatDismissal(wicketType, bowlerName, fielderName) {
    switch (wicketType) {
      case 'bowled': return `b ${bowlerName}`;
      case 'caught': return `c ${fielderName ?? 'fielder'} b ${bowlerName}`;
      case 'caught_behind': return `c ${fielderName ?? '†keeper'} b ${bowlerName}`;
      case 'lbw': return `lbw b ${bowlerName}`;
      case 'run_out': return `run out (${fielderName ?? 'fielder'})`;
      case 'stumped': return `st ${fielderName ?? '†keeper'} b ${bowlerName}`;
      default: return `b ${bowlerName}`;
    }
  }

  endInnings() {
    this.target = this.score1;

    let endOver, endBall;
    if (this.ballNumber === 1 && this.overNumber > 0) {
      endOver = this.overNumber;
      endBall = 0;
    } else {
      endOver = this.overNumber;
      endBall = this.ballNumber > 0 ? this.ballNumber - 1 : 0;
    }

    const lastBatsmanId = this.currentBatting[this.currentBatsmanIndex].userCardId;
    const lastBowlerId = this.currentBowling[this.currentBowlerIndex % this.currentBowling.length].userCardId;

    this.innings = 2;
    this.overNumber = 0;
    this.ballNumber = 0;
    this.currentBatting = this.battingOrder2;
    this.currentBowling = this.bowlingOrder1;
    this.currentBatsmanIndex = 0;
    this.nonStrikerIndex = 1;
    this.nextBatsmanIndex = 2;
    this.currentBowlerIndex = 0;
    this.freeHitNext = false;

    const commentary = this.isSuperOver
      ? `End of Super Over first innings. Score: ${this.score1}/${this.wickets1}. Target: ${this.target + 1}`
      : `End of first innings. Score: ${this.score1}/${this.wickets1}. Target: ${this.target + 1}`;

    return {
      innings: 1,
      overNumber: endOver,
      ballNumber: endBall,
      batsmanCardId: lastBatsmanId,
      bowlerCardId: lastBowlerId,
      eventType: 'innings_break',
      runs: 0,
      isBoundary: false,
      isWicket: false,
      wicketType: null,
      fielderCardId: null,
      commentary,
      scoreAfter: this.score1,
      wicketsAfter: this.wickets1,
    };
  }

  startSuperOver() {
    const lastBatsmanId = this.currentBatting[this.currentBatsmanIndex].userCardId;
    const lastBowlerId = this.currentBowling[this.currentBowlerIndex % this.currentBowling.length].userCardId;

    // Store regular match scores
    const regularScore1 = this.score1;
    const regularScore2 = this.score2;
    const regularWickets1 = this.wickets1;
    const regularWickets2 = this.wickets2;

    // Reset for super over
    this.isSuperOver = true;
    this.innings = 1;
    this.overNumber = 0;
    this.ballNumber = 0;
    this.score1 = 0;
    this.wickets1 = 0;
    this.score2 = 0;
    this.wickets2 = 0;
    this.target = 0;
    this.freeHitNext = false;

    // Reset batting/bowling for super over (use same orders)
    this.currentBatting = this.battingOrder1;
    this.currentBowling = this.bowlingOrder2;
    this.currentBatsmanIndex = 0;
    this.nonStrikerIndex = 1;
    this.nextBatsmanIndex = 2;
    this.currentBowlerIndex = 0;

    return {
      innings: 2,
      overNumber: 0,
      ballNumber: 0,
      batsmanCardId: lastBatsmanId,
      bowlerCardId: lastBowlerId,
      eventType: 'super_over',
      runs: 0,
      isBoundary: false,
      isWicket: false,
      wicketType: null,
      fielderCardId: null,
      commentary: `Match tied at ${regularScore1}/${regularWickets1}! SUPER OVER to decide the winner!`,
      scoreAfter: regularScore2,
      wicketsAfter: regularWickets2,
    };
  }

  getMatchResult() {
    const battingFirstName = this.homeBatsFirst ? this.homeTeamName : this.awayTeamName;
    const battingSecondName = this.homeBatsFirst ? this.awayTeamName : this.homeTeamName;
    
    if (this.isSuperOver) {
      if (this.score2 > this.score1) {
        return `${battingSecondName} wins the Super Over by ${10 - this.wickets2} wickets!`;
      } else if (this.score1 > this.score2) {
        return `${battingFirstName} wins the Super Over by ${this.score1 - this.score2} runs!`;
      }
      // If super over is also tied, team batting second wins (fewer wickets lost rule)
      if (this.wickets2 < this.wickets1) {
        return `${battingSecondName} wins on fewer wickets lost!`;
      } else if (this.wickets1 < this.wickets2) {
        return `${battingFirstName} wins on fewer wickets lost!`;
      }
      return `${battingSecondName} wins the Super Over!`;
    }
    
    if (this.score2 > this.score1) {
      return `${battingSecondName} wins by ${10 - this.wickets2} wickets!`;
    } else if (this.score1 > this.score2) {
      return `${battingFirstName} wins by ${this.score1 - this.score2} runs!`;
    }
    return 'Match tied!';
  }

  calculateOutcome(battingRating, bowlingRating, chemistry, batsman, bowler) {
    let probs = {
      dot: 0.30, single: 0.30, double: 0.10, triple: 0.02,
      four: 0.15, six: 0.08, wicket: 0.05, wide: 0.015, no_ball: 0.015,
    };

    const matchupScore = battingRating - bowlingRating;
    const normalized = matchupScore / 100;

    probs.four += 0.1 * normalized;
    probs.six += 0.08 * normalized;
    probs.dot -= 0.1 * normalized;
    probs.wicket -= 0.05 * normalized;
    probs.single += 0.03 * normalized;

    const aggression = batsman.aggression ?? battingRating;
    const technique = batsman.technique ?? battingRating;
    const power = batsman.power ?? battingRating;
    const consistency = batsman.consistency ?? battingRating;
    const pace = bowler.pace ?? bowlingRating;
    const accuracy = bowler.accuracy ?? bowlingRating;
    const variations = bowler.variations ?? bowlingRating;

    probs.six += aggression * 0.001;
    probs.wicket += aggression * 0.0005;
    probs.dot -= aggression * 0.0008;
    probs.six += power * 0.0008;
    probs.four += power * 0.0006;
    probs.single += technique * 0.0005;
    probs.double += technique * 0.0003;
    probs.wicket -= technique * 0.0004;
    probs.dot += consistency * 0.0003;
    probs.wicket -= consistency * 0.0005;
    probs.dot += accuracy * 0.001;
    probs.wicket += accuracy * 0.0007;
    probs.wide -= accuracy * 0.0003;
    probs.no_ball -= accuracy * 0.0002;
    probs.wicket += pace * 0.0005;
    probs.dot += pace * 0.0003;
    probs.wicket += variations * 0.0003;
    probs.dot += variations * 0.0002;

    const powerplayEnd = Math.min(10, Math.floor(this.maxOvers * 0.3));
    const middleOversEnd = Math.floor(this.maxOvers * 0.8);

    if (this.overNumber >= middleOversEnd) {
      probs.six += 0.05; probs.four += 0.03; probs.wicket += 0.03;
      probs.dot -= 0.05; probs.single -= 0.02;
    } else if (this.overNumber < powerplayEnd) {
      probs.four += 0.03; probs.six += 0.02; probs.dot -= 0.02;
    } else {
      probs.single += 0.05; probs.double += 0.02;
      probs.dot += 0.02; probs.six -= 0.02;
    }

    if (!this.isFirstInnings && this.target > 0) {
      const currentScore = this.score2;
      const ballsRemaining = (this.maxOvers * 6) - (this.overNumber * 6 + this.ballNumber);
      const runsNeeded = this.target + 1 - currentScore;
      const requiredRunRate = ballsRemaining > 0 ? (runsNeeded / ballsRemaining) * 6 : 0;
      
      if (requiredRunRate > 10) {
        probs.six += 0.07; probs.four += 0.04;
        probs.wicket += 0.04; probs.dot -= 0.08;
      } else if (requiredRunRate > 8) {
        probs.six += 0.04; probs.four += 0.03;
        probs.wicket += 0.02; probs.dot -= 0.04;
      }
      
      if (requiredRunRate < 6) {
        probs.single += 0.05; probs.dot += 0.03;
        probs.six -= 0.03; probs.wicket -= 0.02;
      }
    }

    const currentWickets = this.currentWickets;
    if (currentWickets >= 7) {
      probs.wicket += 0.05; probs.dot += 0.05;
      probs.six -= 0.03; probs.four -= 0.03;
    } else if (currentWickets <= 2) {
      probs.wicket -= 0.02; probs.single += 0.02;
    }

    switch (this.pitchCondition) {
      case 'batting_friendly':
      case 'flat':
        probs.four += 0.05; probs.six += 0.05;
        probs.wicket -= 0.03; probs.dot -= 0.03;
        break;
      case 'bowling_friendly':
      case 'green':
        probs.wicket += 0.05; probs.dot += 0.05;
        probs.four -= 0.03; probs.six -= 0.03;
        break;
      case 'spin_friendly':
      case 'dusty':
        probs.wicket += 0.03; probs.dot += 0.04; probs.six -= 0.02;
        break;
    }

    const chemMod = chemistry / 500;
    probs.four += chemMod * 0.02;
    probs.six += chemMod * 0.01;
    probs.wicket -= chemMod * 0.02;

    probs.dot = clamp(probs.dot, 0.05, 0.6);
    probs.single = clamp(probs.single, 0.1, 0.45);
    probs.double = clamp(probs.double, 0.02, 0.2);
    probs.triple = clamp(probs.triple, 0.005, 0.05);
    probs.four = clamp(probs.four, 0.02, 0.3);
    probs.six = clamp(probs.six, 0.01, 0.2);
    probs.wicket = clamp(probs.wicket, 0.01, 0.2);
    probs.wide = clamp(probs.wide, 0.005, 0.05);
    probs.no_ball = clamp(probs.no_ball, 0.005, 0.03);

    const total = Object.values(probs).reduce((a, b) => a + b, 0);
    for (const key in probs) {
      probs[key] /= total;
    }

    const roll = Math.random();
    let cum = 0;
    for (const [outcome, prob] of Object.entries(probs)) {
      cum += prob;
      if (roll < cum) return outcome;
    }
    return 'dot';
  }

  swapStrike() {
    const temp = this.currentBatsmanIndex;
    this.currentBatsmanIndex = this.nonStrikerIndex;
    this.nonStrikerIndex = temp;
  }

  advanceBatsman() {
    if (this.nextBatsmanIndex < this.currentBatting.length) {
      this.currentBatsmanIndex = this.nextBatsmanIndex;
      this.nextBatsmanIndex++;
    }
  }

  randomWicketType() {
    return pick(['bowled', 'caught', 'lbw', 'run_out', 'stumped', 'caught_behind']);
  }

  pickFielder(wicketType, bowler) {
    if (wicketType === 'bowled' || wicketType === 'lbw') return null;
    const allFielders = this.isFirstInnings
      ? (this.homeBatsFirst ? this.awayXI : this.homeXI)
      : (this.homeBatsFirst ? this.homeXI : this.awayXI);
    if (wicketType === 'caught_behind' || wicketType === 'stumped') {
      const keepers = allFielders.filter(p => p.role === 'wicket_keeper');
      if (keepers.length > 0) return keepers[Math.floor(Math.random() * keepers.length)];
    }
    const candidates = allFielders.filter(p => p.userCardId !== bowler.userCardId);
    if (candidates.length === 0) return allFielders[Math.floor(Math.random() * allFielders.length)];
    return candidates[Math.floor(Math.random() * candidates.length)];
  }

  getFallbackCommentary(eventType, batsmanName, bowlerName, wicketType, fielderName, isFreeHit) {
    let commentary;
    
    switch (eventType) {
      case 'dot_ball':
        commentary = this.dotCommentary(batsmanName, bowlerName);
        break;
      case 'single':
        commentary = pick([
          `${batsmanName} pushes for a quick single.`,
          `Good running! They scamper through for one.`,
          `${batsmanName} taps it into the gap, easy single.`,
        ]);
        break;
      case 'double':
        commentary = pick([
          `${batsmanName} drives through the gap for two.`,
          `Well placed! They come back for the second.`,
        ]);
        break;
      case 'triple':
        commentary = pick([
          `${batsmanName} finds the gap, they run three!`,
          `Excellent running! Three runs taken!`,
        ]);
        break;
      case 'four':
        commentary = this.fourCommentary(batsmanName, bowlerName);
        break;
      case 'six':
        commentary = this.sixCommentary(batsmanName);
        break;
      case 'wicket':
        if (isFreeHit) {
          commentary = `${batsmanName} misses but it's a FREE HIT! No wicket!`;
        } else {
          commentary = this.wicketCommentary(batsmanName, bowlerName, wicketType, fielderName);
        }
        break;
      case 'wide':
        commentary = pick([
          `Wide ball from ${bowlerName}. Extra run.`,
          `WIDE! ${bowlerName} loses his line.`,
        ]);
        break;
      case 'no_ball':
        commentary = pick([
          `No ball! Free hit coming up.`,
          `NO BALL! ${bowlerName} oversteps! FREE HIT next!`,
        ]);
        break;
      default:
        commentary = 'Dot ball.';
    }
    
    if (isFreeHit && eventType !== 'no_ball' && eventType !== 'wicket') {
      commentary += ' (Free Hit)';
    }
    
    return commentary;
  }

  dotCommentary(batsman, bowler) {
    return pick([
      `${bowler} keeps it tight, dot ball.`,
      `Good length from ${bowler}, ${batsman} defends solidly.`,
      `Beaten! ${bowler} just misses the edge.`,
      `${batsman} leaves it alone, good judgement.`,
      `Tight line from ${bowler}, no run.`,
    ]);
  }

  fourCommentary(batsman, bowler) {
    return pick([
      `${batsman} punches it through cover for FOUR!`,
      `FOUR! ${batsman} drives beautifully past mid-off!`,
      `Pulled away for FOUR! ${batsman} is in command.`,
      `Cut shot for FOUR! ${batsman} finds the gap.`,
    ]);
  }

  sixCommentary(batsman) {
    return pick([
      `SIX! ${batsman} launches it into the stands!`,
      `MASSIVE SIX! ${batsman} clears the boundary with ease!`,
      `That's gone all the way! SIX by ${batsman}!`,
      `What a hit! ${batsman} muscles it for SIX!`,
    ]);
  }

  wicketCommentary(batsman, bowler, wicketType, fielderName) {
    switch (wicketType) {
      case 'bowled':
        return pick([
          `BOWLED! ${bowler} knocks over the stumps! ${batsman} is gone!`,
          `Timber! ${bowler} cleans up ${batsman}! What a delivery!`,
        ]);
      case 'caught':
        const c = fielderName ?? 'fielder';
        return pick([
          `CAUGHT! ${batsman} edges it and ${c} takes a sharp catch!`,
          `OUT! Caught by ${c}! ${bowler} gets the wicket!`,
        ]);
      case 'caught_behind':
        const k = fielderName ?? '†keeper';
        return pick([
          `CAUGHT BEHIND! ${batsman} nicks it and ${k} takes a clean catch!`,
          `Edge and taken! ${k} snaps it up!`,
        ]);
      case 'lbw':
        return pick([
          `LBW! ${bowler} traps ${batsman} plumb in front!`,
          `OUT! LBW! That was crashing into the stumps!`,
        ]);
      case 'run_out':
        const t = fielderName ?? 'fielder';
        return pick([
          `RUN OUT! Direct hit by ${t}! ${batsman} is short!`,
          `Gone! Brilliant throw from ${t}!`,
        ]);
      case 'stumped':
        const sk = fielderName ?? '†keeper';
        return pick([
          `STUMPED! ${batsman} dances down and ${sk} whips the bails off!`,
          `OUT! Quick work by ${sk}!`,
        ]);
      default:
        return `OUT! ${bowler} strikes! ${batsman} has to walk back.`;
    }
  }

  serialize() {
    return {
      homeXI: this.homeXI,
      awayXI: this.awayXI,
      homeChemistry: this.homeChemistry,
      awayChemistry: this.awayChemistry,
      maxOvers: this.maxOvers,
      pitchCondition: this.pitchCondition,
      homeTeamName: this.homeTeamName,
      awayTeamName: this.awayTeamName,
      homeBatsFirst: this.homeBatsFirst,
      innings: this.innings,
      overNumber: this.overNumber,
      ballNumber: this.ballNumber,
      score1: this.score1,
      wickets1: this.wickets1,
      score2: this.score2,
      wickets2: this.wickets2,
      target: this.target,
      matchComplete: this.matchComplete,
      isSuperOver: this.isSuperOver,
      freeHitNext: this.freeHitNext,
      currentBatsmanIndex: this.currentBatsmanIndex,
      nonStrikerIndex: this.nonStrikerIndex,
      nextBatsmanIndex: this.nextBatsmanIndex,
      currentBowlerIndex: this.currentBowlerIndex,
      battingOrder1: this.battingOrder1,
      bowlingOrder1: this.bowlingOrder1,
      battingOrder2: this.battingOrder2,
      bowlingOrder2: this.bowlingOrder2,
      currentBatting: this.currentBatting,
      currentBowling: this.currentBowling,
      batsmanStats: this.batsmanStats,
      bowlerStats: this.bowlerStats,
    };
  }

  static deserialize(data) {
    const engine = Object.create(MatchEngine.prototype);
    Object.assign(engine, data);
    return engine;
  }
}

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v));
}
