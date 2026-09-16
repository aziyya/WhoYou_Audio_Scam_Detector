import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import '../widgets/app_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _name = '';
  String _email = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();

    String name = '';

    if (doc.exists && (doc['name'] ?? '').toString().isNotEmpty) {
      // ✅ Name already saved in Firestore — use it
      name = doc['name'];
    } else {
      // ✅ No name in Firestore — try Google display name, else fallback to 'no name'
      name = user.displayName ?? 'no name';

      // ✅ Write it to Firestore so it's consistent going forward
      await _firestore.collection('users').doc(user.uid).set(
        {'name': name, 'email': user.email ?? ''},
        SetOptions(merge: true), // merge: true won't overwrite other fields
      );
    }

    setState(() {
      _email = user.email ?? '';
      _name = name;
      _isLoading = false;
    });
  }

  void _showChangeNameDialog() {
    final controller = TextEditingController(text: _name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.person, color: Color.fromARGB(255, 0, 0, 0)),
            SizedBox(width: 8),
            Text(
              'Change Name',
              style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter new name',
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;

              final user = _auth.currentUser;
              if (user == null) return;

              await _firestore.collection('users').doc(user.uid).update({
                'name': newName,
              });
              await user.updateDisplayName(newName);

              setState(() => _name = newName);
              Navigator.pop(context);
              Navigator.pop(context);
              _showPopupMessage(
                context,
                title: 'Name Updated!',
                message: 'Your name has been changed to "$newName".',
                isSuccess: true,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3A6B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock, color: Color.fromARGB(255, 0, 0, 0)),
              SizedBox(width: 8),
              Text(
                'Change Password',
                style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogPasswordField(
                controller: currentController,
                hint: 'Current password',
                obscure: obscureCurrent,
                onToggle: () =>
                    setDialogState(() => obscureCurrent = !obscureCurrent),
              ),
              const SizedBox(height: 12),
              _dialogPasswordField(
                controller: newController,
                hint: 'New password',
                obscure: obscureNew,
                onToggle: () => setDialogState(() => obscureNew = !obscureNew),
              ),
              const SizedBox(height: 12),
              _dialogPasswordField(
                controller: confirmController,
                hint: 'Confirm new password',
                obscure: obscureConfirm,
                onToggle: () =>
                    setDialogState(() => obscureConfirm = !obscureConfirm),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final current = currentController.text;
                final newPass = newController.text;
                final confirm = confirmController.text;

                if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                  _showSnack('Please fill in all fields.');
                  return;
                }
                if (newPass != confirm) {
                  _showSnack('New passwords do not match.');
                  return;
                }
                if (newPass.length < 6) {
                  _showSnack('Password must be at least 6 characters.');
                  return;
                }

                try {
                  final user = _auth.currentUser!;
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: current,
                  );

                  await user.reauthenticateWithCredential(cred);
                  await user.updatePassword(newPass);

                  Navigator.pop(context);
                  Navigator.pop(context);
                  _showPopupMessage(
                    context,
                    title: 'Password Updated!',
                    message: 'Your password has been changed successfully.',
                    isSuccess: true,
                  );
                } on FirebaseAuthException catch (e) {
                  if (e.code == 'wrong-password' ||
                      e.code == 'invalid-credential') {
                    _showSnack('Current password is incorrect.');
                  } else {
                    _showSnack(e.message ?? 'Failed to change password.');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A6B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF5F6FA),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Log Out'),
          ],
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Delete Account'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade400,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action is permanent and cannot be undone. All your data will be deleted.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'Enter your password to confirm',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password.isEmpty) {
                  _showSnack('Please enter your password.');
                  return;
                }

                try {
                  final user = _auth.currentUser!;

                  // Reauthenticate first
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: password,
                  );
                  await user.reauthenticateWithCredential(cred);

                  // Delete Firestore data
                  await _firestore
                      .collection('history')
                      .where('userId', isEqualTo: user.uid)
                      .get()
                      .then((snap) {
                        for (final doc in snap.docs) {
                          doc.reference.delete();
                        }
                      });

                  await _firestore.collection('users').doc(user.uid).delete();

                  // Delete Firebase Auth account
                  await user.delete();

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                } on FirebaseAuthException catch (e) {
                  Navigator.pop(context);
                  if (e.code == 'wrong-password' ||
                      e.code == 'invalid-credential') {
                    _showSnack('Incorrect password.');
                  } else {
                    _showSnack(e.message ?? 'Failed to delete account.');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColor() {
    const colors = [
      Color(0xFF1A3A6B),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
      Color(0xFFE65100),
      Color(0xFFAD1457),
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
    ];
    if (_name.isEmpty) return colors[0];
    return colors[_name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          color: const Color(0xFFF5F6FA),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 20,
            bottom: 12,
          ),
          child: const AppHeader(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: Column(
                children: [
                  const SizedBox(height: 2),

                  // 🔹 Profile Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 8,
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar with edit badge
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    _avatarColor(),
                                    _avatarColor().withOpacity(0.75),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 16,
                                    color: _avatarColor().withOpacity(0.3),
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.transparent,
                                child: Text(
                                  _name.isNotEmpty
                                      ? _name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // GestureDetector(
                            //   onTap: _showChangeNameDialog,
                            //   child: Container(
                            //     padding: const EdgeInsets.all(6),
                            //     decoration: const BoxDecoration(
                            //       color: Colors.white,
                            //       shape: BoxShape.circle,
                            //       boxShadow: [
                            //         BoxShadow(
                            //           color: Colors.black12,
                            //           blurRadius: 4,
                            //         ),
                            //       ],
                            //     ),
                            //     child: const Icon(
                            //       Icons.edit,
                            //       size: 14,
                            //       color: Color(0xFF1A3A6B),
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Name
                        Text(
                          _name.isNotEmpty ? _name : 'No name set',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Email pill badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3A6B).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A3A6B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 🔹 Account Info Card
                  _sectionCard(
                    title: 'Account Information',
                    children: [
                      _infoTile(
                        Icons.person,
                        'Name',
                        _name.isNotEmpty ? _name : '—',
                        onEdit: _showChangeNameDialog,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Settings Card
                  _sectionCard(
                    title: 'Settings',
                    children: [
                      _actionTile(
                        icon: Icons.lock_outline,
                        label: 'Change Password',
                        onTap: _showChangePasswordDialog,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Logout Card
                  _sectionCard(
                    children: [
                      _actionTile(
                        icon: Icons.logout,
                        label: 'Log Out',
                        color: Colors.redAccent,
                        onTap: _showLogoutDialog,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Delete Account Card
                  _sectionCard(
                    children: [
                      _actionTile(
                        icon: Icons.delete_forever,
                        label: 'Delete Account',
                        color: Colors.redAccent,
                        onTap: _showDeleteAccountDialog,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _sectionCard({String? title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  // ✅ Updated _infoTile with optional onEdit pencil icon
  Widget _infoTile(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A3A6B), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // ✅ Show pencil icon only if onEdit is provided
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 18, color: Color(0xFF1A3A6B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Edit name',
            ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF1A3A6B),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showPopupMessage(
    BuildContext context, {
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  size: 50,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
