import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_state.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/features/leads/presentation/widgets/leads_table.dart';
import 'package:solar_sales/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/premium_ui.dart';
import 'package:solar_sales/shared/widgets/unread_badge.dart';

class WorkflowTeamScreen extends ConsumerStatefulWidget {
  final String? titleOverride;

  const WorkflowTeamScreen({super.key, this.titleOverride});

  @override
  ConsumerState<WorkflowTeamScreen> createState() => _WorkflowTeamScreenState();
}

class _WorkflowTeamScreenState extends ConsumerState<WorkflowTeamScreen> {
  int selectedPage = 0; // 0 Dashboard, 1 Notifications

  String get _title {
    final auth = ref.read(authProvider);
    return widget.titleOverride ?? auth.roleTitle;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final leadsAsync = ref.watch(allLeadsProvider);
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: selectedPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectedPage != 0) {
          setState(() => selectedPage = 0);
        }
      },
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppAppBar(
          title: selectedPage == 1 ? 'Notifications' : _title,
          subtitle: selectedPage == 0 ? auth.roleName : null,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(allLeadsProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
            UnreadBadge(
              child: IconButton(
                tooltip: 'Notifications',
                onPressed: () => setState(() => selectedPage = 1),
                icon: Icon(
                  selectedPage == 1
                      ? Icons.notifications_rounded
                      : Icons.notifications_outlined,
                ),
              ),
            ),
          ],
        ),
        body: selectedPage == 1
            ? const NotificationsScreen(showAppBar: false)
            : leadsAsync.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(allLeadsProvider),
                ),
                data: (leads) {
                  if (!LeadWorkflow.isAdminRole(auth.effectiveRoleName) &&
                      !auth.isCompanyAdmin) {
                    return const EmptyState(
                      title: 'Workflow Desk unavailable',
                      subtitle:
                          'Only Company Admin can open the cross-team pipeline.',
                      icon: Icons.lock_outline_rounded,
                    );
                  }
                  final filtered = _filterLeadsForRole(leads, auth);
                  return _Dashboard(
                    leads: filtered,
                    roleName: auth.effectiveRoleName,
                    title: _title,
                  );
                },
              ),
      ),
    );
  }

  List<LeadModel> _filterLeadsForRole(List<LeadModel> leads, AuthState auth) {
    if (LeadWorkflow.isAdminRole(auth.effectiveRoleName)) {
      return leads;
    }

    final roleKey = auth.workflowRoleKey;
    final visibleStatuses = LeadWorkflow.getVisibleStatusesForRole(roleKey);
    if (visibleStatuses.isEmpty) return [];
    final userId = auth.userId.trim();

    return leads.where((lead) {
      final status = lead.status.trim();
      if (!visibleStatuses.contains(status)) return false;

      if (roleKey == 'Sales') {
        return userId.isNotEmpty && lead.createdBy.trim() == userId;
      }

      if (userId.isNotEmpty) {
        switch (roleKey) {
          case 'Document Administrator':
            return lead.assignedToDocumentAdmin.trim() == userId;
          case 'Bank Process':
            return lead.assignedToLiaisonOfficer.trim() == userId;
          case 'Finance User':
            return lead.assignedToFinanceUser.trim() == userId;
          case 'Material Engineer':
            return lead.assignedToMaterialEngineer.trim() == userId;
          case 'Electrical Engineer':
            return lead.assignedToElectricalEngineer.trim() == userId;
        }
      }

      return true;
    }).toList();
  }
}

enum _PipelineFilter { active, completed, rejected }

class _Dashboard extends StatefulWidget {
  const _Dashboard({
    required this.leads,
    required this.roleName,
    required this.title,
  });

  final List<LeadModel> leads;
  final String roleName;
  final String title;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  _PipelineFilter _filter = _PipelineFilter.active;

  static bool _isRejected(LeadModel lead) =>
      lead.status.trim() == 'Rejected';

