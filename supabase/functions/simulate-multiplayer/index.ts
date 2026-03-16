import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ─── Types ──────────────────────────────────────────────────────────

interface Player {
  userCardId: string;
  name: string;
  role: string;
  batting: number;
  bowling: number;
  fielding: number;
}

interface BatsmanStats {
  name: string;
  innings: number;
  runs: number;
  balls: number;
  fours: number;
  sixes: number;
  isOut: boolean;
  dismissalType: string | null;
}

interface BowlerStats {
  name: string;
  innings: number;
  balls: number;
  runs: number;
  wickets: number;
  maidens: number;
  dotBalls: number;
}

interface BallResult {
  innings: number;
  overNumber: number;
  ballNumber: number;
  batsmanCardId: string;
  bowlerCardId: string;
  eventType: string;
  runs: number;
  isBoundary: boolean;
  isWicket: boolean;
  wicketType: string | null;
  fielderCardId: string | null;
  commentary: string;
  scoreAfter: number;
  wicketsAfter: number;
}

// ─── Match Engine (ported from Dart) ────────────────────────────────

class MatchEngine {
  homeXI: Player[];
  awayXI: Player[];
  homeChemistry: number;
  awayChemistry: number;
  maxOvers: number;
  pitchCondition: string;
  homeTeamName: string;
  awayTeamName: string;
  homeBatsFirst: boolean;

  innings = 1;
  overNumber = 0;
  ballNumber = 0;
  score1 = 0;
  wickets1 = 0;
  score2 = 0;
  wickets2 = 0;
  target = 0;
  matchComplete = false;

  private currentBatsmanIndex = 0;
  private nonStrikerIndex = 1;
  private nextBatsmanIndex = 2;
  private currentBowlerIndex = 0;

  private battingOrder1: Player[];
  private bowlingOrder1: Player[];
  private battingOrder2: Player[];
  private bowlingOrder2: Player[];
  private currentBatting: Player[];
  private currentBowling: Player[];

  // Stats tracking
  batsmanStats: Record<string, BatsmanStats> = {};
  bowlerStats: Record<string, BowlerStats> = {};

  constructor(
    homeXI: Player[],
    awayXI: Player[],
    homeChemistry: number,
    awayChemistry: number,
    maxOvers: number,
    pitchCondition: string,
    homeTeamName: string,
    awayTeamName: string,
    homeBatsFirst: boolean
  ) {
    this.homeXI = homeXI;
    this.awayXI = awayXI;
    this.homeChemistry = homeChemistry;
    this.awayChemistry = awayChemistry;
    this.maxOvers = maxOvers;
    this.pitchCondition = pitchCondition;
    this.homeTeamName = homeTeamName;
    this.awayTeamName = awayTeamName;
    this.homeBatsFirst = homeBatsFirst;

    this.battingOrder1 = [...(homeBatsFirst ? homeXI : awayXI)];
    this.bowlingOrder1 = (homeBatsFirst ? homeXI : awayXI).filter(
      (p) => p.role === "bowler" || p.role === "all_rounder"
    );
    if (this.bowlingOrder1.length === 0)
      this.bowlingOrder1 = [...(homeBatsFirst ? homeXI : awayXI)];

    this.battingOrder2 = [...(homeBatsFirst ? awayXI : homeXI)];
    this.bowlingOrder2 = (homeBatsFirst ? awayXI : homeXI).filter(
      (p) => p.role === "bowler" || p.role === "all_rounder"
    );
    if (this.bowlingOrder2.length === 0)
      this.bowlingOrder2 = [...(homeBatsFirst ? awayXI : homeXI)];

    this.currentBatting = this.battingOrder1;
    this.currentBowling = this.bowlingOrder2;
  }

  get isFirstInnings(): boolean {
    return this.innings === 1;
  }
  get currentWickets(): number {
    return this.isFirstInnings ? this.wickets1 : this.wickets2;
  }
  get currentBatsman(): Player {
    return this.currentBatting[this.currentBatsmanIndex];
  }
  get currentBowler(): Player {
    return this.currentBowling[
      this.currentBowlerIndex % this.currentBowling.length
    ];
  }

