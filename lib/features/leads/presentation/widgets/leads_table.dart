import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

/// Responsive lead card list (replaces the old horizontal DataTable).
class LeadsTable extends StatefulWidget {
  final List<LeadModel> leads;
  final bool showSearch;
  final String emptyMessage;
  final String? statusFilter;
  final ValueChanged<String?>? onStatusFilterChanged;

  const LeadsTable({
    super.key,
    required this.leads,
    this.showSearch = true,
    this.emptyMessage = 'No leads found',
    this.statusFilter,
    this.onStatusFilterChanged,
  });

  @override
  State<LeadsTable> createState() => _LeadsTableState();
}

class _LeadsTableState extends State<LeadsTable> {
  final TextEditingController searchController = TextEditingController();
  String search = '';
  bool openingLead = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<String> get _statusOptions {
    final set = <String>{};
    for (final l in widget.leads) {
      if (l.status.trim().isNotEmpty) set.add(l.status.trim());
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<LeadModel> get filteredLeads {
    final q = search.trim().toLowerCase();
    final status = widget.statusFilter;

    return widget.leads.where((lead) {
      if (status != null &&
          status.isNotEmpty &&
          status != 'All' &&
          lead.status.trim() != status) {
        return false;
      }
      if (q.isEmpty) return true;
      return lead.fullName.toLowerCase().contains(q) ||
          lead.mobile.toLowerCase().contains(q) ||
          lead.leadCode.toLowerCase().contains(q) ||
          lead.status.toLowerCase().contains(q) ||
          lead.currentDepartment.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> openLead(LeadModel lead) async {
    if (openingLead || !mounted) return;
    setState(() => openingLead = true);
    await Navigator.of(
      context,
    ).pushNamed('/solar/leads/detail', arguments: lead.id);
    if (!mounted) return;
    setState(() => openingLead = false);
  }

  @override
  Widget build(BuildContext context) {
    final leads = filteredLeads;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: AppSearchField(
              controller: searchController,
              hintText: 'Search name, mobile, code, status…',
              onChanged: (v) => setState(() => search = v),
              onClear: () => setState(() => search = ''),
            ),
          ),
        if (widget.onStatusFilterChanged != null)
          AppFilterBar(
            options: _statusOptions,
            selected: widget.statusFilter ?? 'All',
            onSelected: (v) =>
                widget.onStatusFilterChanged!(v == 'All' ? null : v),
          ),
        Expanded(
          child: leads.isEmpty
              ? EmptyState(
                  title: widget.emptyMessage,
                  subtitle: search.isNotEmpty
                      ? 'Try a different search'
                      : 'Leads will appear here',
                  icon: Icons.handshake_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: leads.length,
                  itemBuilder: (context, index) {
                    final lead = leads[index];
                    return EntityTile(
                      index: index,
                      title: lead.fullName.isEmpty
                          ? (lead.leadCode.isEmpty
                                ? 'Untitled lead'
                                : lead.leadCode)
                          : lead.fullName,
                      subtitle: [
                        if (lead.leadCode.isNotEmpty) lead.leadCode,
                        if (lead.mobile.isNotEmpty) lead.mobile,
                        if (lead.currentDepartment.isNotEmpty)
                          lead.currentDepartment,
                      ].join(' · '),
                      leadingIcon: Icons.handshake_rounded,
                      status: lead.status.isEmpty ? null : lead.status,
                      onTap: openingLead ? null : () => openLead(lead),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