  static bool _isCompleted(LeadModel lead) =>
      lead.status.trim() == 'Final Complete';

  /// In-progress leads only — excludes Rejected and Final Complete.
  static bool _isActiveLead(LeadModel lead) =>
      !_isRejected(lead) && !_isCompleted(lead);

  IconData _roleIcon(String roleKey) {
    switch (roleKey) {
      case 'Sales':
      case 'Sales Manager':
        return Icons.solar_power_rounded;
      case 'Document Administrator':
        return Icons.support_agent_rounded;
      case 'Bank Process':
        return Icons.account_tree_rounded;
      case 'Installation Manager':
      case 'Material Engineer':
      case 'Electrical Engineer':
        return Icons.electrical_services_rounded;
      case 'Finance Manager':
      case 'Finance User':
        return Icons.account_balance_rounded;
      default:
        return Icons.dashboard_rounded;
    }
  }

  String _deskLabel(String roleKey) {
    switch (roleKey) {
      case 'Sales':
      case 'Sales Manager':
        return 'Sales Desk';
      case 'Document Administrator':
        return 'Document Administrator';
      case 'Bank Process':
        return 'Bank Process';
      case 'Installation Manager':
      case 'Material Engineer':
      case 'Electrical Engineer':
        return 'Installation Desk';
      case 'Finance Manager':
      case 'Finance User':
        return 'Finance Desk';
      default:
        return 'Dashboard';
    }
  }

  List<LeadModel> get _filteredLeads {
    switch (_filter) {
      case _PipelineFilter.active:
        return widget.leads.where(_isActiveLead).toList();
      case _PipelineFilter.completed:
        return widget.leads.where(_isCompleted).toList();
      case _PipelineFilter.rejected:
        return widget.leads.where(_isRejected).toList();
    }
  }

  String get _emptyMessage {
    switch (_filter) {
      case _PipelineFilter.active:
        return 'No active leads in your queue';
      case _PipelineFilter.completed:
        return 'No completed leads';
      case _PipelineFilter.rejected:
        return 'No rejected leads';
    }
  }

  Widget _filterTile({
    required String label,
    required String value,
    required IconData icon,
    required _PipelineFilter filter,
    required ColorScheme scheme,
  }) {
    final selected = _filter == filter;
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.55)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: MetricTile(
          label: label,
          value: value,
          icon: icon,
          compact: true,
          onTap: () => setState(() => _filter = filter),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roleKey = LeadWorkflow.resolveRoleKey(widget.roleName);
    final active = widget.leads.where(_isActiveLead).length;
    final completed = widget.leads.where(_isCompleted).length;
    final rejected = widget.leads.where(_isRejected).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          icon: _roleIcon(roleKey),
          greeting: _deskLabel(roleKey),
          title: widget.title,
          subtitle: widget.roleName,
          trailing: StatusPill(
            label: _deskLabel(roleKey),
            color: scheme.primary,
          ),
        ).appFadeSlide(index: 0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              _filterTile(
                label: 'Active',
                value: '$active',
                icon: Icons.groups_rounded,
                filter: _PipelineFilter.active,
                scheme: scheme,
              ),
              const SizedBox(width: 8),
              _filterTile(
                label: 'Completed',
                value: '$completed',
                icon: Icons.check_circle_outline,
                filter: _PipelineFilter.completed,
                scheme: scheme,
              ),
              const SizedBox(width: 8),
              _filterTile(
                label: 'Rejected',
                value: '$rejected',
                icon: Icons.cancel_outlined,
                filter: _PipelineFilter.rejected,
                scheme: scheme,
              ),
            ],
          ),
        ).appFadeSlide(index: 1),
        const SizedBox(height: AppSpacing.md),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: PremiumSectionTitle(title: 'Pipeline'),
        ),
        Expanded(
          child: LeadsTable(
            leads: _filteredLeads,
            emptyMessage: _emptyMessage,
          ),
        ),
      ],
    );
  }
}
