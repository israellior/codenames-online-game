import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/game_theme_provider.dart';
import '../theme/game_theme.dart';

import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  Future<void> _refreshUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (!mounted) return;
    setState(() {});
  }

  String? _newAvatarId;
  String? _usernameError;


  User get user => FirebaseAuth.instance.currentUser!;
  final usernameController = TextEditingController();

  bool savingUsername = false;

  bool get hasGoogle =>
      user.providerData.any((p) => p.providerId == 'google.com');

  bool get hasPhone =>
      user.providerData.any((p) => p.providerId == 'phone');

  String? get googleEmail {
    for (final p in user.providerData) {
      if (p.providerId == 'google.com') {
        return p.email;
      }
    }
    return null;
  }

  String? get phoneNumber {
    for (final p in user.providerData) {
      if (p.providerId == 'phone') {
        return p.phoneNumber;
      }
    }
    return null;
  }


  int get providerCount => user.providerData.length;

  bool get canUnlinkProvider => providerCount > 1;
  //===================================================================================
  // Phone linking flow state
final _phoneController = TextEditingController();
final _otpController = TextEditingController();

StateSetter? _modalSetState;
bool _linkingPhone = false;
bool _codeSent = false;


String? _verificationId;
String? _phoneError;
String? _otpError;

Timer? _resendTimer;
int _resendSeconds = 0;

String normalizePhone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');

  if (digits.startsWith('0')) return '+972${digits.substring(1)}';
  if (digits.startsWith('972')) return '+$digits';
  if (input.startsWith('+')) return input;

  return '+972$digits';
}

Future<void> _sendPhoneLinkCode() async {
  if (_linkingPhone) return;

  final raw = _phoneController.text.trim();
  if (raw.isEmpty) {
    setState(() => _phoneError = "Enter phone number");
    return;
  }

  final phone = normalizePhone(raw);

  // ✅ prove button works
  debugPrint("📲 SEND CODE pressed. phone=$phone");

  setState(() {
    _linkingPhone = true;
    _phoneError = null;
    _otpError = null;
  });

  try {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Sending code to $phone...")),
    );

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (cred) async {
        debugPrint("✅ verificationCompleted (auto) → linking...");

          await user.linkWithCredential(cred);
          await _refreshUser();


        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone connected")),
        );
        Navigator.pop(context);
      },

      verificationFailed: (e) {
        debugPrint("❌ verificationFailed: ${e.code} ${e.message}");
        setState(() {
          _linkingPhone = false;
          _phoneError = e.message ?? e.code;
        });
      },

      codeSent: (id, _) {
        debugPrint("📩 codeSent. verificationId=$id");
        setState(() {
          _verificationId = id;
          _codeSent = true;
          _linkingPhone = false;
          _startResendTimer();
        });
      },

      codeAutoRetrievalTimeout: (_) {
        debugPrint("⏱ codeAutoRetrievalTimeout");
      },
    );
  } catch (e) {
    debugPrint("🔥 verifyPhoneNumber THREW: $e");
    if (!mounted) return;
    setState(() => _linkingPhone = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Phone auth error: $e")),
    );
  }
}


Future<void> _verifyPhoneLinkCode() async {
  if (_verificationId == null) return;

  final code = _otpController.text.trim();
  if (code.length < 6) {
    setState(() => _otpError = "Enter 6-digit code");
    return;
  }

  setState(() => _linkingPhone = true);

  try {
    final cred = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );

  await user.linkWithCredential(cred);
  await _refreshUser();


    if (!mounted) return;
    Navigator.pop(context);
  } catch (_) {
    setState(() {
      _linkingPhone = false;
      _otpError = "Invalid code";
    });
  }
}

void _startResendTimer() {
  _resendTimer?.cancel();
  _resendSeconds = 60;

  _modalSetState?.call(() {}); // initial paint

  _resendTimer = Timer.periodic(
    const Duration(seconds: 1),
    (timer) {
      _resendSeconds--;

      // 🔥 repaint bottom sheet EVERY tick (including 0)
      _modalSetState?.call(() {});

      if (_resendSeconds <= 0) {
        timer.cancel();
      }
    },
  );
}


@override
void dispose() {
  _resendTimer?.cancel();
  _phoneController.dispose();
  _otpController.dispose();
  usernameController.dispose();
  super.dispose();
}

  //===================================================================================



  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  //================================================================================
  Future<void> _unlinkGoogle() async {
  if (!canUnlinkProvider) {
    _showCannotUnlink();
    return;
  }

  try {
    await user.unlink('google.com');
    await _refreshUser();
  } on FirebaseAuthException catch (e) {
    _handleReauthIfNeeded(e);
  }
}

