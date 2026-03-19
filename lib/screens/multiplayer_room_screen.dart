import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/auth_provider.dart';

class MultiplayerRoomScreen extends ConsumerStatefulWidget {
  const MultiplayerRoomScreen({super.key});

  @override
  ConsumerState<MultiplayerRoomScreen> createState() => _MultiplayerRoomScreenState();
}

class _MultiplayerRoomScreenState extends ConsumerState<MultiplayerRoomScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh room data when screen loads
    Future.microtask(() {
      ref.read(multiplayerProvider.notifier).refreshRoom();
      ref.invalidate(activeMultiplayerMatchProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multiplayerProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final activeMatchAsync = ref.watch(activeMultiplayerMatchProvider);
    final activeMatchData = activeMatchAsync.hasValue ? activeMatchAsync.value : null;
    final hasActiveMatch = activeMatchData != null &&
        activeMatchData['status'] != 'completed';

    // Listen for match start
    ref.listen<MultiplayerState>(multiplayerProvider, (previous, next) {
      if (next.matchStartedId != null && previous?.matchStartedId != next.matchStartedId) {
        // Match started, navigate to match screen
        print('Navigating to match: ${next.matchStartedId}');
        final matchId = next.matchStartedId;
        ref.read(multiplayerProvider.notifier).clearMatchStarted();
        
        // Navigate immediately — the match screen handles its own loading state
        context.push('/multiplayer/match/$matchId').then((_) {
          if (mounted) ref.invalidate(activeMultiplayerMatchProvider);
        });
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await ref.read(multiplayerProvider.notifier).leaveRoom();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(state.currentRoom?.roomName ?? 'ROOM'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (state.currentRoom != null) {
                  ref.read(multiplayerProvider.notifier).refreshRoom();
                }
              },
            ),
            if (state.pendingChallenges.isNotEmpty)
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () => _showChallengesDialog(context, ref, hasActiveMatch),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${state.pendingChallenges.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            // Room info banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary.withValues(alpha: 0.6), AppTheme.surface],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people, color: AppTheme.accent, size: 40),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: state.isConnected ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: state.isConnected
                                  ? const SizedBox()
                                  : const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              state.isConnected ? 'LIVE' : 'CONNECTING',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.usersInRoom.length} Players Online',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.isConnected
                        ? 'Challenge other players to a match!'
                        : 'Connecting to room...',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),

            // Users list
            Expanded(
              child: state.usersInRoom.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.white24),
                          SizedBox(height: 16),
                          Text(
                            'No other players in this room yet...',
                            style: TextStyle(color: Colors.white38),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Waiting for players to join...',
                            style: TextStyle(color: Colors.white24, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.usersInRoom.length,
                      itemBuilder: (context, index) {
                        final user = state.usersInRoom[index];
                        final isCurrentUser = user.userId == currentUser?.id;
                        
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _buildUserCard(context, ref, user, isCurrentUser, hasActiveMatch),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, WidgetRef ref, user, bool isCurrentUser, bool hasActiveMatch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isCurrentUser ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrentUser ? AppTheme.accent : Colors.white24,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  user.teamName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.teamName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: AppTheme.cardGold),
                      const SizedBox(width: 4),
                      Text(
                        'Level ${user.userLevel}',
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Challenge button
            if (!isCurrentUser)
              ElevatedButton.icon(
                onPressed: hasActiveMatch
                    ? null
                    : () => _showChallengeDialog(context, ref, user),
                icon: const Icon(Icons.sports_cricket, size: 16),
                label: Text(hasActiveMatch ? 'MATCH IN PROGRESS' : 'CHALLENGE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.shade700,
                  disabledForegroundColor: Colors.white38,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showChallengeDialog(BuildContext context, WidgetRef ref, user) {
    const int selectedOvers = 5;
    bool sending = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Challenge Player'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Challenge ${user.teamName} to a match?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sports_cricket, color: AppTheme.accent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '5 Overs Match',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      setDialogState(() => sending = true);
                      await ref.read(multiplayerProvider.notifier).sendChallenge(
                        user.userId,
                        user.teamId,
                        selectedOvers,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Challenge sent!')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
              ),
              child: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('SEND CHALLENGE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChallengesDialog(BuildContext context, WidgetRef ref, bool hasActiveMatch) {
    final state = ref.read(multiplayerProvider);
    String? respondingId;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Pending Challenges'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.pendingChallenges.length,
            itemBuilder: (context, index) {
              final challenge = state.pendingChallenges[index];
              final isResponding = respondingId == challenge.id;
              
              return Card(
                color: AppTheme.surfaceLight,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Match Challenge',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${challenge.matchOvers} Overs Match',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: respondingId != null
                                ? null
                                : () async {
                                    setDialogState(() => respondingId = challenge.id);
                                    await ref.read(multiplayerProvider.notifier).respondToChallenge(challenge.id, false);
                                    if (context.mounted) Navigator.pop(context);
                                  },
                            child: isResponding
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('DECLINE'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: hasActiveMatch || respondingId != null
                                ? null
                                : () async {
                              setDialogState(() => respondingId = challenge.id);
                              Navigator.pop(context); // Close challenges dialog
                              
                              // Accept challenge — navigation happens via ref.listen when matchStartedId is set
                              await ref.read(multiplayerProvider.notifier).respondToChallenge(challenge.id, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.grey.shade700,
                              disabledForegroundColor: Colors.white38,
                            ),
                            child: Text(hasActiveMatch ? 'MATCH ACTIVE' : 'ACCEPT'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
      ),
    );
  }
}
