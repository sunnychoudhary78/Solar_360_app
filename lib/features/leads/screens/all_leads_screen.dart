import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/lead_provider.dart';
import '../widgets/leads_table.dart';
import 'lead_form_screen.dart';

class AllLeadsScreen extends ConsumerWidget {
  const AllLeadsScreen({super.key});

  static const bgColor = Color(0xFFF7F8FC);
  static const primaryColor = Color(0xFF5663A0);
  static const textColor = Color(0xFF1F2028);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(allLeadsProvider);
    final canCreate = ref.watch(authProvider).hasPermission('lead.create');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          'All Leads',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allLeadsProvider),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Create Lead'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LeadFormScreen(),
                  ),
                );
              },
            )
          : null,
      body: leadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        data: (leads) => LeadsTable(
          leads: leads,
          emptyMessage: 'No leads found',
        ),
      ),
    );
  }
}
