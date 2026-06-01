import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/lead_provider.dart';
import '../widgets/leads_table.dart';
import 'lead_form_screen.dart';

class AllLeadsScreen extends ConsumerStatefulWidget {
  const AllLeadsScreen({super.key});

  @override
  ConsumerState<AllLeadsScreen> createState() => _AllLeadsScreenState();
}

class _AllLeadsScreenState extends ConsumerState<AllLeadsScreen> {
  static const bgColor = Color(0xFFF7F8FC);
  static const primaryColor = Color(0xFF5663A0);
  static const textColor = Color(0xFF1F2028);

  Future<void> _refreshLeads() async {
    if (!mounted) return;

    await ref.refresh(allLeadsProvider.future);
  }

  Future<void> _openCreateLead() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeadFormScreen()),
    );

    if (!mounted) return;

    await _refreshLeads();
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _refreshLeads,
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Create Lead'),
              onPressed: _openCreateLead,
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
        data: (leads) {
          return RefreshIndicator(
            onRefresh: _refreshLeads,
            child: leads.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 220),
                      Center(
                        child: Text(
                          'No leads found',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  )
                : LeadsTable(
                    leads: leads,
                    emptyMessage: 'No leads found',
                  ),
          );
        },
      ),
    );
  }
}