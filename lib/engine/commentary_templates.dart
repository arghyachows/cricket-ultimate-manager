import 'dart:math';
import '../models/models.dart';

/// Generates commentary text for dot balls.
String dotCommentary(String batsman, String bowler, Random rng) {
  final options = [
    '$bowler keeps it tight, dot ball.',
    'Good length from $bowler, $batsman defends solidly.',
    'Beaten! $bowler just misses the edge.',
    '$batsman leaves it alone, good judgement.',
    'Tight line from $bowler, no run.',
    '$batsman blocks it back to $bowler.',
    'Dot ball. $bowler builds the pressure.',
    '$batsman shoulders arms, good leave.',
    'Defended watchfully by $batsman.',
    '$bowler beats $batsman with a beauty!',
    'Past the outside edge! Close call!',
    '$batsman plays and misses, lucky to survive!',
    'Solid defense from $batsman, no run.',
    '$bowler on target, $batsman can\'t get it away.',
    'Excellent line from $bowler, dot ball.',
  ];
  return options[rng.nextInt(options.length)];
}

/// Generates commentary text for fours.
String fourCommentary(String batsman, String bowler, Random rng) {
  final options = [
    '$batsman punches it through cover for FOUR!',
    'FOUR! $batsman drives beautifully past mid-off!',
    'Pulled away for FOUR! $batsman is in command.',
    'Cut shot for FOUR! $batsman finds the gap.',
    'FOUR through the legs! $bowler won\'t like that.',
    'Swept fine for FOUR! Excellent placement by $batsman.',
    'FOUR! $batsman finds the boundary with a cracking shot!',
    'Glorious cover drive! That races to the fence!',
    'FOUR! $batsman threads the gap perfectly!',
    'Exquisite timing from $batsman, four runs!',
    'Cut away beautifully for FOUR!',
    '$batsman leans into the drive, FOUR runs!',
    'Pulled away with authority! That\'s a boundary!',
    'FOUR! $batsman finds the rope with ease!',
    'Classy stroke from $batsman, four runs!',
    'Driven through the covers, FOUR!',
    '$batsman flicks it off his pads for FOUR!',
    'Square cut for four! Brilliant shot!',
    'FOUR! $batsman punishes the loose delivery!',
    'That\'s raced away to the boundary! FOUR!',
  ];
  return options[rng.nextInt(options.length)];
}

/// Generates commentary text for sixes.
String sixCommentary(String batsman, Random rng) {
  final options = [
    'SIX! $batsman launches it into the stands!',
    'MASSIVE SIX! $batsman clears the boundary with ease!',
    'That\'s gone all the way! SIX by $batsman!',
    'SIX! $batsman deposits it into the crowd!',
    'What a hit! $batsman muscles it for SIX!',
    'HIGH AND HANDSOME! SIX runs!',
    '$batsman absolutely smashes it for SIX!',
    'Out of the ground! What a strike from $batsman!',
    'SIX! $batsman clears the ropes with ease!',
    'Monstrous hit! That\'s disappeared into the crowd!',
    '$batsman gets under it and sends it sailing for SIX!',
    'BANG! $batsman deposits it over the boundary!',
    'Clean strike! SIX runs to $batsman!',
    '$batsman goes downtown! Maximum!',
    'Incredible power! That\'s a huge SIX!',
    'SIX! $batsman in full flow now!',
    'Into the stands! $batsman with a mighty blow!',
    'That\'s out of here! SIX runs!',
    '$batsman sends it soaring over the ropes!',
    'MAXIMUM! $batsman with a colossal hit!',
  ];
  return options[rng.nextInt(options.length)];
}

