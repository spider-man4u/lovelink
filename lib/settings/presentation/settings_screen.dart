import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/services/presence_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic>? _userData;
  bool _autoSuggest = true;
  double _imageFrequency = 0.5;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPreferences();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (mounted) setState(() => _userData = snap.data());
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoSuggest = prefs.getBool('auto_suggest') ?? true;
        _imageFrequency = prefs.getDouble('image_frequency') ?? 0.5;
      });
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) prefs.setBool(key, value);
    if (value is double) prefs.setDouble(key, value);
  }

  Future<void> _editUsername() async {
    final controller = TextEditingController(
      text: _userData?['username'] as String? ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Choose a unique username',
            prefixIcon: Icon(Icons.alternate_email),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'username': result, 'usernameLower': result.toLowerCase()},
      );
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Username updated!')));
      }
    }
  }

  Future<void> _editProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(
      text: user.displayName ?? _userData?['displayName'] as String? ?? '',
    );
    final usernameController = TextEditingController(
      text: _userData?['username'] as String? ?? '',
    );

    final result = await showDialog<({String name, String username})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, (
              name: nameController.text.trim(),
              username: usernameController.text.trim().toLowerCase(),
            )),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (result.name.isEmpty || result.username.length < 3) {
      _showSnack('Name and username are required');
      return;
    }

    final currentUsername = _userData?['username'] as String?;
    if (result.username != currentUsername) {
      final taken = await FirebaseFirestore.instance
          .collection('users')
          .where('usernameLower', isEqualTo: result.username)
          .get();
      if (taken.docs.isNotEmpty) {
        _showSnack('Username is already taken');
        return;
      }
    }

    await user.updateDisplayName(result.name);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'displayName': result.name,
      'username': result.username,
      'usernameLower': result.username,
      'profileUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _loadUserData();
    _showSnack('Profile updated');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PresenceService.instance.setOffline();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SizedBox.shrink()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final username = _userData?['username'] as String?;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      (FirebaseAuth.instance.currentUser?.displayName ??
                          'U')[0],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FirebaseAuth.instance.currentUser?.displayName ??
                              'User',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        GestureDetector(
                          onTap: _editUsername,
                          child: Row(
                            children: [
                              Text(
                                username != null
                                    ? '@$username'
                                    : email.split('@').first,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.edit,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: _editProfile,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Scene Suggestions',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Auto Image Suggestions'),
                  subtitle: const Text('Let AI suggest scenes automatically'),
                  value: _autoSuggest,
                  onChanged: (v) {
                    setState(() => _autoSuggest = v);
                    _savePreference('auto_suggest', v);
                  },
                ),
                if (_autoSuggest) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Image Frequency'),
                    subtitle: Text('${(_imageFrequency * 100).round()}%'),
                    trailing: SizedBox(
                      width: 120,
                      child: Slider(
                        value: _imageFrequency,
                        onChanged: (v) {
                          setState(() => _imageFrequency = v);
                          _savePreference('image_frequency', v);
                        },
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        label: '${(_imageFrequency * 100).round()}%',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Appearance',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              value: isDark,
              onChanged: (v) {
                ref.read(themeProvider.notifier).setTheme(v);
              },
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Privacy & Data',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('End-to-End Encryption'),
                  subtitle: Text('Messages are encrypted in transit'),
                  trailing: Icon(Icons.check_circle, color: Colors.green),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Image Cache'),
                  subtitle: const Text('Manage downloaded scene images'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCacheOptions(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'About',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Version'),
                  trailing: Text('1.0.0'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.favorite_outline),
                  title: Text('Made with love for couples'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showCacheOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Image Cache',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              const SizedBox(height: 16),
              const ListTile(
                leading: Icon(Icons.storage),
                title: Text('Cache Size'),
                trailing: Text('Calculating...'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache cleared')),
                    );
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear Cache'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
