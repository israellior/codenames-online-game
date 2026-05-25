import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/auth_providers.dart';

import '../widgets/auth_card.dart';
import '../user_session.dart';
import 'home_screen.dart';
import 'phone_otp_screen.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'complete_profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  bool loading = false;

  String normalizePhone(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  @override
  void dispose() {
    usernameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  /*Future<void> register() async {
    final username = usernameController.text.trim();
    final phone = normalizePhone(phoneController.text);

    if (username.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final users = FirebaseFirestore.instance.collection('users');

      if ((await users.doc(phone).get()).exists) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone already registered")),
        );
        return;
      }

      await users.doc(phone).set({
        'username': username,
        'phone': phone,
        'createdAt': Timestamp.now(),
      });

      currentUserId = phone;
      currentUsername = username;

      setState(() => loading = false);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Register failed: $e")),
      );
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _Background(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AuthCard(
                    title: "Create account",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GlassTextField(
                          controller: usernameController,
                          label: "Username",
                          icon: Icons.person,
                          keyboardType: TextInputType.text,
                        ),

                        const SizedBox(height: 16),

                        _GlassTextField(
                          controller: phoneController,
                          label: "Phone number",
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),

                        const SizedBox(height: 24),

                        /*ElevatedButton(
                          onPressed: loading ? null : register,*/
                          ElevatedButton(
                          onPressed: loading
                              ? null
                              : () {
                                  final phone = normalizePhone(phoneController.text);
                                  if (phone.isEmpty) return;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PhoneOtpScreen(phone: phone),
                                    ),
                                  );
                                },
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
                              : const Text("Register"),
                        ),

                        const SizedBox(height: 24),

                        _DividerOr(),

                        const SizedBox(height: 24),

                        _ProviderButton(
                          label: "Continue with Google",
                          icon: Icons.g_mobiledata,
                          onPressed: () async {
                            try {
                              debugPrint("GOOGLE: tapped");

                              final user = await AuthService.signInWithGoogle();

                              debugPrint("GOOGLE USER: $user");

                              if (user == null) {
                                debugPrint("GOOGLE: user cancelled");
                                return;
                              }

                              debugPrint("GOOGLE UID: ${user.uid}");
                              debugPrint("GOOGLE EMAIL: ${user.email}");

                              final isNew = await UserService.ensureUserDoc(user);
                              debugPrint("IS NEW USER: $isNew");

                              if (!mounted) return;

                              if (isNew) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CompleteProfileScreen(),
                                  ),
                                );
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HomeScreen(),
                                  ),
                                );
                              }
                            } catch (e, s) {
                              debugPrint("GOOGLE SIGN-IN ERROR: $e");
                              debugPrint("$s");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                        ),

                        const SizedBox(height: 12),

                        _ProviderButton(
                          label: "Continue with Apple",
                          icon: Icons.apple,
                          onPressed: () {
                            debugPrint("Apple sign-in tapped");
                          },
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Already have an account? Login",
                            style: TextStyle(color: Colors.white.withOpacity(0.85)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= SHARED UI WIDGETS =================

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

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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

class _DividerOr extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "or",
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.4)),
          backgroundColor: Colors.white.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
