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
    final initial =
        (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        foregroundColor: const Color(0xFF1F2028),
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE4E1EA)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ProfilePhotoBox(
                    rawProfilePicture: user?.profilePicture,
                    initial: initial,
                    textColor: const Color(0xFF5663A0),
                    fontSize: 42,
                  ),
                ),
                if (_uploading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              user?.name ?? 'User',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.roleName ?? '',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _pickAndUpload,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Change profile picture'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5663A0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Changes sync with the web portal automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
