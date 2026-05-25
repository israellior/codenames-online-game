import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/auth_card.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

import 'home_screen.dart';
import 'complete_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/game_theme_provider.dart';
import '../theme/game_theme.dart';



enum AuthStep {
  login,
  completeProfile,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({    super.key,
    this.initialStep = AuthStep.login,});

    final AuthStep initialStep;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

late AuthStep step;
GameTheme _previewTheme = GameTheme.defaultView();

@override
void initState() {
  super.initState();
  step = widget.initialStep;
}

  final phoneController = TextEditingController();
  final otpController = TextEditingController();


  bool loading = false;
  bool codeSent = false;

  String? verificationId;
  String? phoneError;
  String? otpError;

  Timer? _resendTimer;
  int _resendSeconds = 0;

  // ─────────────────────────────
  // Phone normalization (IL)
  // ─────────────────────────────
  String normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('0')) return '+972${digits.substring(1)}';
    if (digits.startsWith('972')) return '+$digits';
    if (input.startsWith('+')) return input;

    return '+972$digits';
  }

  // ─────────────────────────────
  // RESET TO PHONE INPUT
  // ─────────────────────────────
  void _resetToPhoneEntry() {
      if (!mounted) return;
    setState(() {
      codeSent = false;
      verificationId = null;
      otpController.clear();
      otpError = null;
      _resendTimer?.cancel();
      _resendSeconds = 0;
    });
  }

Widget _buildLoginUI() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (codeSent)
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: loading ? null : _resetToPhoneEntry,
          ),
        ),

      Text(
        codeSent
            ? "Enter the code we sent to your phone"
            : "Sign in using your phone or Google",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.8)),
      ),

      const SizedBox(height: 24),

      if (!codeSent) ...[
        _GlassTextField(
          controller: phoneController,
          label: "Phone number",
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          errorText: phoneError,
          onChanged: (_) => setState(() => phoneError = null),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          loading: loading,
          label: "Send code",
          onPressed: sendCode,
        ),
      ],

      if (codeSent) ...[
        _GlassTextField(
          controller: otpController,
          label: "SMS code",
          icon: Icons.lock,
          keyboardType: TextInputType.number,
          errorText: otpError,
          onChanged: (_) => setState(() => otpError = null),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          loading: loading,
          label: "Verify & continue",
          onPressed: verifyCode,
        ),
                Center(
    child: _resendSeconds > 0
        ? Text(
            "Resend code in $_resendSeconds seconds",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          )
        : TextButton(
            onPressed: loading ? null : sendCode,
            child: const Text("Resend code"),
          ),
  ),
      ],



      const SizedBox(height: 32),
      _DividerOr(),
      const SizedBox(height: 24),

      _ProviderButton(
        label: "Continue with Google",
        icon: Icons.g_mobiledata,
        onPressed: () async {
          final user = await AuthService.signInWithGoogle();
          if (user == null) return;

          final isNew = await UserService.ensureUserDoc(user);

          if (!mounted) return;

          if (isNew) {
            setState(() {
              step = AuthStep.completeProfile;
            });
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        },
      ),
    ],
  );
}


  // ─────────────────────────────
  // SEND OTP
  // ─────────────────────────────
  Future<void> sendCode() async {
    if (loading) return;

    setState(() {
      phoneError = null;
      otpError = null;
    });

    final raw = phoneController.text.trim();
    if (raw.isEmpty) {
      setState(() => phoneError = "Please enter your phone number");
      return;
    }

    final phone = normalizePhone(raw);
setState(() => loading = true);

FirebaseAuth.instance.verifyPhoneNumber(
  phoneNumber: phone,
  timeout: const Duration(seconds: 60),

  verificationCompleted: (cred) async {
    if (!mounted) return;
    await _signInWithCredential(cred);
  },

  verificationFailed: (e) {
    if (!mounted) return;
    setState(() {
      loading = false;
      phoneError = e.message ?? "Failed to send code";
    });
  },

  codeSent: (id, _) {
    if (!mounted) return;
    setState(() {
      verificationId = id;
      codeSent = true;
      loading = false;
      _startResendTimer();
    });
  },

  codeAutoRetrievalTimeout: (_) {},
);

  }

  // ─────────────────────────────
  // VERIFY OTP
  // ─────────────────────────────
