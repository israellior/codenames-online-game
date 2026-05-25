import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'lobby_screen.dart';

class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key});

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final TextEditingController roomController = TextEditingController();
  bool loading = false;

  Future<void> joinRoom() async {
    final code = roomController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;

    setState(() => loading = true);

    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(code);
    final doc = await roomRef.get();

    if (!doc.exists) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Room does not exist")),
      );
      return;
    }

    // Add user to room players
    await roomRef.update({
      'players': FieldValue.arrayUnion([
        {
          'id': uid,
          'isHost': false,
          'role': 'operative',
          'ready': false,
          'team': 'none',
        }
      ])
    });

    // Update CURRENT USER ONLY
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'currentRoom': code});

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          createNew: false,
          roomCode: code,
        ),
      ),
    );

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join room"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Enter Room Code",
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : joinRoom,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Join"),
            ),
          ],
        ),
      ),
    );
  }
}
