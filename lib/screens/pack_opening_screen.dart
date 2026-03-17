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
  final bool fromInventory;
  const PackOpeningScreen({
    super.key,
    required this.packTypeId,
    this.fromInventory = false,
  });

  @override
  ConsumerState<PackOpeningScreen> createState() => _PackOpeningScreenState();
}

class _PackOpeningScreenState extends ConsumerState<PackOpeningScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  bool _packOpened = false;
  PageController? _pageController;
  int _currentPage = 0;

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
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packState = ref.watch(packOpeningProvider);

    // Inventory packs bypass the store packType lookup entirely
    if (widget.fromInventory) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('PACK OPENING'),
          backgroundColor: Colors.transparent,
        ),
        body: _buildInventoryBody(packState),
      );
    }

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

  Widget _buildInventoryBody(PackOpeningState packState) {
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

    // Fallback — shouldn't normally reach here
    return const Center(child: Text('No cards to reveal'));
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
    // Initialize page controller once when cards are ready
    if (_pageController == null || !_pageController!.hasClients) {
      _pageController?.dispose();
      _pageController = PageController();
      _currentPage = 0;
      // Auto-reveal first card
      if (packState.currentRevealIndex < 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(packOpeningProvider.notifier).revealNext();
        });
      }
    }

    final totalCards = packState.revealedCards.length;
    final revealedCount = packState.currentRevealIndex + 1;

    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalCards, (i) {
              final isRevealed = i <= packState.currentRevealIndex;
              final isCurrent = i == _currentPage;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isCurrent ? 24 : 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: isRevealed
                      ? (isCurrent ? AppTheme.accent : AppTheme.accent.withValues(alpha: 0.5))
                      : Colors.white24,
                ),
              );
            }),
          ),
        ),

        // Card counter
        Text(
          '$revealedCount / $totalCards revealed',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 8),

        // Cards
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalCards,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              // Auto-reveal when user swipes to an unrevealed card
              if (page > packState.currentRevealIndex) {
                // Reveal up to this page
                final notifier = ref.read(packOpeningProvider.notifier);
                for (int i = packState.currentRevealIndex + 1; i <= page; i++) {
                  notifier.revealNext();
                }
              }
            },
            itemBuilder: (context, index) {
              final card = packState.revealedCards[index];
              final isRevealed = index <= packState.currentRevealIndex;

              return Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: isRevealed
                      ? Column(
                          key: ValueKey('revealed_$index'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PlayerCardWidget(
                              playerCard: card.playerCard!,
                              showStats: true,
                              size: CardSize.large,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              card.playerCard!.rarity.toUpperCase(),
                              style: TextStyle(
                                color: AppTheme.getRarityColor(card.playerCard!.rarity),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        )
                      : Container(
                          key: ValueKey('hidden_$index'),
                          width: 200,
                          height: 300,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.surfaceLight,
                                AppTheme.surface,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.help_outline, size: 48, color: Colors.white24),
                              SizedBox(height: 8),
                              Text(
                                'TAP REVEAL\nOR SWIPE',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white24, fontSize: 12),
                              ),
                            ],
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
                  onPressed: () {
                    final notifier = ref.read(packOpeningProvider.notifier);
                    notifier.revealNext();
                    // Navigate to the newly revealed card
                    final nextPage = packState.currentRevealIndex + 1;
                    if (nextPage < totalCards) {
                      _pageController?.animateToPage(
                        nextPage,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  icon: const Icon(Icons.touch_app),
                  label: Text(
                    packState.currentRevealIndex < 0
                        ? 'REVEAL FIRST'
                        : 'REVEAL NEXT',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () {
                    ref.read(packOpeningProvider.notifier).revealAll();
                    // Scroll back to first card so user can swipe through all
                    _pageController?.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  },
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
                    _pageController?.dispose();
                    _pageController = null;
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