Future<void> verifyCode() async {
  if (loading || verificationId == null) return;

  setState(() => otpError = null);

  final code = otpController.text.trim();
  if (code.length < 6) {
    setState(() => otpError = "Enter the 6-digit code");
    return;
  }

  setState(() => loading = true);

  try {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId!,
      smsCode: code,
    );

    await _signInWithCredential(cred);
  } catch (_) {
    if (!mounted) return;
    setState(() {
      otpError = "Invalid verification code";
    });
  }
}


  // ─────────────────────────────
  // FINAL SIGN-IN
  // ─────────────────────────────
Future<void> _signInWithCredential(AuthCredential cred) async {
  try {
    debugPrint("AUTH: start signInWithCredential");
    final uc = await FirebaseAuth.instance
        .signInWithCredential(cred)
        .timeout(const Duration(seconds: 20));

    debugPrint("AUTH: signed in, uid=${uc.user?.uid}");

    final user = uc.user!;
    debugPrint("AUTH: start ensureUserDoc");
    final isNew = await UserService.ensureUserDoc(user)
        .timeout(const Duration(seconds: 20));

    debugPrint("AUTH: ensureUserDoc done, isNew=$isNew");

    if (!mounted) return;

    setState(() => loading = false);

    if (isNew) {
      setState(() => step = AuthStep.completeProfile);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  } on TimeoutException {
    if (!mounted) return;
    setState(() {
      loading = false;
      otpError = "Request timed out. Please try again.";
    });
  } catch (e) {
    debugPrint("AUTH: error $e");
    if (!mounted) return;
    setState(() {
      loading = false;
      otpError = "Verification failed: $e";
    });
  }
}



  // ─────────────────────────────
  // RESEND TIMER
  // ─────────────────────────────
  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);

_resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
  if (!mounted) {
    t.cancel();
    return;
  }

  if (_resendSeconds == 0) {
    t.cancel();
  } else {
    setState(() => _resendSeconds--);
  }
});

  }

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Widget _buildLoginContent() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [

      if (codeSent)
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: loading ? null : _resetToPhoneEntry,
          ),
        ),

      Text(
        codeSent
            ? "Enter the code we sent to your phone"
            : "Sign in using your phone or Google",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.8)),
      ),

      const SizedBox(height: 24),

      if (!codeSent) ...[
        _GlassTextField(
          controller: phoneController,
          label: "Phone number",
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          errorText: phoneError,
          onChanged: (_) => setState(() => phoneError = null),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          loading: loading,
          label: "Send code",
          onPressed: sendCode,
        ),
      ],

      if (codeSent) ...[
        _GlassTextField(
          controller: otpController,
          label: "SMS code",
          icon: Icons.lock,
          keyboardType: TextInputType.number,
          errorText: otpError,
          onChanged: (_) => setState(() => otpError = null),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          loading: loading,
          label: "Verify & continue",
          onPressed: verifyCode,
        ),
      ],
    ],
  );
}


  // ─────────────────────────────
  // UI
  // ─────────────────────────────
@override
Widget build(BuildContext context) {
  final themeToUse =
      (step == AuthStep.completeProfile) ? _previewTheme : GameTheme.defaultView();

  return GameThemeProvider(
    theme: themeToUse,
    child: Scaffold(
      body: Stack(
        children: [
          const _Background(),
          //const AppBackgroundHeader(),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔝 LOGO (flow layout)
                      _LoginLogo(),

                      const SizedBox(height: 24),

                      // 🧊 AUTH CARD
                      AuthCard(
                        title: "Sign in",
                        child: step == AuthStep.login
                            ? _buildLoginUI()
                            : _CompleteProfileInline(
                                onThemeChanged: (t) {
                                  setState(() => _previewTheme = t);
                                },
                        onCompleted: () {
                          if (!mounted) return;

                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                          );
                        },

                        ),
                      ),
                    ],
                  ),
                ),
              ),

            ),
          ),
        ],
      ),
    ),
  );
}


}

/* ================= SHARED UI ================= */

class _PrimaryButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
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
          : Text(label),
    );
  }
}


class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.keyboardType,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
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

/* ================= BACKGROUND ================= */

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    final theme = GameThemeProvider.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.background, // ✅ FROM THEME
        ),
      ),
    );
  }
}


class _CompleteProfileInline extends StatefulWidget {
  final VoidCallback onCompleted;
  final ValueChanged<GameTheme> onThemeChanged;

  const _CompleteProfileInline({
    required this.onCompleted,
    required this.onThemeChanged,
  });

  @override
  State<_CompleteProfileInline> createState() => _CompleteProfileInlineState();
}