/// Generates commentary text for wicket events.
String wicketCommentary(
    String batsman, String bowler, String wicketType, String? fielderName, Random rng) {
  switch (wicketType) {
    case 'bowled':
      final options = [
        'BOWLED! $bowler knocks over the stumps! $batsman is gone!',
        'Timber! $bowler cleans up $batsman! What a delivery!',
        'BOWLED HIM! $batsman\'s stumps are shattered by $bowler!',
        'BOWLED! $bowler crashes through the defense!',
        'Through the gate! $bowler gets his man!',
        'CLEANED UP! $bowler shatters the stumps!',
        'BOWLED! The stumps are in disarray! $batsman departs!',
        'What a ball! $bowler knocks back the off stump!',
      ];
      return options[rng.nextInt(options.length)];
    case 'caught':
      final catcher = fielderName ?? 'fielder';
      final options = [
        'CAUGHT! $batsman edges it and $catcher takes a sharp catch! $bowler strikes!',
        'OUT! Caught by $catcher! $bowler gets the wicket of $batsman!',
        'Gone! $batsman skies it to $catcher, c $catcher b $bowler!',
        'IN THE AIR... and taken! $catcher holds on! $bowler celebrates!',
        'CAUGHT! $catcher takes a brilliant catch! $batsman is gone!',
        'GONE! $catcher pouches it safely! $batsman walks back!',
        'CAUGHT! What a grab by $catcher! $bowler gets the breakthrough!',
        'Edged and taken! $catcher makes no mistake!',
        'OUT! $catcher with a stunning catch! $bowler strikes!',
      ];
      return options[rng.nextInt(options.length)];
    case 'caught_behind':
      final keeper = fielderName ?? 'keeper';
      final options = [
        'CAUGHT BEHIND! $batsman nicks it and $keeper takes a clean catch! c $keeper b $bowler!',
        'Edge and taken! $keeper snaps it up, $batsman has to go! c $keeper b $bowler!',
        'CAUGHT BEHIND! $keeper with the gloves does the rest!',
        'Feather edge! $keeper takes a sharp catch behind the stumps!',
        'GONE! $keeper pouches it cleanly! c $keeper b $bowler!',
      ];
      return options[rng.nextInt(options.length)];
    case 'lbw':
      final options = [
        'LBW! $bowler traps $batsman plumb in front! Given out!',
        'OUT! LBW! That was crashing into the stumps. $batsman walks back!',
        'PLUMB! That\'s hitting middle stump! $batsman has to go!',
        'OUT LBW! $bowler gets his man! Dead in front!',
        'TRAPPED! $batsman is gone LBW! $bowler strikes!',
        'LBW! No doubt about that one! $batsman departs!',
        'STONE DEAD! $bowler gets the LBW decision!',
        'OUT! That\'s as plumb as they come! LBW!',
      ];
      return options[rng.nextInt(options.length)];
    case 'run_out':
      final thrower = fielderName ?? 'fielder';
      final options = [
        'RUN OUT! Direct hit by $thrower! $batsman is short of the crease!',
        'Gone! Brilliant throw from $thrower catches $batsman short!',
        'RUN OUT! Brilliant work by $thrower! $batsman is gone!',
        'DIRECT HIT! $thrower finds the stumps! $batsman is short!',
        'RUN OUT! $thrower with a rocket throw! $batsman can\'t make it!',
        'OUT! Superb fielding from $thrower! $batsman is run out!',
        'RUN OUT! $thrower hits the target! $batsman is well short!',
      ];
      return options[rng.nextInt(options.length)];
    case 'stumped':
      final keeper = fielderName ?? 'keeper';
      final options = [
        'STUMPED! $batsman dances down the pitch and $keeper whips the bails off! st $keeper b $bowler!',
        'OUT! Quick work by $keeper! $batsman stumped off $bowler!',
        'STUMPED! Lightning work by $keeper! $batsman is out!',
        'STUMPED! $keeper whips off the bails! $batsman is gone!',
        'OUT STUMPED! Quick hands from $keeper! $batsman departs!',
        'STUMPED! $batsman is caught out of his crease! Brilliant keeping!',
      ];
      return options[rng.nextInt(options.length)];
    default:
      return 'OUT! $bowler strikes! $batsman has to walk back.';
  }
}