  getName(cardId: string): string {
    for (const p of [...this.homeXI, ...this.awayXI]) {
      if (p.userCardId === cardId) return p.name;
    }
    return "Unknown";
  }

  simulateNextBall(): BallResult | null {
    if (this.matchComplete) return null;

    this.ballNumber++;
    if (this.ballNumber > 6) {
      this.ballNumber = 1;
      this.overNumber++;
      this.currentBowlerIndex++;
      this.swapStrike();
    }

    if (this.overNumber >= this.maxOvers || this.currentWickets >= 10) {
      if (this.isFirstInnings) {
        return this.endInnings();
      } else {
        this.matchComplete = true;
        return null;
      }
    }

    if (!this.isFirstInnings && this.score2 > this.target) {
      this.matchComplete = true;
      return null;
    }

    const batsman = this.currentBatsman;
    const bowler = this.currentBowler;
    const chemistry = this.isFirstInnings
      ? this.homeBatsFirst
        ? this.homeChemistry
        : this.awayChemistry
      : this.homeBatsFirst
        ? this.awayChemistry
        : this.homeChemistry;

    const outcome = this.calculateOutcome(
      batsman.batting,
      bowler.bowling,
      chemistry
    );

    const batsmanName = batsman.name;
    const bowlerName = bowler.name;

    let runs = 0;
    let isWicket = false;
    let isBoundary = false;
    let eventType: string;
    let commentary: string;
    let wicketType: string | null = null;
    let fielderCardId: string | null = null;

    switch (outcome) {
      case "dot":
        runs = 0;
        eventType = "dot_ball";
        commentary = this.dotCommentary(batsmanName, bowlerName);
        break;
      case "single":
        runs = 1;
        eventType = "single";
        commentary = pick([
          `${batsmanName} pushes for a quick single.`,
          `Good running! They scamper through for one.`,
          `${batsmanName} taps it into the gap, easy single.`,
          `Quick single taken by ${batsmanName}.`,
          `${batsmanName} nudges it away for a single.`,
        ]);
        this.swapStrike();
        break;
      case "double":
        runs = 2;
        eventType = "double";
        commentary = pick([
          `${batsmanName} drives through the gap for two.`,
          `Well placed! They come back for the second.`,
          `${batsmanName} finds the gap, comfortable two runs.`,
          `Good running between the wickets, two runs added.`,
        ]);
        break;
      case "triple":
        runs = 3;
        eventType = "triple";
        commentary = pick([
          `${batsmanName} finds the gap, they run three!`,
          `Excellent running! Three runs taken!`,
          `${batsmanName} pushes it into the deep, they hustle for three!`,
        ]);
        this.swapStrike();
        break;
      case "four":
        runs = 4;
        isBoundary = true;
        eventType = "four";
        commentary = this.fourCommentary(batsmanName, bowlerName);
        break;
      case "six":
        runs = 6;
        isBoundary = true;
        eventType = "six";
        commentary = this.sixCommentary(batsmanName);
        break;
      case "wicket": {
        runs = 0;
        isWicket = true;
        eventType = "wicket";
        wicketType = this.randomWicketType();
        const fielder = this.pickFielder(wicketType, bowler);
        fielderCardId = fielder?.userCardId ?? null;
        const fielderName = fielder?.name;
        commentary = this.wicketCommentary(
          batsmanName,
          bowlerName,
          wicketType,
          fielderName
        );
        break;
      }
      case "wide":
        runs = 1;
        eventType = "wide";
        commentary = pick([
          `Wide ball from ${bowlerName}. Extra run.`,
          `WIDE! ${bowlerName} loses his line.`,
          `That's wide! ${bowlerName} strays down the leg side.`,
        ]);
        this.ballNumber--;
        break;
      case "no_ball":
        runs = 1;
        eventType = "no_ball";
        commentary = pick([
          `No ball! Free hit coming up.`,
          `NO BALL! ${bowlerName} oversteps!`,
          `That's a no ball! Extra delivery.`,
        ]);
        this.ballNumber--;
        break;
      default:
        runs = 0;
        eventType = "dot_ball";
        commentary = "Dot ball.";
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

    if (!this.isFirstInnings && this.score2 > this.target) {
      this.matchComplete = true;
    }

    const result: BallResult = {
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

    // Update stats
    this.updateStats(result, batsmanName, bowlerName);

    return result;
  }

  private updateStats(
    result: BallResult,
    batsmanName: string,
    bowlerName: string
  ) {
    if (result.eventType === "innings_break") return;

    const isExtra =
      result.eventType === "wide" || result.eventType === "no_ball";
    const batKey = `${result.innings}_${result.batsmanCardId}`;
    const bowlKey = `${result.innings}_${result.bowlerCardId}`;

    if (!this.batsmanStats[batKey]) {
      this.batsmanStats[batKey] = {
        name: batsmanName,
        innings: result.innings,
        runs: 0,
        balls: 0,
        fours: 0,
        sixes: 0,
        isOut: false,
        dismissalType: null,
      };
    }
    const bat = this.batsmanStats[batKey];
    if (result.eventType !== "wide") bat.balls++;
    bat.runs += result.runs;
    if (result.runs === 4) bat.fours++;
    if (result.runs === 6) bat.sixes++;
    if (result.isWicket) {
      bat.isOut = true;
      bat.dismissalType = this.formatDismissal(
        result.wicketType ?? "bowled",
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

  private formatDismissal(
    wicketType: string,
    bowlerName: string,
    fielderName: string | null
  ): string {
    switch (wicketType) {
      case "bowled":
        return `b ${bowlerName}`;
      case "caught":
        return `c ${fielderName ?? "fielder"} b ${bowlerName}`;
      case "caught_behind":
        return `c ${fielderName ?? "†keeper"} b ${bowlerName}`;
      case "lbw":
        return `lbw b ${bowlerName}`;
      case "run_out":
        return `run out (${fielderName ?? "fielder"})`;
      case "stumped":
        return `st ${fielderName ?? "†keeper"} b ${bowlerName}`;
      default:
        return `b ${bowlerName}`;
    }
  }

  private endInnings(): BallResult | null {
    this.target = this.score1;

    let endOver: number, endBall: number;
    if (this.ballNumber === 1 && this.overNumber > 0) {
      endOver = this.overNumber;
      endBall = 0;
    } else {
      endOver = this.overNumber;
      endBall = this.ballNumber > 0 ? this.ballNumber - 1 : 0;
    }

    const lastBatsmanId =
      this.currentBatting[this.currentBatsmanIndex].userCardId;
    const lastBowlerId =
      this.currentBowling[this.currentBowlerIndex % this.currentBowling.length]
        .userCardId;

    this.innings = 2;
    this.overNumber = 0;
    this.ballNumber = 0;
    this.currentBatting = this.battingOrder2;
    this.currentBowling = this.bowlingOrder1;
    this.currentBatsmanIndex = 0;
    this.nonStrikerIndex = 1;
    this.nextBatsmanIndex = 2;
    this.currentBowlerIndex = 0;

    return {
      innings: 1,
      overNumber: endOver,
      ballNumber: endBall,
      batsmanCardId: lastBatsmanId,
      bowlerCardId: lastBowlerId,
      eventType: "innings_break",
      runs: 0,
      isBoundary: false,
      isWicket: false,
      wicketType: null,
      fielderCardId: null,
      commentary: `End of first innings. Score: ${this.score1}/${this.wickets1}. Target: ${this.target + 1}`,
      scoreAfter: this.score1,
      wicketsAfter: this.wickets1,
    };
  }

  getMatchResult(): string {
    const battingFirstName = this.homeBatsFirst
      ? this.homeTeamName
      : this.awayTeamName;
    const battingSecondName = this.homeBatsFirst
      ? this.awayTeamName
      : this.homeTeamName;
    if (this.score2 > this.score1) {
      return `${battingSecondName} wins by ${10 - this.wickets2} wickets!`;
    } else if (this.score1 > this.score2) {
      return `${battingFirstName} wins by ${this.score1 - this.score2} runs!`;
    }
    return "Match tied!";
  }

  private calculateOutcome(
    battingRating: number,
    bowlingRating: number,
    chemistry: number
  ): string {
    let dotProb = 0.35;
    let singleProb = 0.3;
    let doubleProb = 0.1;
    let tripleProb = 0.02;
    let fourProb = 0.1;
    let sixProb = 0.04;
    let wicketProb = 0.05;
    let wideProb = 0.02;
    let noBallProb = 0.02;

    const batMod = (battingRating - 50) / 200;
    fourProb += batMod * 0.08;
    sixProb += batMod * 0.04;
    singleProb += batMod * 0.05;
    dotProb -= batMod * 0.1;
    wicketProb -= batMod * 0.04;

    const bowlMod = (bowlingRating - 50) / 200;
    dotProb += bowlMod * 0.1;
    wicketProb += bowlMod * 0.06;
    fourProb -= bowlMod * 0.06;
    sixProb -= bowlMod * 0.03;
    singleProb -= bowlMod * 0.04;

    const chemMod = chemistry / 500;
    fourProb += chemMod * 0.02;
    sixProb += chemMod * 0.01;
    wicketProb -= chemMod * 0.02;

    switch (this.pitchCondition) {
      case "batting_friendly":
        fourProb += 0.04;
        sixProb += 0.02;
        wicketProb -= 0.02;
        break;
      case "bowling_friendly":
        wicketProb += 0.03;
        dotProb += 0.05;
        fourProb -= 0.03;
        sixProb -= 0.02;
        break;
      case "spin_friendly":
        wicketProb += 0.02;
        dotProb += 0.03;
        break;
      case "seam_friendly":
        wicketProb += 0.02;
        fourProb -= 0.02;
        break;
    }

    dotProb = clamp(dotProb, 0.05, 0.6);
    singleProb = clamp(singleProb, 0.1, 0.45);
    doubleProb = clamp(doubleProb, 0.02, 0.2);
    tripleProb = clamp(tripleProb, 0.005, 0.05);
    fourProb = clamp(fourProb, 0.02, 0.25);
    sixProb = clamp(sixProb, 0.01, 0.15);
    wicketProb = clamp(wicketProb, 0.01, 0.15);
    wideProb = clamp(wideProb, 0.01, 0.05);
    noBallProb = clamp(noBallProb, 0.005, 0.03);

    const total =
      dotProb +
      singleProb +
      doubleProb +
      tripleProb +
      fourProb +
      sixProb +
      wicketProb +
      wideProb +
      noBallProb;
    dotProb /= total;
    singleProb /= total;
    doubleProb /= total;
    tripleProb /= total;
    fourProb /= total;
    sixProb /= total;
    wicketProb /= total;
    wideProb /= total;
    noBallProb /= total;

    const roll = Math.random();
    let cum = 0;
    cum += dotProb;
    if (roll < cum) return "dot";
    cum += singleProb;
    if (roll < cum) return "single";
    cum += doubleProb;
    if (roll < cum) return "double";
    cum += tripleProb;
    if (roll < cum) return "triple";
    cum += fourProb;
    if (roll < cum) return "four";
    cum += sixProb;
    if (roll < cum) return "six";
    cum += wicketProb;
    if (roll < cum) return "wicket";
    cum += wideProb;
    if (roll < cum) return "wide";
    return "no_ball";
  }

  private swapStrike() {
    const temp = this.currentBatsmanIndex;
    this.currentBatsmanIndex = this.nonStrikerIndex;
    this.nonStrikerIndex = temp;
  }

  private advanceBatsman() {
    if (this.nextBatsmanIndex < this.currentBatting.length) {
      this.currentBatsmanIndex = this.nextBatsmanIndex;
      this.nextBatsmanIndex++;
    }
  }

  private randomWicketType(): string {
    return pick([
      "bowled",
      "caught",
      "lbw",
      "run_out",
      "stumped",
      "caught_behind",
    ]);
  }

  private pickFielder(
    wicketType: string,
    bowler: Player
  ): Player | null {
    if (wicketType === "bowled" || wicketType === "lbw") return null;
    const allFielders = this.isFirstInnings
      ? this.homeBatsFirst
        ? this.awayXI
        : this.homeXI
      : this.homeBatsFirst
        ? this.homeXI
        : this.awayXI;
    if (wicketType === "caught_behind" || wicketType === "stumped") {
      const keepers = allFielders.filter(
        (p) => p.role === "wicket_keeper"
      );
      if (keepers.length > 0) return keepers[Math.floor(Math.random() * keepers.length)];
    }
    const candidates = allFielders.filter(
      (p) => p.userCardId !== bowler.userCardId
    );
    if (candidates.length === 0)
      return allFielders[Math.floor(Math.random() * allFielders.length)];
    return candidates[Math.floor(Math.random() * candidates.length)];
  }

  // ─── Commentary generators ────────────────────────────────────────

  private dotCommentary(batsman: string, bowler: string): string {
    return pick([
      `${bowler} keeps it tight, dot ball.`,
      `Good length from ${bowler}, ${batsman} defends solidly.`,
      `Beaten! ${bowler} just misses the edge.`,
      `${batsman} leaves it alone, good judgement.`,
      `Tight line from ${bowler}, no run.`,
      `${batsman} blocks it back to ${bowler}.`,
      `Dot ball. ${bowler} builds the pressure.`,
      `Solid defense from ${batsman}, no run.`,
      `${bowler} on target, ${batsman} can't get it away.`,
      `Past the outside edge! Close call!`,
    ]);
  }

  private fourCommentary(batsman: string, bowler: string): string {
    return pick([
      `${batsman} punches it through cover for FOUR!`,
      `FOUR! ${batsman} drives beautifully past mid-off!`,
      `Pulled away for FOUR! ${batsman} is in command.`,
      `Cut shot for FOUR! ${batsman} finds the gap.`,
      `FOUR through the legs! ${bowler} won't like that.`,
      `Swept fine for FOUR! Excellent placement by ${batsman}.`,
      `FOUR! ${batsman} finds the boundary with a cracking shot!`,
      `Glorious cover drive! That races to the fence!`,
      `Driven through the covers, FOUR!`,
      `${batsman} flicks it off his pads for FOUR!`,
    ]);
  }

  private sixCommentary(batsman: string): string {
    return pick([
      `SIX! ${batsman} launches it into the stands!`,
      `MASSIVE SIX! ${batsman} clears the boundary with ease!`,
      `That's gone all the way! SIX by ${batsman}!`,
      `SIX! ${batsman} deposits it into the crowd!`,
      `What a hit! ${batsman} muscles it for SIX!`,
      `HIGH AND HANDSOME! SIX runs!`,
      `${batsman} absolutely smashes it for SIX!`,
      `Out of the ground! What a strike from ${batsman}!`,
      `SIX! ${batsman} clears the ropes with ease!`,
      `MAXIMUM! ${batsman} with a colossal hit!`,
    ]);
  }

  private wicketCommentary(
    batsman: string,
    bowler: string,
    wicketType: string,
    fielderName?: string
  ): string {
    switch (wicketType) {
      case "bowled":
        return pick([
          `BOWLED! ${bowler} knocks over the stumps! ${batsman} is gone!`,
          `Timber! ${bowler} cleans up ${batsman}! What a delivery!`,
          `BOWLED! ${bowler} crashes through the defense!`,
          `Through the gate! ${bowler} gets his man!`,
        ]);
      case "caught": {
        const c = fielderName ?? "fielder";
        return pick([
          `CAUGHT! ${batsman} edges it and ${c} takes a sharp catch! ${bowler} strikes!`,
          `OUT! Caught by ${c}! ${bowler} gets the wicket of ${batsman}!`,
          `Gone! ${batsman} skies it to ${c}, c ${c} b ${bowler}!`,
          `CAUGHT! ${c} takes a brilliant catch! ${batsman} is gone!`,
        ]);
      }
      case "caught_behind": {
        const k = fielderName ?? "†keeper";
        return pick([
          `CAUGHT BEHIND! ${batsman} nicks it and ${k} takes a clean catch!`,
          `Edge and taken! ${k} snaps it up, ${batsman} has to go!`,
          `Feather edge! ${k} takes a sharp catch behind the stumps!`,
        ]);
      }
      case "lbw":
        return pick([
          `LBW! ${bowler} traps ${batsman} plumb in front! Given out!`,
          `OUT! LBW! That was crashing into the stumps. ${batsman} walks back!`,
          `PLUMB! That's hitting middle stump! ${batsman} has to go!`,
          `TRAPPED! ${batsman} is gone LBW! ${bowler} strikes!`,
        ]);
      case "run_out": {
        const t = fielderName ?? "fielder";
        return pick([
          `RUN OUT! Direct hit by ${t}! ${batsman} is short of the crease!`,
          `Gone! Brilliant throw from ${t} catches ${batsman} short!`,
          `RUN OUT! ${t} with a rocket throw! ${batsman} can't make it!`,
        ]);
      }
      case "stumped": {
        const sk = fielderName ?? "†keeper";
        return pick([
          `STUMPED! ${batsman} dances down and ${sk} whips the bails off!`,
          `OUT! Quick work by ${sk}! ${batsman} stumped off ${bowler}!`,
          `STUMPED! Lightning work by ${sk}! ${batsman} is out!`,
        ]);
      }
      default:
        return `OUT! ${bowler} strikes! ${batsman} has to walk back.`;
    }
  }
}

// ─── Utilities ──────────────────────────────────────────────────────

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, v));
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function oversDisplay(balls: number): string {
  return `${Math.floor(balls / 6)}.${balls % 6}`;
}

// ─── Edge Function Handler ──────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    // Authenticate caller
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { match_id } = await req.json();
    if (!match_id) {
      return new Response(
        JSON.stringify({ error: "match_id required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Load match
    const { data: match, error: matchError } = await supabase
      .from("multiplayer_matches")
      .select("*")
      .eq("id", match_id)
      .single();

    if (matchError || !match) {
      return new Response(
        JSON.stringify({ error: "Match not found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Verify participant
    if (match.home_user_id !== user.id && match.away_user_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Not a participant" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Prevent duplicate simulation — only 'waiting' or 'in_progress' allowed
    if (match.status === "completed" || match.status === "simulating") {
      return new Response(
        JSON.stringify({ error: "Match already " + match.status }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const maxOvers = match.match_overs ?? 20;
    const homeBatsFirst = match.home_bats_first ?? true;
    const homeTeamName = match.home_team_name ?? "Home";
    const awayTeamName = match.away_team_name ?? "Away";

    // Load both teams' playing XIs (using service role — bypasses RLS)
    const homeXI = await loadTeamXI(supabase, match.home_team_id);
    const awayXI = await loadTeamXI(supabase, match.away_team_id);
    const homeChemistry = match.home_chemistry ?? 50;
    const awayChemistry = match.away_chemistry ?? 50;

    // Mark match as simulating
    await supabase
      .from("multiplayer_matches")
      .update({ status: "in_progress" })
      .eq("id", match_id);

    console.log(`Starting simulation for match ${match_id}, overs: ${maxOvers}, homeBatsFirst: ${homeBatsFirst}`);
    console.log(`HomeXI: ${homeXI.length} players, AwayXI: ${awayXI.length} players`);

    // Create engine
    const engine = new MatchEngine(
      homeXI,
      awayXI,
      homeChemistry,
      awayChemistry,
      maxOvers,
      match.pitch_condition ?? "balanced",
      homeTeamName,
      awayTeamName,
      homeBatsFirst
    );

    // ─── Ball-by-ball simulation with DB pushes ─────────────────────
    let ballCount = 0;
    const commentaryLog: Array<{commentary: string; eventType: string; runs: number; innings: number; oversDisplay: string}> = [];
    try {
    while (!engine.matchComplete) {
      const result = engine.simulateNextBall();
      if (!result) break;
      ballCount++;

      // Compute home/away scores from engine state
      const hScore = homeBatsFirst ? engine.score1 : engine.score2;
      const hWickets = homeBatsFirst ? engine.wickets1 : engine.wickets2;
      const aScore = homeBatsFirst ? engine.score2 : engine.score1;
      const aWickets = homeBatsFirst ? engine.wickets2 : engine.wickets1;

      let batsmanName = "";
      let bowlerName = "";
      if (result.eventType !== "innings_break") {
        batsmanName = engine.getName(result.batsmanCardId);
        bowlerName = engine.getName(result.bowlerCardId);
      }

      // Build overs display values
      const hOversDisplay = homeBatsFirst
        ? (result.innings === 1
            ? `${result.overNumber}.${result.ballNumber}`
            : oversDisplay(engine.innings === 2 ? totalBallsInnings1(engine) : 0))
        : (result.innings === 2
            ? `${result.overNumber}.${result.ballNumber}`
            : "0.0");
      const aOversDisplay = !homeBatsFirst
        ? (result.innings === 1
            ? `${result.overNumber}.${result.ballNumber}`
            : oversDisplay(engine.innings === 2 ? totalBallsInnings1(engine) : 0))
        : (result.innings === 2
            ? `${result.overNumber}.${result.ballNumber}`
            : "0.0");

      // Append to commentary log — pick the batting team's overs
      const battingInInnings1 = homeBatsFirst ? hOversDisplay : aOversDisplay;
      const battingInInnings2 = homeBatsFirst ? aOversDisplay : hOversDisplay;
      const currentOvers = result.innings === 1 ? battingInInnings1 : battingInInnings2;
      commentaryLog.push({
        commentary: result.commentary,
        eventType: result.eventType,
        runs: result.runs,
        innings: result.innings,
        oversDisplay: currentOvers,
      });

      // Push update to DB — both users see this via Realtime
      await supabase
        .from("multiplayer_matches")
        .update({
          home_score: hScore,
          home_wickets: hWickets,
          away_score: aScore,
          away_wickets: aWickets,
          current_innings: result.innings,
          current_commentary: result.commentary,
          home_overs_display: hOversDisplay,
          away_overs_display: aOversDisplay,
          last_event_type: result.eventType,
          last_runs: result.runs,
          target: engine.target,
          home_batsman: batsmanName,
          current_bowler: bowlerName,
          scorecard_data: {
            batsmen: engine.batsmanStats,
            bowlers: engine.bowlerStats,
          },
          commentary_log: commentaryLog,
        })
        .eq("id", match_id);

      // Delay between balls for realtime feel
      await delay(50);

      if (ballCount % 30 === 0) {
        console.log(`Ball ${ballCount}: ${engine.score1}/${engine.wickets1} vs ${engine.score2}/${engine.wickets2}, innings ${engine.innings}`);
      }
    }
    } catch (simError: any) {
      // If simulation crashes mid-way, still mark match completed so it doesn't get stuck
      console.error('Simulation error:', simError.message);
      await supabase
        .from('multiplayer_matches')
        .update({
          status: 'completed',
          match_result: 'Match abandoned due to error',
          current_commentary: 'Match abandoned due to error',
        })
        .eq('id', match_id);
      return new Response(
        JSON.stringify({ error: 'Simulation failed', details: simError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ─── Match complete ─────────────────────────────────────────────
    const hScore = homeBatsFirst ? engine.score1 : engine.score2;
    const aScore = homeBatsFirst ? engine.score2 : engine.score1;
    const hWickets = homeBatsFirst ? engine.wickets1 : engine.wickets2;
    const aWickets = homeBatsFirst ? engine.wickets2 : engine.wickets1;

    let winnerId: string | null = null;
    if (hScore > aScore) winnerId = match.home_user_id;
    else if (aScore > hScore) winnerId = match.away_user_id;

    const matchResult = engine.getMatchResult();

    await supabase
      .from("multiplayer_matches")
      .update({
        status: "completed",
        home_score: hScore,
        home_wickets: hWickets,
        away_score: aScore,
        away_wickets: aWickets,
        match_result: matchResult,
        current_commentary: matchResult,
        winner_user_id: winnerId,
        target: engine.target,
        scorecard_data: {
          batsmen: engine.batsmanStats,
          bowlers: engine.bowlerStats,
        },
      })
      .eq("id", match_id);

    // Award rewards to both users
    for (const uid of [match.home_user_id, match.away_user_id]) {
      if (!uid) continue;
      const isWinner = uid === winnerId;
      const isDraw = winnerId === null;
      const coins = isWinner ? 100 : isDraw ? 50 : 30;
      const xp = isWinner ? 50 : isDraw ? 30 : 20;

      try {
        await supabase.rpc("award_match_rewards", {
          p_user_id: uid,
          p_coins: coins,
          p_xp: xp,
          p_won: isWinner,
        });
      } catch (_) {
        // Fallback: direct update
        try {
          const { data: u } = await supabase
            .from("users")
            .select("coins, xp, matches_played, matches_won")
            .eq("id", uid)
            .single();
          if (u) {
            const newXp = (u.xp ?? 0) + xp;
            const newLevel = Math.min(Math.floor(newXp / 500) + 1, 100);
            await supabase
              .from("users")
              .update({
                coins: (u.coins ?? 0) + coins,
                xp: newXp,
                level: newLevel,
                matches_played: (u.matches_played ?? 0) + 1,
                matches_won: isWinner ? (u.matches_won ?? 0) + 1 : (u.matches_won ?? 0),
                updated_at: new Date().toISOString(),
              })
              .eq("id", uid);
          }
        } catch (_) {}
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        result: matchResult,
        balls: ballCount,
        home_score: `${hScore}/${hWickets}`,
        away_score: `${aScore}/${aWickets}`,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ─── Helpers ────────────────────────────────────────────────────────

function totalBallsInnings1(engine: MatchEngine): number {
  // If we're in innings 2, innings 1 is done — use score/wickets to estimate
  // For simplicity, track via the overNumber when innings ended
  // The engine target being set means innings 1 is done
  return engine.maxOvers * 6; // Conservative: full overs
}

function countBalls(_engine: MatchEngine, _innings: number): number {
  return _engine.maxOvers * 6;
}

async function loadTeamXI(
  supabase: SupabaseClient,
  teamId: string
): Promise<Player[]> {
  try {
    const { data, error } = await supabase
      .from("teams")
      .select(
        "*, squads(*, squad_players(*, user_cards(*, player_cards(*))))"
      )
      .eq("id", teamId)
      .single();

    if (error || !data) return generateFallbackXI();

    const squads = data.squads ?? [];
    // Find active squad or first squad
    const squad =
      squads.find((s: any) => s.is_active) ?? squads[0];
    if (!squad) return generateFallbackXI();

    const players = (squad.squad_players ?? [])
      .filter((sp: any) => sp.is_playing_xi)
      .sort((a: any, b: any) => (a.position ?? 0) - (b.position ?? 0));

    if (players.length === 0) {
      // Fall back to all players in squad
      const allPlayers = squad.squad_players ?? [];
      if (allPlayers.length === 0) return generateFallbackXI();
      return allPlayers.slice(0, 11).map(mapPlayer);
    }

    return players.slice(0, 11).map(mapPlayer);
  } catch (_) {
    return generateFallbackXI();
  }
}

function mapPlayer(sp: any): Player {
  const uc = sp.user_cards ?? sp.user_card;
  const pc = uc?.player_cards ?? uc?.player_card;
  return {
    userCardId: sp.user_card_id ?? uc?.id ?? crypto.randomUUID(),
    name: pc?.player_name ?? "Player",
    role: pc?.role ?? "batsman",
    batting: pc?.batting ?? 50,
    bowling: pc?.bowling ?? 50,
    fielding: pc?.fielding ?? 50,
  };
}

function generateFallbackXI(): Player[] {
  const roles = [
    "batsman",
    "batsman",
    "batsman",
    "batsman",
    "wicket_keeper",
    "all_rounder",
    "all_rounder",
    "bowler",
    "bowler",
    "bowler",
    "bowler",
  ];
  const names = [
    "A. Smith",
    "B. Kumar",
    "C. Williams",
    "D. Sharma",
    "E. Jones",
    "F. Singh",
    "G. Taylor",
    "H. Patel",
    "I. Anderson",
    "J. Khan",
    "K. Brown",
  ];
  return roles.map((role, i) => ({
    userCardId: crypto.randomUUID(),
    name: names[i],
    role,
    batting: role === "bowler" ? 35 : role === "all_rounder" ? 55 : 65,
    bowling: role === "batsman" ? 25 : role === "all_rounder" ? 55 : 70,
    fielding: 50,
  }));
}
