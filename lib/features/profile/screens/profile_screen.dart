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
    final user = ref.watch(authProvider).user;

    final name = user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        foregroundColor: textColor,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider.notifier).refreshProfile(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, teamAccent],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.22),
                      blurRadius: 22,
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
                          height: 112,
                          width: 112,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ProfilePhotoBox(
                            rawProfilePicture: user?.profilePicture,
                            initial: initial,
                            textColor: primaryColor,
                            fontSize: 40,
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
                                : const Icon(Icons.edit_rounded, color: primaryColor),
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
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.roleName ?? '—',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                    _infoTile(Icons.badge_outlined, 'User ID', user?.id),
                    _infoTile(Icons.person_outline_rounded, 'Full Name', user?.name),
                    _infoTile(Icons.work_outline_rounded, 'Role Name', user?.roleName),
                    _infoTile(Icons.email_outlined, 'Email', user?.email),
                    _infoTile(Icons.business_outlined, 'Company', user?.companyName),
                    _infoTile(Icons.location_on_outlined, 'Work Location', null),
                    _infoTile(Icons.phone_outlined, 'Contact', null, showDivider: false),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Profile picture changes sync with the web portal automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(
    IconData icon,
    String title,
    String? value, {
    bool showDivider = true,
  }) {
    final displayValue =
        value == null || value.trim().isEmpty ? 'Not specified' : value.trim();

    return Column(
      children: [
        Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.black45, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    displayValue,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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