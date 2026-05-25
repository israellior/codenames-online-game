import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/user_service.dart';
import 'home_screen.dart';
import 'complete_profile_screen.dart';

class PhoneOtpScreen extends StatefulWidget {
  final String phone;
  final bool linkOnly;

  const PhoneOtpScreen({
    super.key,
    required this.phone,
    this.linkOnly = false,
  });

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final codeController = TextEditingController();
  String? verificationId;
  bool loading = true;

  String normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('0')) {
      return '+972${digits.substring(1)}';
    }
    if (digits.startsWith('972')) {
      return '+$digits';
    }
    if (input.startsWith('+')) {
      return input;
    }
    return '+972$digits';
  }

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  Future<void> _sendCode() async {
    final phoneE164 = normalizePhone(widget.phone);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (cred) async {
        await _signInWithCredential(cred);
      },

      verificationFailed: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? "Failed")));
        Navigator.pop(context);
      },

      codeSent: (id, _) {
        setState(() {
          verificationId = id;
          loading = false;
        });
      },

      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _verifyCode() async {
    if (verificationId == null) return;

    setState(() => loading = true);

    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId!,
      smsCode: codeController.text.trim(),
    );

    await _signInWithCredential(cred);
  }

  Future<void> _signInWithCredential(AuthCredential cred) async {
    final auth = FirebaseAuth.instance;
    UserCredential uc;

    if (widget.linkOnly && auth.currentUser != null) {
      uc = await auth.currentUser!.linkWithCredential(cred);
    } else {
      uc = await auth.signInWithCredential(cred);
    }

    final user = uc.user!;
    final isNew = await UserService.ensureUserDoc(user);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            isNew ? const CompleteProfileScreen() : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify phone")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text("Code sent to ${widget.phone}"),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "SMS code"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : _verifyCode,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Verify"),
            ),
          ],
        ),
      ),
    );
  }
}