Future<void> _unlinkPhone() async {
  if (!canUnlinkProvider) {
    _showCannotUnlink();
    return;
  }

  try {
    await user.unlink('phone');
    await _refreshUser();
  } on FirebaseAuthException catch (e) {
    _handleReauthIfNeeded(e);
  }
}

void _handleReauthIfNeeded(FirebaseAuthException e) {
  if (e.code == 'requires-recent-login') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Please re-authenticate before unlinking this account",
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? "Auth error")),
    );
  }
}

void _showCannotUnlink() {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Action blocked"),
      content: const Text(
        "You must have at least one login method connected.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("OK"),
        ),
      ],
    ),
  );
}

  //================================================================================

  Future<void> _loadUsername() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data != null && data['username'] != null) {
      usernameController.text = data['username'];
    }
  }

  Future<void> _saveUsername() async {
    final name = usernameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _usernameError = "Username is required";
      });
      return;
    }


    setState(() {
      savingUsername = false;
      _usernameError = null;
    });
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'username': name});

    setState(() => savingUsername = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Username updated")),
    );
  }

void _showProfileImageOptions() {
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
          onTap: () async {
            Navigator.pop(context);
            setState(() {
              _newAvatarId = id;
            });
            await _saveProfileImage();

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

Future<void> _saveProfileImage() async {
  final uid = user.uid;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({
        'avatarId': _newAvatarId,
      });

  setState(() {
    _newAvatarId = null;
  });
}
 

  // ─────────────────────────────────────────────
  // LINK GOOGLE
  // ─────────────────────────────────────────────
  Future<void> _linkGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      final cred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.linkWithCredential(cred);
      await _refreshUser();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  // ─────────────────────────────────────────────
  // LINK PHONE
  // ─────────────────────────────────────────────
void _linkPhone() {
  setState(() {
    _codeSent = false;
    _verificationId = null;
    _phoneError = null;
    _otpError = null;
    _linkingPhone = false;
    _phoneController.clear();
    _otpController.clear();
    _resendTimer?.cancel();
    _resendSeconds = 0;
  });
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black.withOpacity(0.95),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          _modalSetState = setModalState;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _codeSent ? "Enter the code sent to your phone" : "Connect phone number",
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),

                  if (!_codeSent)
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Phone number",
                        errorText: _phoneError,
                      ),
                    ),

                  if (_codeSent)
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "SMS code",
                        errorText: _otpError,
                      ),
                    ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _linkingPhone
                        ? null
                        : () async {
                            if (_codeSent) {
                              await _verifyPhoneLinkCode();
                            } else {
                              await _sendPhoneLinkCode();
                            }
                            // ✅ force bottom sheet UI refresh
                            setModalState(() {});
                          },
                    child: _linkingPhone
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_codeSent ? "Verify" : "Send code"),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _resendSeconds > 0
                        ? Text(
                            "Resend in $_resendSeconds s",
                            style: const TextStyle(color: Colors.white70),
                          )
                        : TextButton(
                            onPressed: _linkingPhone
                                ? null
                                : () async {
                                    await _sendPhoneLinkCode();
                                    setModalState(() {}); // repaint bottom sheet
                                  },
                            child: const Text("Resend code"),
                          ),
                  ),

                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
  _modalSetState = null;
});
}


  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
@override
Widget build(BuildContext context) {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final data = snapshot.data!.data() as Map<String, dynamic>?;
      final view = data?['gameView'] ?? 'blue';

      final theme = switch (view) {
        'red' => GameTheme.red(),
        'blue' => GameTheme.blue(),
        _ => GameTheme.defaultView(), // 👈 neutral
      };

return GameThemeProvider(
  theme: theme,
  child: _SettingsScaffold(
    header: _header(context),

    profileSection: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Profile"),
        _profileImageEditor(data), // 👈 ADD THIS
        _usernameEditor(),
      ],
    ),

    gameViewSection: _gameViewSelector(),

    connectedAccountsSection: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Connected Accounts"),

        _providerTile(
          icon: Icons.g_mobiledata,
          label: googleEmail != null
              ? "Google ($googleEmail)"
              : "Google",
          connected: hasGoogle,
          onTap: _linkGoogle,
          onUnlink: _unlinkGoogle,
        ),

        _providerTile(
          icon: Icons.phone,
          label: phoneNumber ?? "Phone",
          connected: hasPhone,
          onTap: _linkPhone,
          onUnlink: _unlinkPhone,
        ),
      ],
    ),

    accountSection: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Account"),
        _dangerTile(
          icon: Icons.logout,
          label: "Sign out",
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (_) => false,
            );
          },
        ),
      ],
    ),
  ),
);

    },
  );
}



  // ─────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────

