import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/presentation/providers/site_survey_providers.dart';
import 'package:solar_sales/features/site_survey/presentation/screens/survey_builder_screen.dart';
import 'package:solar_sales/features/site_survey/presentation/site_survey_access.dart';

class SurveyTemplatesScreen extends ConsumerStatefulWidget {
  const SurveyTemplatesScreen({super.key});

  @override
  ConsumerState<SurveyTemplatesScreen> createState() => _SurveyTemplatesScreenState();
}

class _SurveyTemplatesScreenState extends ConsumerState<SurveyTemplatesScreen> {
  List<SurveyTemplate> _templates = [];
  bool _loading = true;
  String _query = '';
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(siteSurveyRepositoryProvider).listTemplates();
      if (!mounted) return;
      setState(() {
        _templates = list;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppMessage(context, '$error');
    }
  }

  List<SurveyTemplate> get _visible {
    return _templates.where((template) {
      final type = template.projectTypeLabel;
      if (_filter == 'Any project' && template.projectType != null) return false;
      if (_filter != 'All' && _filter != 'Any project' && type != _filter) return false;
      if (_query.trim().isEmpty) return true;
      return template.name.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();
  }

  int _count(String filter) {
    if (filter == 'All') return _templates.length;
    if (filter == 'Any project') {
      return _templates.where((t) => t.projectType == null).length;
    }
    return _templates.where((t) => t.projectType == filter).length;
  }

  Future<void> _create() async {
    final created = await showDialog<({String name, String? projectType})>(
      context: context,
      builder: (context) => const _NewTemplateDialog(),
    );
    if (created == null || !mounted) return;
    try {
      final auth = ref.read(authProvider);
      final template = await ref.read(siteSurveyRepositoryProvider).createTemplate(
        name: created.name,
        projectType: created.projectType,
        actor: surveyActor(auth),
      );
      if (!mounted) return;
      final fresh = await ref.read(siteSurveyRepositoryProvider).getTemplate(template.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SurveyBuilderScreen(template: fresh)),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, '$error');
    }
  }

  Future<void> _starters() async {
    try {
      await ref.read(siteSurveyRepositoryProvider).addStarterTemplates(surveyActor(ref.read(authProvider)));
      await _load();
      if (!mounted) return;
      showAppMessage(context, 'Starter templates are ready');
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, '$error');
    }
  }

  Future<void> _open(SurveyTemplate template) async {
    try {
      final fresh = await ref.read(siteSurveyRepositoryProvider).getTemplate(template.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SurveyBuilderScreen(template: fresh)),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, '$error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canEdit = SiteSurveyAccess.canEditTemplates(ref.watch(authProvider));
    final filters = ['All', ...surveyProjectTypes, 'Any project'];
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Survey Templates')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text(
                    'Design the site survey forms your team fills on each lead. Publish a template to make it available.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  if (canEdit)
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _starters,
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: const Text('Starter templates'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add),
                          label: const Text('New template'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in filters)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$filter ${_count(filter)}'),
                              selected: _filter == filter,
                              onSelected: (_) => setState(() => _filter = filter),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search templates...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 12),
                  if (_visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('No templates match this filter')),
                    )
                  else
                    for (final template in _visible)
                      _TemplateCard(
                        template: template,
                        canEdit: canEdit,
                        onEdit: () => _open(template),
                        onDuplicate: () async {
                          await ref.read(siteSurveyRepositoryProvider).duplicate(
                            template.id,
                            surveyActor(ref.read(authProvider)),
                          );
                          await _load();
                        },
                        onDefault: () async {
                          try {
                            await ref.read(siteSurveyRepositoryProvider).setDefault(template.id);
                            await _load();
                          } catch (error) {
                            if (!context.mounted) return;
                            showAppMessage(context, '$error');
                          }
                        },
                        onRemove: () async {
                          await ref.read(siteSurveyRepositoryProvider).deactivate(template.id);
                          await _load();
                        },
                      ),
                ],
              ),
            ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.canEdit,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDefault,
    required this.onRemove,
  });

  final SurveyTemplate template;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDefault;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updated = DateTime.tryParse(template.updatedAt)?.toLocal();
    final updatedLabel = updated == null ? '' : DateFormat('d MMM yyyy').format(updated);
    final by = template.updater?.name ?? template.creator?.name ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.assignment_outlined, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    template.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                if (canEdit)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'duplicate') onDuplicate();
                      if (value == 'default') onDefault();
                      if (value == 'remove') onRemove();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                      PopupMenuItem(value: 'default', child: Text('Set as default')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                Chip(label: Text(template.projectTypeLabel), visualDensity: VisualDensity.compact),
                if (template.isDefault)
                  Chip(
                    avatar: Icon(Icons.star, size: 16, color: scheme.primary),
                    label: const Text('Default'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              template.description.trim().isEmpty ? 'No description' : template.description,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              '${template.draftSchema.sections.length} sections   ·   ${template.draftSchema.fieldCount} fields',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.isPublished
                        ? 'Live · v${template.currentVersion}${template.hasUnpublishedChanges ? ' · unpublished changes' : ''}\nUpdated $updatedLabel${by.isEmpty ? '' : ' by $by'}'
                        : 'Not published\nUpdated $updatedLabel${by.isEmpty ? '' : ' by $by'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewTemplateDialog extends StatefulWidget {
  const _NewTemplateDialog();

  @override
  State<_NewTemplateDialog> createState() => _NewTemplateDialogState();
}

class _NewTemplateDialogState extends State<_NewTemplateDialog> {
  final _name = TextEditingController();
  String? _projectType;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New survey template'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Name it and pick the project type. You'll add sections and fields next."),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g. Rooftop survey',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Project type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any project type'),
                  selected: _projectType == null,
                  onSelected: (_) => setState(() => _projectType = null),
                ),
                for (final type in surveyProjectTypes)
                  ChoiceChip(
                    label: Text(type),
                    selected: _projectType == type,
                    onSelected: (_) => setState(() => _projectType = type),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(context, (name: _name.text.trim(), projectType: _projectType));
          },
          child: const Text('Create & open builder'),
        ),
      ],
    );
  }
}
