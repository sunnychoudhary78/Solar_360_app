import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/survey_validation.dart';
import 'package:solar_sales/features/site_survey/data/survey_visibility.dart';
import 'package:solar_sales/features/site_survey/presentation/providers/site_survey_providers.dart';
import 'package:solar_sales/features/site_survey/presentation/screens/survey_preview_screen.dart';
import 'package:solar_sales/features/site_survey/presentation/site_survey_access.dart';
import 'package:solar_sales/features/site_survey/presentation/widgets/survey_field_type_tile.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class SurveyBuilderScreen extends ConsumerStatefulWidget {
  const SurveyBuilderScreen({super.key, required this.template});

  final SurveyTemplate template;

  @override
  ConsumerState<SurveyBuilderScreen> createState() => _SurveyBuilderScreenState();
}

class _SurveyBuilderScreenState extends ConsumerState<SurveyBuilderScreen> {
  late TextEditingController _name;
  late TextEditingController _description;
  String? _projectType;
  late SurveySchema _schema;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.template.name);
    _description = TextEditingController(text: widget.template.description);
    _projectType = widget.template.projectType;
    _schema = widget.template.draftSchema;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Set<String> get _ids => {
    for (final section in _schema.sections) section.id,
    for (final field in _schema.fields) field.id,
  };

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showAppMessage(context, 'Template name is required');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref.read(siteSurveyRepositoryProvider).saveDraft(
        id: widget.template.id,
        name: _name.text,
        description: _description.text,
        projectType: _projectType,
        schema: _schema,
        actor: surveyActor(ref.read(authProvider)),
      );
      if (!mounted) return;
      setState(() => _schema = saved.draftSchema);
      showAppMessage(context, 'Template saved');
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, '$error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    await _save();
    if (!mounted) return;
    try {
      await ref.read(siteSurveyRepositoryProvider).publish(
        widget.template.id,
        surveyActor(ref.read(authProvider)),
      );
      if (!mounted) return;
      showAppMessage(context, 'Template published');
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, '$error', isError: true);
    }
  }

  void _addSection() {
    final taken = _ids;
    final id = uniqueId('section_${_schema.sections.length + 1}', taken);
    setState(() {
      _schema = _schema.copyWith(
        sections: [
          ..._schema.sections,
          SurveySection(id: id, title: 'Section ${_schema.sections.length + 1}'),
        ],
      );
    });
  }

  Future<void> _addField(int sectionIndex) async {
    final type = await showSurveyFieldTypePicker(context);
    if (type == null) return;
    final label = surveyFieldTypeInfo(type)?.label ?? type;
    final id = uniqueId(slugify(label), _ids);
    final field = SurveyField(
      id: id,
      type: type,
      label: label,
      options: type == 'select' || type == 'multiselect' ? const ['Option 1', 'Option 2'] : const [],
      maxPhotos: type == 'photo' ? 5 : null,
    );
    final sections = [..._schema.sections];
    final section = sections[sectionIndex];
    sections[sectionIndex] = section.copyWith(fields: [...section.fields, field]);
    setState(() => _schema = _schema.copyWith(sections: sections));
    if (!mounted) return;
    await _editField(sectionIndex, sections[sectionIndex].fields.length - 1);
  }

  Future<void> _editField(int sectionIndex, int fieldIndex) async {
    final field = _schema.sections[sectionIndex].fields[fieldIndex];
    final earlier = <SurveyField>[
      for (var s = 0; s < sectionIndex; s++) ..._schema.sections[s].fields,
      for (var f = 0; f < fieldIndex; f++) _schema.sections[sectionIndex].fields[f],
    ];
    final edited = await showModalBottomSheet<SurveyField>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FieldEditor(field: field, earlier: earlier),
    );
    if (edited == null) return;
    final sections = [..._schema.sections];
    final fields = [...sections[sectionIndex].fields];
    fields[fieldIndex] = edited;
    sections[sectionIndex] = sections[sectionIndex].copyWith(fields: fields);
    setState(() => _schema = _schema.copyWith(sections: sections));
  }

  Future<void> _editSection(int sectionIndex) async {
    final section = _schema.sections[sectionIndex];
    final earlier = <SurveyField>[
      for (var s = 0; s < sectionIndex; s++) ..._schema.sections[s].fields,
    ];
    final edited = await showModalBottomSheet<SurveySection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SectionSettingsEditor(section: section, earlier: earlier),
    );
    if (edited == null) return;
    final sections = [..._schema.sections];
    sections[sectionIndex] = edited;
    setState(() => _schema = _schema.copyWith(sections: sections));
  }

  void _openTest() {
    final schemaError = validateSchema(_schema);
    if (schemaError != null) {
      showAppMessage(context, schemaError, isError: true);
      return;
    }
    if (_schema.fieldCount == 0) {
      showAppMessage(context, 'Add at least one field before testing', isError: true);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurveyPreviewScreen(
          name: _name.text.trim().isEmpty ? 'Test form' : _name.text.trim(),
          schema: _schema,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canEdit = SiteSurveyAccess.canEditTemplates(ref.watch(authProvider));
    final published = widget.template.isPublished;
    final fieldCount = _schema.fieldCount;
    final sectionCount = _schema.sections.length;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text(_name.text.isEmpty ? 'Template' : _name.text),
        actions: [
          TextButton.icon(
            onPressed: _openTest,
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Test'),
          ),
          if (canEdit)
            TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
          if (canEdit)
            TextButton(onPressed: _saving ? null : _publish, child: const Text('Publish')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _BuilderStatsBar(
            published: published,
            version: widget.template.currentVersion,
            sections: sectionCount,
            fields: fieldCount,
            hasUnpublished: widget.template.hasUnpublishedChanges,
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumSectionTitle(
                  title: 'Template details',
                  subtitle: 'Name and how this template is categorized',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  readOnly: !canEdit,
                  decoration: const InputDecoration(
                    labelText: 'Template name *',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _projectType,
                  decoration: const InputDecoration(
                    labelText: 'Project type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any project type')),
                    for (final type in surveyProjectTypes)
                      DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  onChanged: canEdit ? (value) => setState(() => _projectType = value) : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  readOnly: !canEdit,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PremiumSectionTitle(
                  title: 'Form structure',
                  subtitle: sectionCount == 0
                      ? 'Add a section, then drop fields into it'
                      : '$sectionCount section${sectionCount == 1 ? '' : 's'} · $fieldCount field${fieldCount == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_schema.sections.isEmpty)
            _EmptyStructureHint(canEdit: canEdit, onAddSection: _addSection)
          else
            for (var s = 0; s < _schema.sections.length; s++)
              _SectionEditor(
                index: s,
                section: _schema.sections[s],
                canEdit: canEdit,
                fieldsById: {
                  for (final field in _schema.fields) field.id: field,
                },
                onTitle: (title) {
                  final sections = [..._schema.sections];
                  sections[s] = sections[s].copyWith(title: title);
                  setState(() => _schema = _schema.copyWith(sections: sections));
                },
                onEditSection: () => _editSection(s),
                onAddField: () => _addField(s),
                onEditField: (fieldIndex) => _editField(s, fieldIndex),
                onDeleteField: (fieldIndex) {
                  final sections = [..._schema.sections];
                  final fields = [...sections[s].fields]..removeAt(fieldIndex);
                  sections[s] = sections[s].copyWith(fields: fields);
                  setState(() => _schema = _schema.copyWith(sections: sections));
                },
                onDeleteSection: () {
                  final sections = [..._schema.sections]..removeAt(s);
                  setState(() => _schema = _schema.copyWith(sections: sections));
                },
              ),
          if (canEdit && _schema.sections.isNotEmpty) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _addSection,
              icon: const Icon(Icons.add),
              label: const Text('Add section'),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _openTest,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Test all fields'),
          ),
        ],
      ),
    );
  }
}

class _BuilderStatsBar extends StatelessWidget {
  const _BuilderStatsBar({
    required this.published,
    required this.version,
    required this.sections,
    required this.fields,
    required this.hasUnpublished,
  });

  final bool published;
  final int version;
  final int sections;
  final int fields;
  final bool hasUnpublished;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusLabel = published
        ? (hasUnpublished ? 'Draft changes' : 'Published')
        : 'Draft';
    final statusBg = published && !hasUnpublished
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFFF7ED);
    final statusFg = published && !hasUnpublished
        ? const Color(0xFF047857)
        : const Color(0xFFC2410C);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatPill(
          icon: Icons.circle,
          label: statusLabel,
          background: statusBg,
          foreground: statusFg,
          iconSize: 8,
        ),
        _StatPill(
          icon: Icons.layers_outlined,
          label: '$sections sections',
          background: scheme.primaryContainer.withValues(alpha: 0.55),
          foreground: scheme.primary,
        ),
        _StatPill(
          icon: Icons.view_agenda_outlined,
          label: '$fields fields',
          background: scheme.secondaryContainer.withValues(alpha: 0.55),
          foreground: scheme.onSecondaryContainer,
        ),
        if (published)
          _StatPill(
            icon: Icons.tag,
            label: 'v$version',
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
          ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.iconSize = 14,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStructureHint extends StatelessWidget {
  const _EmptyStructureHint({
    required this.canEdit,
    required this.onAddSection,
  });

  final bool canEdit;
  final VoidCallback onAddSection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.65),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.dashboard_customize_outlined, color: scheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            'No sections yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start with a section, then add field types your surveyors will fill on site.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          if (canEdit) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddSection,
              icon: const Icon(Icons.add),
              label: const Text('Add first section'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionEditor extends StatelessWidget {
  const _SectionEditor({
    required this.index,
    required this.section,
    required this.canEdit,
    required this.fieldsById,
    required this.onTitle,
    required this.onEditSection,
    required this.onAddField,
    required this.onEditField,
    required this.onDeleteField,
    required this.onDeleteSection,
  });

  final int index;
  final SurveySection section;
  final bool canEdit;
  final Map<String, SurveyField> fieldsById;
  final ValueChanged<String> onTitle;
  final VoidCallback onEditSection;
  final VoidCallback onAddField;
  final ValueChanged<int> onEditField;
  final ValueChanged<int> onDeleteField;
  final VoidCallback onDeleteSection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fieldCount = section.fields.length;
    final condition = describeShowIf(section.showIf, fieldsById, subject: 'section');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue: section.title,
                        readOnly: !canEdit,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        decoration: const InputDecoration(
                          labelText: 'Section title',
                          isDense: true,
                          filled: true,
                        ),
                        onChanged: onTitle,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$fieldCount field${fieldCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (canEdit)
                      IconButton(
                        tooltip: 'Section settings',
                        onPressed: onEditSection,
                        icon: Icon(Icons.tune_rounded, color: scheme.primary),
                      ),
                    if (canEdit)
                      IconButton(
                        tooltip: 'Delete section',
                        onPressed: onDeleteSection,
                        icon: Icon(Icons.delete_outline, color: scheme.error),
                      ),
                  ],
                ),
                if (condition != null) ...[
                  const SizedBox(height: 8),
                  _ConditionBadge(label: condition),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (section.fields.isEmpty)
                  _EmptyFieldsZone(canEdit: canEdit, onAddField: onAddField)
                else ...[
                  for (var i = 0; i < section.fields.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _SectionFieldTile(
                      field: section.fields[i],
                      fieldsById: fieldsById,
                      canEdit: canEdit,
                      onEdit: () => onEditField(i),
                      onDelete: () => onDeleteField(i),
                    ),
                  ],
                  if (canEdit) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onAddField,
                      icon: const Icon(Icons.add),
                      label: const Text('Add field'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFieldsZone extends StatelessWidget {
  const _EmptyFieldsZone({
    required this.canEdit,
    required this.onAddField,
  });

  final bool canEdit;
  final VoidCallback onAddField;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canEdit ? onAddField : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: scheme.outlineVariant.withValues(alpha: 0.9),
            radius: AppRadius.lg,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            child: Column(
              children: [
                Icon(Icons.add_box_outlined, color: scheme.primary),
                const SizedBox(height: 6),
                Text(
                  canEdit ? 'Add your first field' : 'No fields in this section',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Short text, choices, photos, signature, GPS, and more',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _SectionFieldTile extends StatelessWidget {
  const _SectionFieldTile({
    required this.field,
    required this.fieldsById,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final SurveyField field;
  final Map<String, SurveyField> fieldsById;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = surveyFieldTypeInfo(field.type);
    final visual = surveyFieldTypeVisual(field.type);
    final typeLabel = info?.label ?? field.type;
    final preview = _fieldPreview(field);
    final condition = describeShowIf(field.showIf, fieldsById);

    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: canEdit ? onEdit : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(visual.icon, size: 20, color: visual.foreground),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: field.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              children: [
                                if (field.required)
                                  const TextSpan(
                                    text: ' *',
                                    style: TextStyle(
                                      color: Color(0xFFE11D48),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (field.required)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE11D48),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: visual.foreground,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      if (field.options.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final option in field.options.take(4))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            if (field.options.length > 4)
                              Text(
                                '+${field.options.length - 4} more',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        )
                      else
                        Text(
                          preview,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                    if (condition != null) ...[
                      const SizedBox(height: 6),
                      _ConditionBadge(label: condition),
                    ],
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Remove field',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fieldPreview(SurveyField field) {
    if (field.options.isNotEmpty) return 'options';
    switch (field.type) {
      case 'boolean':
        return 'Yes · No';
      case 'photo':
        return 'Up to ${field.maxPhotos ?? 5} photos';
      case 'signature':
        return 'Signature pad';
      case 'location':
        return 'Capture GPS location';
      case 'date':
        return 'DD / MM / YYYY';
      case 'number':
        return field.unit == null || field.unit!.trim().isEmpty
            ? 'Number'
            : 'Number in ${field.unit}';
      default:
        return (field.placeholder ?? '').trim();
    }
  }
}

class _ConditionBadge extends StatelessWidget {
  const _ConditionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.alt_route_rounded, size: 12, color: Color(0xFF4338CA)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4338CA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldEditor extends StatefulWidget {
  const _FieldEditor({required this.field, required this.earlier});

  final SurveyField field;
  final List<SurveyField> earlier;

  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late final TextEditingController _label;
  late final TextEditingController _help;
  late final TextEditingController _placeholder;
  late final TextEditingController _options;
  late final TextEditingController _unit;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final TextEditingController _maxPhotos;
  late bool _required;
  ShowIfRule? _showIf;

  @override
  void initState() {
    super.initState();
    final field = widget.field;
    _label = TextEditingController(text: field.label);
    _help = TextEditingController(text: field.helpText ?? '');
    _placeholder = TextEditingController(text: field.placeholder ?? '');
    _options = TextEditingController(text: field.options.join('\n'));
    _unit = TextEditingController(text: field.unit ?? '');
    _min = TextEditingController(text: field.min?.toString() ?? '');
    _max = TextEditingController(text: field.max?.toString() ?? '');
    _maxPhotos = TextEditingController(text: '${field.maxPhotos ?? 5}');
    _required = field.required;
    _showIf = field.showIf;
  }

  @override
  void dispose() {
    _label.dispose();
    _help.dispose();
    _placeholder.dispose();
    _options.dispose();
    _unit.dispose();
    _min.dispose();
    _max.dispose();
    _maxPhotos.dispose();
    super.dispose();
  }

  void _apply() {
    final options = _options.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    Navigator.pop(
      context,
      widget.field.copyWith(
        label: _label.text.trim().isEmpty ? widget.field.label : _label.text.trim(),
        required: _required,
        helpText: _help.text.trim(),
        placeholder: _placeholder.text.trim(),
        unit: _unit.text.trim(),
        min: num.tryParse(_min.text.trim()),
        max: num.tryParse(_max.text.trim()),
        clearMin: _min.text.trim().isEmpty,
        clearMax: _max.text.trim().isEmpty,
        options: options,
        maxPhotos: (int.tryParse(_maxPhotos.text.trim())?.clamp(1, 10))?.toInt(),
        showIf: _showIf,
        clearShowIf: _showIf == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.field.type;
    final info = surveyFieldTypeInfo(type);
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit field',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            if (info != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: SurveyFieldTypeTile(info: info, dense: true),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Question / label *',
                prefixIcon: Icon(Icons.short_text_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _required
                    ? const Color(0xFFFFF1F2).withValues(alpha: 0.65)
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _required
                      ? const Color(0xFFE11D48).withValues(alpha: 0.25)
                      : scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Required',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  "The survey can't be submitted without it.",
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                value: _required,
                onChanged: (value) => setState(() => _required = value ?? false),
              ),
            ),
            if (type == 'select' || type == 'multiselect') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _options,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Options (one per line)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.list_alt_rounded),
                ),
              ),
            ],
            if (type == 'number') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Min'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Max'),
                    ),
                  ),
                ],
              ),
            ],
            if (type == 'photo') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _maxPhotos,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max photos',
                  helperText: 'Between 1 and 10.',
                  prefixIcon: Icon(Icons.photo_library_outlined),
                ),
              ),
            ],
            if (type == 'text' || type == 'textarea' || type == 'number') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _placeholder,
                decoration: const InputDecoration(
                  labelText: 'Placeholder',
                  prefixIcon: Icon(Icons.text_fields_rounded),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _help,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Help text',
                helperText: 'Shown under the field to guide the surveyor.',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.help_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            _ShowIfConditionEditor(
              subject: 'field',
              rule: _showIf,
              sources: widget.earlier,
              onChanged: (rule) => setState(() => _showIf = rule),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Field key *',
                helperText: 'Used to store the answer. Lowercase letters, numbers and _ only.',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              child: Text(
                widget.field.id,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _apply,
              child: const Text('Apply changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionSettingsEditor extends StatefulWidget {
  const _SectionSettingsEditor({required this.section, required this.earlier});

  final SurveySection section;
  final List<SurveyField> earlier;

  @override
  State<_SectionSettingsEditor> createState() => _SectionSettingsEditorState();
}

class _SectionSettingsEditorState extends State<_SectionSettingsEditor> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  ShowIfRule? _showIf;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.section.title);
    _description = TextEditingController(text: widget.section.description ?? '');
    _showIf = widget.section.showIf;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.pop(
      context,
      widget.section.copyWith(
        title: _title.text.trim().isEmpty ? widget.section.title : _title.text.trim(),
        description: _description.text.trim(),
        showIf: _showIf,
        clearShowIf: _showIf == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Section settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title *',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            _ShowIfConditionEditor(
              subject: 'section',
              rule: _showIf,
              sources: widget.earlier,
              onChanged: (rule) => setState(() => _showIf = rule),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Section key *',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              child: Text(
                widget.section.id,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _apply,
              child: const Text('Apply changes'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Matches web `ConditionEditor`: checkbox "Show this … only when…" + rule picks.
class _ShowIfConditionEditor extends StatelessWidget {
  const _ShowIfConditionEditor({
    required this.subject,
    required this.rule,
    required this.sources,
    required this.onChanged,
  });

  final String subject;
  final ShowIfRule? rule;
  final List<SurveyField> sources;
  final ValueChanged<ShowIfRule?> onChanged;

  SurveyField? get _source {
    if (rule == null) return null;
    for (final field in sources) {
      if (field.id == rule!.field) return field;
    }
    return null;
  }

  void _enable(bool enabled) {
    if (!enabled) {
      onChanged(null);
      return;
    }
    if (sources.isEmpty) return;
    final source = sources.last;
    final ops = opsForSourceType(source.type);
    final op = ops.first;
    onChanged(
      ShowIfRule(
        field: source.id,
        op: op,
        value: ruleOpNeedsValue(op) ? defaultRuleValue(source) : null,
      ),
    );
  }

  void _pickSource(String fieldId) {
    final source = sources.firstWhere((field) => field.id == fieldId);
    final ops = opsForSourceType(source.type);
    final op = ops.contains(rule?.op) ? rule!.op : ops.first;
    onChanged(
      ShowIfRule(
        field: source.id,
        op: op,
        value: ruleOpNeedsValue(op) ? defaultRuleValue(source) : null,
      ),
    );
  }

  void _pickOp(String op) {
    final source = _source;
    if (source == null || rule == null) return;
    onChanged(
      ShowIfRule(
        field: rule!.field,
        op: op,
        value: ruleOpNeedsValue(op)
            ? (rule!.value ?? defaultRuleValue(source))
            : null,
      ),
    );
  }

  void _pickValue(Object? value) {
    if (rule == null) return;
    onChanged(rule!.copyWith(value: value, clearValue: value == null));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = rule != null;
    final source = _source;
    final ops = source == null ? const <String>[] : opsForSourceType(source.type);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(
              'Show this $subject only when…',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            value: enabled,
            onChanged: sources.isEmpty ? null : (value) => _enable(value ?? false),
          ),
          if (sources.isEmpty)
            Text(
              'Add a question above this $subject to use a condition.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            )
          else if (enabled) ...[
            DropdownButtonFormField<String>(
              key: ValueKey('source-${rule!.field}'),
              initialValue: source?.id,
              decoration: const InputDecoration(
                labelText: 'Choose a question',
                isDense: true,
              ),
              items: [
                for (final field in sources)
                  DropdownMenuItem(value: field.id, child: Text(field.label)),
              ],
              onChanged: (value) {
                if (value != null) _pickSource(value);
              },
            ),
            if (source != null) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('op-${rule!.field}-${rule!.op}'),
                initialValue: ops.contains(rule!.op) ? rule!.op : ops.first,
                decoration: const InputDecoration(
                  labelText: 'Condition',
                  isDense: true,
                ),
                items: [
                  for (final op in ops)
                    DropdownMenuItem(
                      value: op,
                      child: Text(ruleOpLabels[op] ?? op),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _pickOp(value);
                },
              ),
              if (ruleOpNeedsValue(rule!.op)) ...[
                const SizedBox(height: 10),
                if (source.type == 'boolean')
                  DropdownButtonFormField<bool>(
                    key: ValueKey('bool-${rule!.value}'),
                    initialValue: rule!.value == true || rule!.value == 'true',
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Yes')),
                      DropdownMenuItem(value: false, child: Text('No')),
                    ],
                    onChanged: (value) {
                      if (value != null) _pickValue(value);
                    },
                  )
                else if (source.options.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey('opt-${rule!.value}'),
                    initialValue: source.options.contains('${rule!.value ?? ''}')
                        ? '${rule!.value}'
                        : source.options.first,
                    decoration: const InputDecoration(
                      labelText: 'Choose an option',
                      isDense: true,
                    ),
                    items: [
                      for (final option in source.options)
                        DropdownMenuItem(value: option, child: Text(option)),
                    ],
                    onChanged: (value) {
                      if (value != null) _pickValue(value);
                    },
                  )
                else
                  TextFormField(
                    key: ValueKey('val-${rule!.field}-${rule!.op}'),
                    initialValue: rule!.value == null ? '' : '${rule!.value}',
                    keyboardType: source.type == 'number'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      isDense: true,
                    ),
                    onChanged: (text) {
                      if (source.type == 'number') {
                        _pickValue(num.tryParse(text.trim()) ?? text);
                      } else {
                        _pickValue(text);
                      }
                    },
                  ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
