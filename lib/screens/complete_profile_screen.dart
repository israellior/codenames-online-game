import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/auth_card.dart';
import 'home_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final controller = TextEditingController();
  bool loading = false;

  Future<void> submit() async {
    final username = controller.text.trim();
    if (username.isEmpty) return;

    setState(() => loading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
          'username': username,
          'profileCompleted': true,
        });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: const [
          _Background(),
          _Content(),
        ],
      ),
    );
  }
}

/* ===================== CONTENT ===================== */

class _Content extends StatefulWidget {
  const _Content();

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  final controller = TextEditingController();
  bool loading = false;

  Future<void> submit(BuildContext context) async {
    final username = controller.text.trim();
    if (username.isEmpty) return;

    setState(() => loading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
          'username': username,
          'profileCompleted': true,
        });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AuthCard(
              title: "Complete profile",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Choose a username to continue",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _GlassTextField(
                    controller: controller,
                    label: "Username",
                    icon: Icons.person,
                  ),

                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: loading ? null : () => submit(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.65),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Continue"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== BACKGROUND ===================== */

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
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
  final double? top;
  final double? left;
  final double? bottom;
  final double? right;
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

/* ===================== GLASS FIELD ===================== */

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

