import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/player_card_widget.dart';

class PackOpeningScreen extends ConsumerStatefulWidget {
  final String packTypeId;
  const PackOpeningScreen({super.key, required this.packTypeId});

  @override
  ConsumerState<PackOpeningScreen> createState() => _PackOpeningScreenState();
}

class _PackOpeningScreenState extends ConsumerState<PackOpeningScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  bool _packOpened = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packState = ref.watch(packOpeningProvider);
    final packsAsync = ref.watch(packTypesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('PACK OPENING'),
        backgroundColor: Colors.transparent,
      ),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (packs) {
          final pack = packs.where((p) => p.id == widget.packTypeId).firstOrNull;
          if (pack == null) {
            return const Center(child: Text('Pack not found'));
          }

          if (packState.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
                  const SizedBox(height: 16),
                  Text(packState.error!, style: const TextStyle(color: AppTheme.error)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => ref.read(packOpeningProvider.notifier).reset(),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (!_packOpened) {
            return _buildUnopenedPack(pack);
          }

          if (packState.isOpening) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  SizedBox(height: 16),
                  Text('Opening pack...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }

          if (packState.revealedCards.isNotEmpty) {
            return _buildRevealView(packState);
          }

          return _buildUnopenedPack(pack);
        },
      ),
    );
  }

  Widget _buildUnopenedPack(PackType pack) {
    Color packColor = AppTheme.cardBronze;
    if (pack.name.contains('Legend')) packColor = AppTheme.cardLegend;
    else if (pack.name.contains('Elite')) packColor = AppTheme.cardElite;
    else if (pack.name.contains('Gold')) packColor = AppTheme.cardGold;
    else if (pack.name.contains('Silver')) packColor = AppTheme.cardSilver;

    return Center(
      child: GestureDetector(
        onTap: () async {
          setState(() => _packOpened = true);
          await ref.read(packOpeningProvider.notifier).openPack(pack);
        },
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              width: 220,
              height: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [packColor, packColor.withValues(alpha: 0.5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: packColor.withValues(alpha: 0.3 + _glowController.value * 0.4),
                    blurRadius: 20 + _glowController.value * 30,
                    spreadRadius: 5 + _glowController.value * 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard_rounded, size: 80, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(height: 16),
                  Text(
                    pack.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${pack.cardCount} CARDS',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'TAP TO OPEN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRevealView(PackOpeningState packState) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            itemCount: packState.revealedCards.length,
            itemBuilder: (context, index) {
              final card = packState.revealedCards[index];
              final isRevealed = index <= packState.currentRevealIndex;

              return Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: isRevealed ? 1.0 : 0.3,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 400),
                    scale: isRevealed ? 1.0 : 0.8,
                    child: isRevealed
                        ? PlayerCardWidget(
                            playerCard: card.playerCard!,
                            showStats: true,
                            size: CardSize.large,
                          )
                        : Container(
                            width: 200,
                            height: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: AppTheme.surfaceLight,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Center(
                              child: Icon(Icons.help_outline, size: 48, color: Colors.white24),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        // Controls
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!packState.allRevealed) ...[
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(packOpeningProvider.notifier).revealNext(),
                  icon: const Icon(Icons.touch_app),
                  label: const Text('REVEAL NEXT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(packOpeningProvider.notifier).revealAll(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  child: const Text('REVEAL ALL'),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(packOpeningProvider.notifier).reset();
                    context.go(AppConstants.collectionRoute);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('CONTINUE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
