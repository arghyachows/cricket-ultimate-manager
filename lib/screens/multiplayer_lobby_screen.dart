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
      appBar: AppBar(
        title: const Text('MULTIPLAYER LOBBY'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'SELECT A ROOM',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...state.rooms.map((room) => _buildRoomCard(room)),
                  ],
                ),
    );
  }

  Widget _buildRoomCard(room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.surface,
      child: InkWell(
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _joiningRoomId == room.id
                    ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                    : const Icon(Icons.sports_cricket, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.roomName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Room Code: ${room.roomCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.accent),
            ],
          ),
        ),
      ),
    );
  }
}
