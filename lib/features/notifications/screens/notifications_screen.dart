import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../leads/models/lead_model.dart';
import '../../leads/providers/lead_provider.dart';
import '../../leads/screens/lead_detail_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  final bool showAppBar;

  const NotificationsScreen({super.key, this.showAppBar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(allLeadsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: showAppBar
          ? AppBar(
              title: const Text('Notifications'),
              backgroundColor: const Color(0xFFF7F8FC),
              elevation: 0,
              foregroundColor: const Color(0xFF1F2028),
            )
          : null,
      body: leadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (leads) {
          final recent = List<LeadModel>.from(leads)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          if (recent.isEmpty) {
            return const Center(
              child: Text(
                'No recent lead activity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recent.take(20).length,
            itemBuilder: (context, index) {
              final lead = recent[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.solar_power, color: Color(0xFF5663A0)),
                  title: Text(
                    lead.fullName.isEmpty ? lead.leadCode : lead.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${lead.status} · ${lead.currentDepartment}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeadDetailScreen(lead: lead),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
