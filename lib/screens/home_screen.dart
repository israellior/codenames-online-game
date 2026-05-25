import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'lobby_screen.dart';
import 'game_board_screen.dart';
import 'settings_screen.dart';
import '../theme/game_theme_provider.dart';
import 'scan_qr_screen.dart';
import '../widgets/fade_slide_route.dart';
import '../services/invitation_service.dart';




import '../widgets/auth_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

final theme = GameThemeProvider.of(context);

    return Scaffold(
      body: Stack(
        children: [
          _Background(colors: theme.background),

          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final data =
                    snapshot.data!.data() as Map<String, dynamic>?;
                final String? currentRoomCode = data?["currentRoom"];

                final String username = data?['username'] ?? 'Player';

                final int wins = data?['wins'] ?? 0;
                final int losses = data?['losses'] ?? 0;
                final int gamesPlayed = data?['gamesPlayed'] ?? 0;

                final int winRate =
                    gamesPlayed == 0 ? 0 : ((wins / gamesPlayed) * 100).round();

                final Map<String, dynamic> recentPlayers =
                    Map<String, dynamic>.from(data?['recentPlayers'] ?? {});

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HomeLogo(),

                          const SizedBox(height: 16),

                          _WelcomeText(username: username),

                          const SizedBox(height: 24),

                          _HomeStatsCard(
                            wins: wins,
                            losses: losses,
                            games: gamesPlayed,
                            winRate: winRate,
                          ),

                          const SizedBox(height: 24),


                          AuthCard(
                            title: "Codename",
                            child: currentRoomCode == null
                                ? _NoRoom(context, uid)
                                : _InRoom(context, currentRoomCode),
                          ),

                          const SizedBox(height: 16),
                          _InvitesCard(uid),

                          if (recentPlayers.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _RecentPlayersSection(
                              recentPlayers: recentPlayers,
                              myRoomCode: currentRoomCode,
                            ),

                          ]

                        ],

                      ),
                    ),
                  ),
                );
              },
            ),
          ),
                    // ⚙️ SETTINGS BUTTON (TOP-RIGHT, SAFE)
          Positioned(
            right: 16,
            child: SafeArea(
              minimum: const EdgeInsets.only(top: 12),
              child: _SettingsButton(
                onPressed: () => _openSettings(context),
              ),
            ),
          ),
        ],
      ),
    );

  }

  // ───────────────────────────────────────────────
  // NOT IN ROOM
  // ───────────────────────────────────────────────
Widget _NoRoom(BuildContext context, String uid) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ElevatedButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            FadeSlideRoute(
              page: const LobbyScreen(createNew: true),
            ),
          );
        },
        style: _primaryButtonStyle(),
        child: const Text("Create Room"),
      ),
      const SizedBox(height: 16),

      ElevatedButton(
        onPressed: () => _showJoinDialog(context, uid),
        style: _primaryButtonStyle(),
        child: const Text("Join Room"),
      ),
      const SizedBox(height: 12),

      // 🔳 NEW: Scan QR
      OutlinedButton.icon(
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text("Scan QR"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          final roomCode = await Navigator.push<String>(
            context,
            FadeSlideRoute(
              page: const ScanQrScreen(),
            ),
          );

          if (roomCode == null || roomCode.isEmpty) return;

          _joinRoomByCode(context, uid, roomCode);
        },
      ),
    ],
  );
}

