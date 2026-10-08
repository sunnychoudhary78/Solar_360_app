import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/presentation/providers/site_survey_providers.dart';
import 'package:solar_sales/features/site_survey/presentation/screens/site_survey_screen.dart';
import 'package:solar_sales/features/site_survey/presentation/site_survey_access.dart';

class SiteSurveyLeadCard extends ConsumerStatefulWidget {
  const SiteSurveyLeadCard({super.key, required this.lead});

  final LeadModel lead;

  @override
  ConsumerState<SiteSurveyLeadCard> createState() => _SiteSurveyLeadCardState();
}

class _SiteSurveyLeadCardState extends ConsumerState<SiteSurveyLeadCard> {
  LeadSurveyLookup? _lookup;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lookup = await ref.read(siteSurveyRepositoryProvider).getForLead(
        leadId: widget.lead.id,
        projectType: widget.lead.projectType,
        canCreate: SiteSurveyAccess.canFillSurvey(ref.read(authProvider)),
      );
      if (!mounted) return;
      setState(() {
        _lookup = lookup;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SiteSurveyScreen(
          leadId: widget.lead.id,
          leadName: widget.lead.fullName.trim().isEmpty ? 'Lead' : widget.lead.fullName,
          projectType: widget.lead.projectType,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final survey = _lookup?.survey;
    final subtitle = _loading
        ? 'Loading…'
        : survey == null
        ? 'No site survey yet'
        : survey.isDraft
        ? 'Draft · ${survey.templateName}'
        : 'Submitted · ${survey.templateName}';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.fact_check_outlined, color: scheme.primary),
        ),
        title: const Text('Site survey', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: _open,
      ),
    );
  }
}
