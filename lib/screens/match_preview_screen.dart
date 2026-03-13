import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../engine/ai_opponent.dart';

class MatchPreviewScreen extends ConsumerStatefulWidget {
  final String format;
  const MatchPreviewScreen({super.key, required this.format});

  @override
  ConsumerState<MatchPreviewScreen> createState() => _MatchPreviewScreenState();
}

class _MatchPreviewScreenState extends ConsumerState<MatchPreviewScreen>
    with SingleTickerProviderStateMixin {
  static final _rng = Random();
  static const _pitchTypes = [
    'balanced',
    'batting_friendly',
    'bowling_friendly',
    'spin_friendly',
    'seam_friendly',
  ];
  static const _weatherConditions = [
    'clear',
    'cloudy',
    'overcast',
    'humid',
    'windy',
  ];

  late final String _pitchType;
  late final String _weather;
  late final String _aiTeamName;
  late final List<SquadPlayer> _aiXI;
  late final int _aiChemistry;
  late final int _difficulty;

  bool _tossAnimating = false;
  bool _tossComplete = false;
  bool _userWonToss = false;
  String? _tossDecision; // 'bat' or 'bowl'
  bool _homeBatsFirst = true;

  late AnimationController _coinController;
  late Animation<double> _coinAnimation;

  @override
  void initState() {
    super.initState();
    _pitchType = _pitchTypes[_rng.nextInt(_pitchTypes.length)];
    _weather = _weatherConditions[_rng.nextInt(_weatherConditions.length)];
    _difficulty = widget.format == 'odi' ? 4 : 3;
    _aiTeamName = AIOpponent.randomTeamName();
    _aiXI = AIOpponent.generateXI(difficulty: _difficulty);
    _aiChemistry = AIOpponent.randomChemistry();

    _coinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _coinAnimation = CurvedAnimation(parent: _coinController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _coinController.dispose();
    super.dispose();
  }

  void _flipCoin() {
    setState(() => _tossAnimating = true);
    _coinController.forward(from: 0).then((_) {
      setState(() {
        _tossAnimating = false;
        _tossComplete = true;
        _userWonToss = _rng.nextBool();
        if (!_userWonToss) {
          // AI decides — more likely to bat on batting-friendly, bowl on bowling-friendly
          if (_pitchType == 'bowling_friendly' || _pitchType == 'seam_friendly') {
            _tossDecision = 'bowl';
            _homeBatsFirst = true; // AI bowls so user/home bats
          } else {
            _tossDecision = 'bat';
            _homeBatsFirst = false; // AI bats first
          }
        }
      });
    });
  }

  void _chooseToss(String decision) {
    setState(() {
      _tossDecision = decision;
      _homeBatsFirst = decision == 'bat';
    });
  }

  void _startMatch() {
    final teamAsync = ref.read(teamProvider);
    final chemistry = ref.read(chemistryProvider);
    final team = teamAsync.valueOrNull;
    if (team == null) return;

    final squad = team.activeSquad;
    if (squad == null) return;

    ref.read(matchProvider.notifier).startMatch(
      homeXI: squad.playingXI,
      awayXI: _aiXI,
      homeTeamId: team.id,
      awayTeamId: 'ai',
      homeChemistry: chemistry,
      awayChemistry: _aiChemistry,
      homeTeamName: team.teamName,
      awayTeamName: _aiTeamName,
      format: widget.format,
      pitchCondition: _pitchType,
      weatherCondition: _weather,
      userWonToss: _userWonToss,
      tossDecision: _tossDecision ?? 'bat',
      homeBatsFirst: _homeBatsFirst,
    );

    context.go(AppConstants.liveMatchRoute);
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('${widget.format.toUpperCase()} PREVIEW')),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (team) {
          if (team == null) return const Center(child: Text('No team found'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Match-up header
              _buildMatchUp(team.teamName, _aiTeamName),
              const SizedBox(height: 16),

              // Conditions card
              _buildConditionsCard(),
              const SizedBox(height: 20),

              // Toss section
              _buildTossSection(),
              const SizedBox(height: 20),

              // Start match button
              if (_tossDecision != null)
                _buildStartButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchUp(String homeName, String awayName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.5), AppTheme.surface],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            widget.format.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.shield, color: AppTheme.accent, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      homeName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text('(You)',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.smart_toy, color: Colors.redAccent, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      awayName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text('(AI)',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MATCH CONDITIONS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _conditionTile(
                Icons.landscape,
                'Pitch',
                _pitchType.replaceAll('_', ' ').toUpperCase(),
                _pitchColor(_pitchType),
              )),
              const SizedBox(width: 12),
              Expanded(child: _conditionTile(
                _weatherIcon(_weather),
                'Weather',
                _weather.toUpperCase(),
                _weatherColor(_weather),
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _conditionTile(
                Icons.sports_cricket,
                'Format',
                widget.format == 'odi' ? '50 OVERS' : '20 OVERS',
                AppTheme.primaryLight,
              )),
              const SizedBox(width: 12),
              Expanded(child: _conditionTile(
                Icons.speed,
                'Difficulty',
                _difficulty <= 2 ? 'EASY' : _difficulty <= 3 ? 'MEDIUM' : 'HARD',
                _difficulty <= 2
                    ? Colors.greenAccent
                    : _difficulty <= 3
                        ? Colors.orangeAccent
                        : Colors.redAccent,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conditionTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: Colors.white38)),
                Text(value,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTossSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Text(
            'COIN TOSS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 16),

          if (!_tossComplete && !_tossAnimating) ...[
            // Coin toss button
            GestureDetector(
              onTap: _flipCoin,
              child: AnimatedBuilder(
                animation: _coinAnimation,
                builder: (context, child) {
                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.cardGold, AppTheme.cardGold.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.cardGold.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.monetization_on, size: 50, color: Colors.white),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap the coin to toss!',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],

          if (_tossAnimating) ...[
            // Spinning coin animation
            AnimatedBuilder(
              animation: _coinAnimation,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_coinAnimation.value * 6 * 3.14159),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.cardGold, AppTheme.cardGold.withValues(alpha: 0.6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.cardGold.withValues(alpha: 0.4),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.monetization_on, size: 50, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Flipping...',
              style: TextStyle(color: AppTheme.cardGold, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],

          if (_tossComplete && _tossDecision == null) ...[
            // Toss result
            Icon(
              _userWonToss ? Icons.emoji_events : Icons.smart_toy,
              color: _userWonToss ? AppTheme.accent : Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              _userWonToss ? 'YOU WON THE TOSS!' : 'AI WON THE TOSS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _userWonToss ? AppTheme.accent : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),

            if (_userWonToss) ...[
              const Text(
                'Choose to:',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _tossChoiceButton(
                      'BAT FIRST',
                      Icons.sports_cricket,
                      AppTheme.accent,
                      () => _chooseToss('bat'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tossChoiceButton(
                      'BOWL FIRST',
                      Icons.sports_baseball,
                      Colors.redAccent,
                      () => _chooseToss('bowl'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // AI already chose
              const SizedBox(height: 8),
              Text(
                _aiTeamName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'elected to ${_tossDecision ?? "bat"} first',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: (_tossDecision ?? 'bat') == 'bat' ? AppTheme.accent : Colors.redAccent,
                ),
              ),
            ],
          ],

          if (_tossComplete && _tossDecision != null) ...[
            // Decision made
            Icon(
              _tossDecision == 'bat' ? Icons.sports_cricket : Icons.sports_baseball,
              color: _tossDecision == 'bat' ? AppTheme.accent : Colors.redAccent,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              _userWonToss ? 'You chose to $_tossDecision first' : '$_aiTeamName chose to $_tossDecision first',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _homeBatsFirst
                  ? 'You will bat first'
                  : '$_aiTeamName will bat first',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tossChoiceButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _startMatch,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow, size: 24),
            SizedBox(width: 8),
            Text(
              'START MATCH',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Color _pitchColor(String pitch) {
    switch (pitch) {
      case 'batting_friendly': return Colors.greenAccent;
      case 'bowling_friendly': return Colors.redAccent;
      case 'spin_friendly': return Colors.purpleAccent;
      case 'seam_friendly': return Colors.tealAccent;
      default: return Colors.blueAccent;
    }
  }

  IconData _weatherIcon(String weather) {
    switch (weather) {
      case 'clear': return Icons.wb_sunny;
      case 'cloudy': return Icons.cloud;
      case 'overcast': return Icons.cloud_queue;
      case 'humid': return Icons.water_drop;
      case 'windy': return Icons.air;
      default: return Icons.wb_sunny;
    }
  }

  Color _weatherColor(String weather) {
    switch (weather) {
      case 'clear': return Colors.orangeAccent;
      case 'cloudy': return Colors.blueGrey;
      case 'overcast': return Colors.grey;
      case 'humid': return Colors.lightBlue;
      case 'windy': return Colors.cyan;
      default: return Colors.orangeAccent;
    }
  }
}