class _CompleteProfileInlineState extends State<_CompleteProfileInline> {
  final controller = TextEditingController();
  bool loading = false;

  String selectedTheme = 'defaultView'; // 👈 NEW
  String? selectedAvatarId = 'avatar_1';
  String? usernameError;


void _showImageChoiceSheet() {
  _openAvatarPicker();
}



void _openAvatarPicker() {
  showModalBottomSheet(
    context: context,
    builder: (_) => GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.all(16),
      children: List.generate(4, (i) {
        final id = 'avatar_${i + 1}';

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedAvatarId = id;
            });
            Navigator.pop(context);
          },
          child: CircleAvatar(
            backgroundImage:
                AssetImage('assets/avatars/$id.png'),
          ),
        );
      }),
    ),
  );
}




Widget _profileImagePicker() {
  final avatarId = selectedAvatarId ?? 'avatar_1';
  final image = AssetImage('assets/avatars/$avatarId.png');

  return Column(
    children: [
      GestureDetector(
        onTap: _showImageChoiceSheet,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white24,
              backgroundImage: image,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black,
                child: const Icon(
                  Icons.edit,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        "Profile picture",
        style: TextStyle(color: Colors.white70),
      ),
    ],
  );
}







  GameTheme _themeFromSelection(String v) {
  switch (v) {
    case 'red':
      return GameTheme.red();
    case 'blue':
      return GameTheme.blue();
    default:
      return GameTheme.defaultView();
  }
}


Future<void> submit() async {
  final username = controller.text.trim();

  if (username.isEmpty) {
    setState(() => usernameError = "Username is required");
    return;
  }

  setState(() => loading = true);

  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
          'username': username,
          'profileCompleted': true,
          'gameView': selectedTheme,
          'avatarId': selectedAvatarId ?? 'avatar_1',
          'photoUrl': FieldValue.delete(), // ✅ cleanup old data if exists
        });

    if (!mounted) return;
    widget.onCompleted();
  } finally {
    if (mounted) setState(() => loading = false);
  }
}



@override
Widget build(BuildContext context) {
  final previewTheme = _themeFromSelection(selectedTheme);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _profileImagePicker(),
const SizedBox(height: 24),

      Text(
        "Choose a username to continue",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: GameThemeProvider.of(context)
              .textPrimary
              .withOpacity(0.8),
        ),
      ),

      const SizedBox(height: 24),

      _GlassTextField(
        controller: controller,
        label: "Username",
        icon: Icons.person,
        keyboardType: TextInputType.text,
        errorText: usernameError,
        onChanged: (_) {
          if (usernameError != null) {
            setState(() => usernameError = null);
          }
        },
      ),


      const SizedBox(height: 32),

      Text(
        "Choose your default view",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: GameThemeProvider.of(context)
              .textPrimary
              .withOpacity(0.8),
        ),
      ),

      const SizedBox(height: 12),

      RadioListTile<String>(
        value: 'defaultView',
        groupValue: selectedTheme,
        activeColor: GameThemeProvider.of(context).accent,
        title: Text(
          "Neutral",
          style: TextStyle(
            color: GameThemeProvider.of(context).textPrimary,
          ),
        ),
          onChanged: (v) {
            setState(() => selectedTheme = v!);
            widget.onThemeChanged(_themeFromSelection(v!));
          },
        ),

      RadioListTile<String>(
        value: 'red',
        groupValue: selectedTheme,
        activeColor: GameThemeProvider.of(context).accent,
        title: Text(
          "Red Team View",
          style: TextStyle(
            color: GameThemeProvider.of(context).textPrimary,
          ),
        ),
          onChanged: (v) {
            setState(() => selectedTheme = v!);
            widget.onThemeChanged(_themeFromSelection(v!));
          },
        ),

      RadioListTile<String>(
        value: 'blue',
        groupValue: selectedTheme,
        activeColor: GameThemeProvider.of(context).accent,
        title: Text(
          "Blue Team View",
          style: TextStyle(
            color: GameThemeProvider.of(context).textPrimary,
          ),
        ),
          onChanged: (v) {
            setState(() => selectedTheme = v!);
            widget.onThemeChanged(_themeFromSelection(v!));
          },
        ),

      const SizedBox(height: 24),

      ElevatedButton(
        onPressed: loading ? null : submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: GameThemeProvider.of(context).primary,
        ),
        child: loading
            ? const CircularProgressIndicator()
            : const Text("Continue"),
      ),
    ],
  );
}




}

class _LoginLogo extends StatelessWidget {
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