Future<void> _joinRoomByCode(
  BuildContext context,
  String uid,
  String code,
) async {
  final roomRef =
      FirebaseFirestore.instance.collection('rooms').doc(code);

  final doc = await roomRef.get();
  if (!doc.exists) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Room does not exist")),
      );
    }
    return;
  }

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  final username = userDoc.data()?['username'] ?? 'Player';

  await roomRef.update({
    'players': FieldValue.arrayUnion([
      {
        'id': uid,
        'name': username,
        'isHost': false,
        'role': 'operative',
        'ready': false,
        'team': 'none',
      }
    ])
  });

  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({'currentRoom': code});

  if (!context.mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => LobbyScreen(
        createNew: false,
        roomCode: code,
      ),
    ),
  );
}


  // ───────────────────────────────────────────────
  // JOIN ROOM DIALOG
  // ───────────────────────────────────────────────
  void _showJoinDialog(BuildContext context, String uid) {
    final controller = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: Colors.black.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Join Room",
                style: TextStyle(color: Colors.white),
              ),
              content: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Room Code",
                  labelStyle: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final code =
                              controller.text.trim().toUpperCase();
                          if (code.isEmpty) return;

                          setState(() => loading = true);

                          final roomRef = FirebaseFirestore.instance
                              .collection('rooms')
                              .doc(code);

                          final doc = await roomRef.get();
                          if (!doc.exists) {
                            setState(() => loading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Room does not exist"),
                              ),
                            );
                            return;
                          }

                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .get();

                            final username = userDoc.data()?['username'] ?? 'Player';

                            await roomRef.update({
                              'players': FieldValue.arrayUnion([
                                {
                                  'id': uid,
                                  'name': username, // ✅ REQUIRED
                                  'isHost': false,
                                  'role': 'operative',
                                  'ready': false,
                                  'team': 'none',
                                }
                              ])
                            });

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({'currentRoom': code});

                          if (!context.mounted) return;

                          Navigator.pop(ctx);

                          Navigator.pushReplacement(
                            context,
                            FadeSlideRoute(
                              page: LobbyScreen(
                                createNew: false,
                                roomCode: code,
                              ),
                            ),
                          );
                        },
                  child: loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Text("Join"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ───────────────────────────────────────────────
  // IN ROOM
  // ───────────────────────────────────────────────
  /*Widget _InRoom(
    BuildContext context,
    String roomCode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "You are currently in room",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.75)),
        ),
        const SizedBox(height: 8),
        Text(
          roomCode,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              FadeSlideRoute(
                page: LobbyScreen(
                  createNew: false,
                  roomCode: roomCode,
                ),
              ),
            );
          },
          style: _primaryButtonStyle(),
          child: const Text("Return to Lobby"),
        ),
        const SizedBox(height: 12),

        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    GameBoardScreen(roomCode: roomCode),
              ),
            );
          },
          style: _primaryButtonStyle(),
          child: const Text("Enter Game"),
        ),
        const SizedBox(height: 12),

        OutlinedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LobbyScreen(
                  createNew: false,
                  roomCode: roomCode,
                  autoLeave: true,
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
          ),
          child: const Text("Leave Room"),
        ),
      ],
    );
  }*/

  Widget _InRoom(BuildContext context, String roomCode) {
  final roomRef =
      FirebaseFirestore.instance.collection('rooms').doc(roomCode);

  return StreamBuilder<DocumentSnapshot>(
    stream: roomRef.snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || snapshot.data!.data() == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final data = snapshot.data!.data() as Map<String, dynamic>;
      final String state = data['state'] ?? 'lobby'; // lobby | in_game | game_over

      final bool inGame = state == 'in_game';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "You are currently in room",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.75)),
          ),
          const SizedBox(height: 8),
          Text(
            roomCode,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // 🔁 RETURN BUTTON (dynamic)
          ElevatedButton(
            style: _primaryButtonStyle(),
            onPressed: () {
              if (inGame) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameBoardScreen(roomCode: roomCode),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  FadeSlideRoute(
                    page: LobbyScreen(
                      createNew: false,
                      roomCode: roomCode,
                    ),
                  ),
                );
              }
            },
            child: Text(inGame ? "Return to Game" : "Return to Lobby"),
          ),

          const SizedBox(height: 12),

          // 🚪 LEAVE ROOM
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            onPressed: () =>
                _confirmLeaveRoom(context, roomCode, inGame),
            child: const Text("Leave Room"),
          ),
        ],
      );
    },
  );
}

Future<void> _confirmLeaveRoom(
  BuildContext context,
  String roomCode,
  bool inGame,
) async {
  final title = inGame ? "Leave Game?" : "Leave Room?";
  final message = inGame
      ? "Are you sure?\nYour team will lose automatically."
      : "Are you sure you want to leave the room?";

  final confirmText = inGame ? "Leave Game" : "Leave Room";

  final leave = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      content: Text(
        message,
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmText,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    ),
  );

  if (leave != true || !context.mounted) return;

  // defer navigation one frame (prevents navigator issues)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      FadeSlideRoute(
        page: LobbyScreen(
          createNew: false,
          roomCode: roomCode,
          autoLeave: true,
        ),
      ),
    );
  });
}





