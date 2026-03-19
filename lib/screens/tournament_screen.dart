import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/supabase_service.dart';
import '../models/models.dart';

class TournamentScreen extends ConsumerStatefulWidget {
  const TournamentScreen({super.key});

  @override
  ConsumerState<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends ConsumerState<TournamentScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TOURNAMENTS'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: SupabaseService.getTournaments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tournaments = snapshot.data ?? [];
          if (tournaments.isEmpty) {
            return _buildNoTournaments();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tournaments.length,
            itemBuilder: (context, index) {
              return _buildTournamentCard(tournaments[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildNoTournaments() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 20),
          const Text(
            'No Active Tournaments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for new tournaments',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          // Upcoming tournaments preview
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.schedule, color: AppTheme.accent, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Weekend League',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Starts every Friday at 00:00 UTC',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Requirements: Min. Team Rating 75',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> data) {
    final name = data['name'] ?? 'Tournament';
    final status = data['status'] ?? 'upcoming';
    final entryFee = data['entry_fee'] ?? 0;
    final maxParticipants = data['max_participants'] ?? 0;
    final prizePool = data['prize_pool'] ?? {};
    final format = data['format'] ?? 't20';

    final statusColor = switch (status) {
      'active' => AppTheme.success,
      'registration' => AppTheme.accent,
      'completed' => Colors.white54,
      _ => AppTheme.primary,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            format.toUpperCase(),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTournamentStat('Entry Fee', '$entryFee', Icons.monetization_on),
                    _buildTournamentStat('Players', '$maxParticipants', Icons.people),
                    _buildTournamentStat(
                      '1st Prize',
                      '${prizePool['first'] ?? 'TBD'}',
                      Icons.star,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: status == 'registration' ? () => _joinTournament(data) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                    ),
                    child: Text(
                      status == 'registration'
                          ? 'JOIN TOURNAMENT'
                          : status == 'active'
                              ? 'IN PROGRESS'
                              : 'COMPLETED',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  void _joinTournament(Map<String, dynamic> tournament) {
    final entryFee = tournament['entry_fee'] ?? 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xE61D1E33),
        title: Text('Join ${tournament['name']}?'),
        content: Text('Entry fee: $entryFee coins'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Joined tournament!')),
              );
            },
            child: const Text('JOIN'),
          ),
        ],
      ),
    );
  }
}