Widget _profileImageEditor(Map<String, dynamic>? data) {
  final avatarId = (data?['avatarId'] as String?) ?? 'avatar_1';

  final image = AssetImage('assets/avatars/$avatarId.png');

  return Center(
    child: Column(
      children: [
        GestureDetector(
          onTap: _showProfileImageOptions,
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
                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}




  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        const Text(
          "Settings",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _usernameEditor() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: usernameController,
            style: const TextStyle(color: Colors.white),
            onChanged: (_) {
              if (_usernameError != null) {
                setState(() => _usernameError = null);
              }
            },
            decoration: InputDecoration(
              labelText: "Username",
              errorText: _usernameError,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: savingUsername ? null : _saveUsername,
          child: savingUsername
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Save"),
        ),
      ],
    );
  }

Widget _providerTile({
  required IconData icon,
  required String label,
  required bool connected,
  VoidCallback? onTap,
  VoidCallback? onUnlink,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),

        // 👇 TAP TO VIEW FULL VALUE
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (label.isEmpty) return;

              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Connected account"),
                  content: SelectableText(label),
                ),
              );
            },
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),

        const SizedBox(width: 8),

        connected
            ? TextButton(
                onPressed: onUnlink,
                child: const Text(
                  "Disconnect",
                  style: TextStyle(color: Colors.redAccent),
                ),
              )
            : TextButton(
                onPressed: onTap,
                child: const Text("Connect"),
              ),
      ],
    ),
  );
}



  Widget _dangerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.redAccent),
      title: Text(label,
          style: const TextStyle(color: Colors.redAccent)),
      onTap: onTap,
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

Widget _gameViewSelector() {
  final uid = user.uid;
  final theme = GameThemeProvider.of(context);

  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots(),
    builder: (context, snapshot) {
      final data = snapshot.data?.data() as Map<String, dynamic>?;
      final currentView = data?['gameView'] ?? 'blue';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Game View"),

          RadioListTile<String>(
            value: 'default',
            groupValue: currentView,
            activeColor: theme.accent,
            title: const Text(
              "Neutral View",
              style: TextStyle(color: Colors.white),
            ),
            onChanged: (v) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({'gameView': v});
            },
          ),

          RadioListTile<String>(
            value: 'blue',
            groupValue: currentView,
            activeColor: theme.accent,
            title: const Text(
              "Blue Team View",
              style: TextStyle(color: Colors.white),
            ),
            onChanged: (v) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({'gameView': v});
            },
          ),

          RadioListTile<String>(
            value: 'red',
            groupValue: currentView,
            activeColor: theme.accent,
            title: const Text(
              "Red Team View",
              style: TextStyle(color: Colors.white),
            ),
            onChanged: (v) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({'gameView': v});
            },
          ),
        ],
      );
    },
  );
}


}

class _SettingsScaffold extends StatelessWidget {
  final Widget header;
  final Widget profileSection;
  final Widget gameViewSection;
  final Widget connectedAccountsSection;
  final Widget accountSection;

  const _SettingsScaffold({
    required this.header,
    required this.profileSection,
    required this.gameViewSection,
    required this.connectedAccountsSection,
    required this.accountSection,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = GameThemeProvider.of(context);

    return Scaffold(
      body: Stack(
        children: [
          _Background(color: theme.background),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 👇 we add the logo here
                      _SettingsLogo(),

                      const SizedBox(height: 24),

                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            header,

                            const SizedBox(height: 24),
                            profileSection,

                            const SizedBox(height: 24),
                            gameViewSection,

                            const SizedBox(height: 32),
                            connectedAccountsSection,

                            const SizedBox(height: 32),
                            accountSection,
                          ],
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

    );
  }
}



/* ================= GLASS CARD ================= */

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = GameThemeProvider.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: child,
    );
  }
}

/* ================= BACKGROUND ================= */

class _Background extends StatelessWidget {
  final List<Color> color;

  const _Background({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: color,
        ),
      ),
    );
  }
}



class _SettingsLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = GameThemeProvider.of(context);

    return Center(
      child: Image.asset(
        theme.logoAsset,
        height: 100,
        fit: BoxFit.contain,
      ),
    );
  }
}