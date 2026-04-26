import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/multiplayer_provider.dart';

class MultiplayerLobbyScreen extends ConsumerStatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  ConsumerState<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends ConsumerState<MultiplayerLobbyScreen> {
  String? _joiningRoomId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(multiplayerProvider.notifier).loadRooms());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multiplayerProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.background,
              AppTheme.primary.withOpacity(0.1),
              AppTheme.background,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              backgroundColor: AppTheme.background.withOpacity(0.8),
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'MULTIPLAYER LOBBY',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
                background: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        Icons.sports_cricket,
                        size: 150,
                        color: AppTheme.accent.withOpacity(0.05),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.green, blurRadius: 8, spreadRadius: 2),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'LIVE ROOMS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            state.isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    ),
                  )
                : state.error != null
                    ? SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Error: ${state.error}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildRoomCard(state.rooms[index]),
                            childCount: state.rooms.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(MultiplayerRoom room) {
    final isJoining = _joiningRoomId == room.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppTheme.surface,
            AppTheme.surfaceLight.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isJoining ? AppTheme.accent : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _joiningRoomId != null
              ? null
              : () async {
                  setState(() => _joiningRoomId = room.id);
                  try {
                    await ref.read(multiplayerProvider.notifier).joinRoom(room.id);
                    final mpState = ref.read(multiplayerProvider);
                    if (mounted && mpState.currentRoom != null && mpState.error == null) {
                      context.push('/multiplayer/room');
                    }
                  } finally {
                    if (mounted) setState(() => _joiningRoomId = null);
                  }
                },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Room Icon/Avatar
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: isJoining
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                          ),
                        )
                      : const Icon(Icons.hub_outlined, color: AppTheme.accent, size: 32),
                ),
                const SizedBox(width: 20),
                // Room Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.roomName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.vpn_key_outlined, size: 14, color: AppTheme.accent.withOpacity(0.7)),
                          const SizedBox(width: 6),
                          Text(
                            'CODE: ${room.roomCode}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.5),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Join Button/Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.accent,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