Future<void> _leaveRoom(
  BuildContext context,
  String roomCode,
  bool inGame,
) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final roomRef =
      FirebaseFirestore.instance.collection('rooms').doc(roomCode);
  final userRef =
      FirebaseFirestore.instance.collection('users').doc(uid);

  final snap = await roomRef.get();
  if (!snap.exists) {
    await userRef.update({'currentRoom': null});
    return;
  }

  final data = snap.data() as Map<String, dynamic>;
  final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

  final me = players.firstWhere(
    (p) => p['id'] == uid,
    orElse: () => {},
  );

  final myTeam = me['team']; // 'red' | 'blue'

  // 1️⃣ Remove player
  final remaining =
      players.where((p) => p['id'] != uid).toList();

  await roomRef.update({'players': remaining});
  await userRef.update({'currentRoom': null});

  // 2️⃣ If leaving DURING GAME → END GAME
  if (inGame && myTeam != null && myTeam != 'none') {
    final winner = myTeam == 'red' ? 'blue' : 'red';

    await roomRef.update({
      'state': 'game_over',
      'winner': winner,
      'endedBy': 'player_left',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  if (!context.mounted) return;

  Navigator.pushNamedAndRemoveUntil(
    context,
    '/',
    (_) => false,
  );
}



  // ───────────────────────────────────────────────
  // SETTINGS MENU
  // ───────────────────────────────────────────────
  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SettingsItem(
                  icon: Icons.settings,
                  label: "Settings",
                  onTap: () {
                    Navigator.pop(context);
                    final theme = GameThemeProvider.of(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
                _SettingsItem(
                  icon: Icons.logout,
                  label: "Log out",
                  danger: true,
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();

                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (_) => false,
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────
  // BUTTON STYLES
  // ───────────────────────────────────────────────
  ButtonStyle _primaryButtonStyle() =>
      ElevatedButton.styleFrom(
        backgroundColor: Colors.black.withOpacity(0.65),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );

  ButtonStyle _secondaryButtonStyle() =>
      ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.15),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );
}



/* ================= SETTINGS BUTTON ================= */

class _SettingsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SettingsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.settings,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

/* ================= SETTINGS ITEM ================= */

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: danger ? Colors.redAccent : Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color:
                    danger ? Colors.redAccent : Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= BACKGROUND ================= */

class _Background extends StatelessWidget {
  final List<Color> colors;

  const _Background({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: const [
          _Blob(top: -80, left: -60, size: 200),
          _Blob(bottom: -100, right: -80, size: 260),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double? top, left, bottom, right;
  final double size;

  const _Blob({
    this.top,
    this.left,
    this.bottom,
    this.right,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class AppBackgroundHeader extends StatelessWidget {
  const AppBackgroundHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = GameThemeProvider.of(context);

    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Image.asset(
            theme.logoAsset, // 👈 dynamic logo
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}





class _HomeLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = GameThemeProvider.of(context);

    return Center(
      child: Image.asset(
        theme.logoAsset,
        height: 120,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _WelcomeText extends StatelessWidget {
  final String username;

  const _WelcomeText({required this.username});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 18) return "Good afternoon";
    return "Good evening";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "${_greeting()}, $username",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          "Ready to play?",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _HomeStatsCard extends StatelessWidget {
  final int wins;
  final int losses;
  final int games;
  final int winRate;

  const _HomeStatsCard({
    required this.wins,
    required this.losses,
    required this.games,
    required this.winRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: "Wins", value: wins),
          _StatItem(label: "Losses", value: losses),
          _StatItem(label: "Games", value: games),
          _StatItem(label: "Win %", value: winRate),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;

  const _StatItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _RecentPlayerRow extends StatelessWidget {
  final String playerId;
  final Map<String, dynamic> stats;
  final String? myRoomCode;

  const _RecentPlayerRow({
    required this.playerId,
    required this.stats,
    required this.myRoomCode,
  });

  @override
  Widget build(BuildContext context) {
    final together = Map<String, dynamic>.from(stats['together'] ?? {});
    final against = Map<String, dynamic>.from(stats['against'] ?? {});

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(playerId)
          .get(),
      builder: (context, snapshot) {
        final user =
            snapshot.data?.data() as Map<String, dynamic>?;

        final String name = user?['username'] ?? 'Player';
        final String avatarId = user?['avatarId'] ?? 'default';

        final avatar = CircleAvatar(
          radius: 24,
          backgroundImage: AssetImage(avatarAsset(avatarId)),
          backgroundColor: Colors.transparent,
        );


        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              avatar,

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 8),

                    _RelationRow(
                      icon: Icons.groups,
                      label: 'Together',
                      color: Colors.greenAccent,
                      games: together['games'] ?? 0,
                      wins: together['wins'] ?? 0,
                      losses: together['losses'] ?? 0,
                    ),

                    const SizedBox(height: 6),

                    _RelationRow(
                      icon: Icons.sports_kabaddi,
                      label: 'Against',
                      color: Colors.redAccent,
                      games: against['games'] ?? 0,
                      wins: against['wins'] ?? 0,
                      losses: against['losses'] ?? 0,
                    ),
                  ],
                ),
                
              ),
              if (myRoomCode != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      final svc = InvitationService();
                      await svc.sendInvite(
                        toUid: playerId,
                        roomCode: myRoomCode!,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Invitation sent")),
                      );
                    } catch (e) {
                      final msg = e.toString().replaceFirst('Exception: ', '');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    }
                  },
                  child: const Text("Invite"),
                ),

              ],

            ],
          ),
        );
      },
    );
  }
}

  String avatarAsset(String avatarId) {
  switch (avatarId) {
    case 'avatar_1':
      return 'assets/avatars/avatar_1.png';
    case 'avatar_2':
      return 'assets/avatars/avatar_2.png';
    case 'avatar_3':
      return 'assets/avatars/avatar_3.png';
    default:
      return 'assets/avatars/default.png';
  }
}

class _RelationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int games;
  final int wins;
  final int losses;

  const _RelationRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.games,
    required this.wins,
    required this.losses,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),

        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),

        _miniStat('G', games),
        _miniStat('W', wins),
        _miniStat('L', losses),
      ],
    );
  }

  Widget _miniStat(String label, int value) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RecentPlayersSection extends StatefulWidget {
  final Map<String, dynamic> recentPlayers;
  final String? myRoomCode;

  const _RecentPlayersSection({
    required this.recentPlayers,
    required this.myRoomCode,
  });

  @override
  State<_RecentPlayersSection> createState() =>
      _RecentPlayersSectionState();
}

