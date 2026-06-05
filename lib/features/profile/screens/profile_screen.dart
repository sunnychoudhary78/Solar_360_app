import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_message.dart';
import '../../../core/widgets/profile_photo_box.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider));
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;

  static const bgColor = Color(0xFFF7F8FC);
  static const cardColor = Colors.white;
  static const primaryColor = Color(0xFF4E5FAE);
  static const teamAccent = Color(0xFF22B8A8);
  static const textColor = Color(0xFF1F2028);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (file == null || !mounted) return;

    setState(() => _uploading = true);

    try {
      final filename =
          await ref.read(profileRepositoryProvider).uploadProfilePhoto(file);

      ref.read(authProvider.notifier).updateProfilePicture(filename);

      if (!mounted) return;
      showAppMessage(context, 'Profile picture updated');
    } catch (e) {
      if (!mounted) return;
      showAppMessage(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    final name =
        user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'User';

    final role =
        user?.roleName.trim().isNotEmpty == true ? user!.roleName.trim() : '—';

    final email =
        user?.email.trim().isNotEmpty == true ? user!.email.trim() : '—';

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        foregroundColor: primaryColor,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: textColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
          children: [
            _topCard(
              name: name,
              role: role,
              initial: initial,
              photo: user?.profilePicture,
            ),
            const SizedBox(height: 22),
            const Text(
              'Profile Information',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _infoTile(
                    icon: Icons.badge_outlined,
                    title: 'User ID',
                    value: user?.id,
                  ),
                  _infoTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Full Name',
                    value: name,
                  ),
                  _infoTile(
                    icon: Icons.work_outline_rounded,
                    title: 'Role Name',
                    value: role,
                  ),
                  _infoTile(
                    icon: Icons.location_on_outlined,
                    title: 'Work Location',
                    value: null,
                  ),
                  _infoTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: email,
                  ),
                  _infoTile(
                    icon: Icons.phone_outlined,
                    title: 'Contact',
                    value: null,
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Pull down to refresh profile details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topCard({
    required String name,
    required String role,
    required String initial,
    required String? photo,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, teamAccent],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                height: 118,
                width: 118,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                clipBehavior: Clip.antiAlias,
                child: ProfilePhotoBox(
                  rawProfilePicture: photo,
                  initial: initial,
                  textColor: primaryColor,
                  fontSize: 42,
                ),
              ),
              InkWell(
                onTap: _uploading ? null : _pickAndUpload,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _uploading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.edit_rounded,
                          color: primaryColor,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            role,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String? value,
    bool showDivider = true,
  }) {
    final displayValue =
        value == null || value.trim().isEmpty ? 'Not specified' : value.trim();

    return Column(
      children: [
        Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 25,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayValue,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
      ],
    );
  }
}