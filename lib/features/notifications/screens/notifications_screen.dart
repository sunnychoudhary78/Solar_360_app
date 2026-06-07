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

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: showAppBar
          ? AppBar(
              title: const Text('Notifications'),
              backgroundColor: bgColor,
              elevation: 0,
              foregroundColor: textColor,
            )
          : null,
      body: leadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (leads) {
          final recent = List<LeadModel>.from(leads)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          if (recent.isEmpty) {
            return Center(
              child: Text(
                'No recent lead activity',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            );
          }

          final items = recent.take(20).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final lead = items[index];

              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    Icons.solar_power,
                    color: primaryColor,
                  ),
                  title: Text(
                    lead.fullName.isEmpty ? lead.leadCode : lead.fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    '${lead.status} · ${lead.currentDepartment}',
                    style: TextStyle(
                      color: textColor.withOpacity(0.65),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: primaryColor,
                  ),
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