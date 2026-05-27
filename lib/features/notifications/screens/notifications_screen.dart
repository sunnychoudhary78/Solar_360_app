import 'package:flutter/material.dart';

import '../../home/screens/home_screen.dart';
import '../../leads/models/lead_model.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  static const bgColor = Color(0xFFF7F8FC);
  static const cardColor = Colors.white;
  static const primaryColor = Color(0xFF5663A0);
  static const textColor = Color(0xFF1F2028);

  @override
  Widget build(BuildContext context) {
    final List<LeadModel> leads = HomeScreen.leads;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: bgColor,
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: textColor),
              title: const Text(
                'Notifications',
                style: TextStyle(
                  color: textColor,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: leads.isEmpty
          ? const Center(
              child: Text(
                'No notifications available',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              children: [

                _notificationCard(
                  icon: Icons.person_add_alt_1_rounded,
                  title: '${leads.length} New Leads Added',
                  subtitle:
                      'New customer leads are waiting for review.',
                ),

                _notificationCard(
                  icon: Icons.file_copy_rounded,
                  title: 'Documents Uploaded',
                  subtitle:
                      'Aadhaar, PAN, electricity bill and support docs uploaded.',
                ),

                _notificationCard(
                  icon: Icons.pending_actions_rounded,
                  title: 'Pending Leads Available',
                  subtitle:
                      'Some leads still need notes and verification.',
                ),

                _notificationCard(
                  icon: Icons.edit_note_rounded,
                  title: 'Support Notes Updated',
                  subtitle:
                      'Support notes were recently updated by team.',
                ),
              ],
            ),
    );
  }

  Widget _notificationCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE4E1EA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          CircleAvatar(
            radius: 28,
            backgroundColor: primaryColor.withOpacity(0.12),
            child: Icon(
              icon,
              color: primaryColor,
              size: 30,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
