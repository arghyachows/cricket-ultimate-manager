import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/multiplayer_provider.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

class MultiplayerRoomScreen extends ConsumerStatefulWidget {
  const MultiplayerRoomScreen({super.key});

  @override
  ConsumerState<MultiplayerRoomScreen> createState() => _MultiplayerRoomScreenState();
}

class _MultiplayerRoomScreenState extends ConsumerState<MultiplayerRoomScreen> {
  bool _hasNavigated = false;

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

    // Listen for match start (only once per match)
    ref.listen<MultiplayerState>(multiplayerProvider, (previous, next) {
      if (next.matchStartedId != null && 
          previous?.matchStartedId != next.matchStartedId && 
          !_hasNavigated) {
        _hasNavigated = true;
        final matchId = next.matchStartedId!;
        ref.read(multiplayerProvider.notifier).clearMatchStarted();
        context.push('/multiplayer/match/$matchId').then((_) {
          if (mounted) {
            _hasNavigated = false;
            ref.invalidate(activeMultiplayerMatchProvider);
          }
        });
      }
    });

    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) {
            await ref.read(multiplayerProvider.notifier).leaveRoom();
          }
        },
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.currentRoom?.roomName.toUpperCase() ?? 'LOBBY',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                ),
                Text(
                  state.isConnected ? '● Connected' : '○ Connecting...',
                  style: TextStyle(
                    fontSize: 10,
                    color: state.isConnected ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              if (state.pendingChallenges.isNotEmpty)
                IconButton(
                  icon: Badge(
                    label: Text('${state.pendingChallenges.length}'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  onPressed: () => _showChallengesDialog(context, ref, hasActiveMatch),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.read(multiplayerProvider.notifier).refreshRoom(),
              ),
            ],
            bottom: const TabBar(
              indicatorColor: AppTheme.accent,
              labelColor: AppTheme.accent,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 18),
                      SizedBox(width: 8),
                      Text('PLAYERS'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 18),
                      SizedBox(width: 8),
                      Text('CHAT'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildPlayersTab(context, ref, state, currentUser, hasActiveMatch),
              _buildChatTab(context, ref, state, currentUser),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayersTab(BuildContext context, WidgetRef ref, MultiplayerState state, currentUser, bool hasActiveMatch) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.black.withOpacity(0.2),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                '${state.usersInRoom.length} Players Online',
                style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.usersInRoom.isEmpty
              ? const Center(child: Text('Waiting for players...'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.usersInRoom.length,
                  itemBuilder: (context, index) {
                    final user = state.usersInRoom[index];
                    final isCurrentUser = user.userId == currentUser?.id;
                    return _buildUserCard(context, ref, user, isCurrentUser, hasActiveMatch);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChatTab(BuildContext context, WidgetRef ref, MultiplayerState state, currentUser) {
    final TextEditingController chatController = TextEditingController();
    final ScrollController scrollController = ScrollController();

    // Auto-scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Column(
      children: [
        Expanded(
          child: state.chatMessages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_outlined, size: 48, color: Colors.white10),
                      SizedBox(height: 16),
                      Text('No messages yet. Start the conversation!', style: TextStyle(color: Colors.white24)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = state.chatMessages[index];
                    final isMe = msg.userId == currentUser?.id;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primary : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                          border: Border.all(
                            color: isMe ? AppTheme.accent.withOpacity(0.3) : Colors.white10,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                msg.teamName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              msg.message,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${msg.createdAt.toLocal().hour}:${msg.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: chatController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: AppTheme.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      ref.read(multiplayerProvider.notifier).sendChatMessage(val);
                      chatController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (chatController.text.trim().isNotEmpty) {
                    ref.read(multiplayerProvider.notifier).sendChatMessage(chatController.text);
                    chatController.clear();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(BuildContext context, WidgetRef ref, user, bool isCurrentUser, bool hasActiveMatch) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser ? AppTheme.accent.withOpacity(0.5) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.primaryLight, AppTheme.primary]),
            shape: BoxShape.circle,
            border: Border.all(color: isCurrentUser ? AppTheme.accent : Colors.white24, width: 2),
          ),
          child: Center(
            child: Text(
              user.teamName[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.teamName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrentUser)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(4)),
                child: const Text('YOU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.military_tech, size: 14, color: AppTheme.cardGold),
              const SizedBox(width: 4),
              Text('Level ${user.userLevel}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
        trailing: !isCurrentUser
            ? ElevatedButton(
                onPressed: hasActiveMatch ? null : () => _showChallengeDialog(context, ref, user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(80, 32),
                ),
                child: Text(hasActiveMatch ? 'ACTIVE' : 'CHALLENGE', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              )
            : null,
      ),
    );
  }

  void _showChallengeDialog(BuildContext context, WidgetRef ref, user) {
    int selectedOvers = 5;
    bool sending = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Challenge ${user.teamName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select match duration:', style: TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [5, 10, 20].map((overs) {
                  final isSelected = selectedOvers == overs;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedOvers = overs),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accent : AppTheme.surfaceLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? AppTheme.accent : Colors.white10),
                      ),
                      child: Center(
                        child: Text(
                          '$overs',
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text('Overs', style: TextStyle(fontSize: 10, color: Colors.white38)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Incoming Challenges'),
        content: SizedBox(
          width: double.maxFinite,
          child: state.pendingChallenges.isEmpty 
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No pending challenges', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38)),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: state.pendingChallenges.length,
                itemBuilder: (context, index) {
                  final challenge = state.pendingChallenges[index];
                  final isResponding = respondingId == challenge.id;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${challenge.challengerTeamName ?? "Someone"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'challenged you to a ${challenge.matchOvers} over match',
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: respondingId != null
                                    ? null
                                    : () async {
                                        setDialogState(() => respondingId = challenge.id);
                                        await ref.read(multiplayerProvider.notifier).respondToChallenge(challenge.id, false);
                                        if (context.mounted) Navigator.pop(context);
                                      },
                                child: const Text('DECLINE', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: hasActiveMatch || respondingId != null
                                    ? null
                                    : () async {
                                        setDialogState(() => respondingId = challenge.id);
                                        await ref.read(multiplayerProvider.notifier).respondToChallenge(challenge.id, true);
                                        if (context.mounted) Navigator.pop(context);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: isResponding
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                    : const Text('ACCEPT'),
                              ),
                            ),
                          ],
                        ),
                      ],
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