class _RecentPlayersSectionState extends State<_RecentPlayersSection>
    with SingleTickerProviderStateMixin {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      titleWidget: InkWell(
        onTap: () {
          setState(() => expanded = !expanded);
        },
        child: Row(
          children: [
            Expanded(
              child: Text(
                "Recent Players (${widget.recentPlayers.length})",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.expand_more,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: expanded
            ? Column(
                children: widget.recentPlayers.entries
                    .take(5)
                    .map((entry) {
                  return _RecentPlayerRow(
                    playerId: entry.key,
                    stats: entry.value,
                    myRoomCode: widget.myRoomCode,
                  );
                }).toList(),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

Widget _InvitesCard(String uid) {
  final invitesRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('invites');

  return StreamBuilder<QuerySnapshot>(
    stream: invitesRef
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots(),
    builder: (context, snap) {
      // ✅ show the real Firestore error in UI instead of crashing
      if (snap.hasError) {
        return AuthCard(
          title: "Invitations",
          child: Text(
            "Invites error: ${snap.error}",
            style: const TextStyle(color: Colors.redAccent),
          ),
        );
      }

      if (snap.connectionState == ConnectionState.waiting) {
        return const SizedBox.shrink(); // or a small loader
      }

      final docs = snap.data?.docs ?? const [];
      if (docs.isEmpty) return const SizedBox.shrink();

      return AuthCard(
        title: "Invitations (${docs.length})",
        child: Column(
          children: docs.map((d) {
            final data = (d.data() as Map<String, dynamic>?) ?? {};
            final roomCode = (data['roomCode'] ?? '') as String;
            final fromName = (data['fromName'] ?? 'Player') as String;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "$fromName invited you to room $roomCode",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      try {
                        final svc = InvitationService();
                        await svc.declineInvite(toUid: uid, inviteId: d.id);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Decline failed: $e")),
                        );
                      }
                    },
                    child: const Text(
                      "Decline",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final svc = InvitationService();
                        final code = await svc.acceptInvite(inviteId: d.id);
                        if (code == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Invite is no longer valid.")),
                          );
                          return;
                        }
                        Navigator.pushReplacement(
                          context,
                          FadeSlideRoute(
                            page: LobbyScreen(createNew: false, roomCode: code),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Accept failed: $e")),
                        );
                      }
                    },
                    child: const Text("Accept"),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    },
  );
}





