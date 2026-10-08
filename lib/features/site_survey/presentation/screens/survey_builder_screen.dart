import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/survey_validation.dart';
import 'package:solar_sales/features/site_survey/presentation/providers/site_survey_providers.dart';
import 'package:solar_sales/features/site_survey/presentation/screens/survey_preview_screen.dart';
import 'package:solar_sales/features/site_survey/presentation/site_survey_access.dart';

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
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Field types')),
            for (final item in surveyFieldTypes)
              ListTile(
                title: Text(item.$2),
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ],
        ),
      ),
    );
    if (type == null) return;
    final label = surveyFieldTypes.firstWhere((item) => item.$1 == type).$2;
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

  @override
  Widget build(BuildContext context) {
    final canEdit = SiteSurveyAccess.canEditTemplates(ref.watch(authProvider));
    return Scaffold(
      appBar: AppBar(
        title: Text(_name.text.isEmpty ? 'Template' : _name.text),
        actions: [
          IconButton(
            tooltip: 'Preview',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SurveyPreviewScreen(name: _name.text, schema: _schema),
                ),
              );
            },
            icon: const Icon(Icons.visibility_outlined),
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
          TextField(
            controller: _name,
            readOnly: !canEdit,
            decoration: const InputDecoration(
              labelText: 'Template name *',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _projectType,
            decoration: const InputDecoration(labelText: 'Project type', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any project type')),
              for (final type in surveyProjectTypes) DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: canEdit ? (value) => setState(() => _projectType = value) : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            readOnly: !canEdit,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          for (var s = 0; s < _schema.sections.length; s++)
            _SectionEditor(
              index: s,
              section: _schema.sections[s],
              canEdit: canEdit,
              onTitle: (title) {
                final sections = [..._schema.sections];
                sections[s] = sections[s].copyWith(title: title);
                setState(() => _schema = _schema.copyWith(sections: sections));
              },
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
          if (canEdit)
            OutlinedButton.icon(
              onPressed: _addSection,
              icon: const Icon(Icons.add),
              label: const Text('Add section'),
            ),
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
    required this.onTitle,
    required this.onAddField,
    required this.onEditField,
    required this.onDeleteField,
    required this.onDeleteSection,
  });

  final int index;
  final SurveySection section;
  final bool canEdit;
  final ValueChanged<String> onTitle;
  final VoidCallback onAddField;
  final ValueChanged<int> onEditField;
  final ValueChanged<int> onDeleteField;
  final VoidCallback onDeleteSection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primaryContainer,
                  child: Text('${index + 1}', style: TextStyle(color: scheme.primary)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: section.title,
                    readOnly: !canEdit,
                    decoration: const InputDecoration(labelText: 'Section title', isDense: true),
                    onChanged: onTitle,
                  ),
                ),
                if (canEdit)
                  IconButton(onPressed: onDeleteSection, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            Text('${section.fields.length} fields', style: TextStyle(color: scheme.onSurfaceVariant)),
            for (var i = 0; i < section.fields.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(section.fields[i].label),
                subtitle: Text(
                  '${section.fields[i].type}${section.fields[i].required ? ' · required' : ''}',
                ),
                trailing: canEdit
                    ? IconButton(
                        onPressed: () => onDeleteField(i),
                        icon: const Icon(Icons.close),
                      )
                    : null,
                onTap: canEdit ? () => onEditField(i) : null,
              ),
            if (canEdit)
              TextButton.icon(
                onPressed: onAddField,
                icon: const Icon(Icons.add),
                label: const Text('Add field'),
              ),
          ],
        ),
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.field.id, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              value: _required,
              onChanged: (value) => setState(() => _required = value),
            ),
            TextField(
              controller: _help,
              decoration: const InputDecoration(labelText: 'Help text', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            if (type == 'text' || type == 'textarea' || type == 'number')
              TextField(
                controller: _placeholder,
                decoration: const InputDecoration(labelText: 'Placeholder', border: OutlineInputBorder()),
              ),
            if (type == 'number') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _unit,
                decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      decoration: const InputDecoration(labelText: 'Min', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      decoration: const InputDecoration(labelText: 'Max', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
            if (type == 'select' || type == 'multiselect') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _options,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Options (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (type == 'photo') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _maxPhotos,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max photos', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Show only if'),
            DropdownButtonFormField<String?>(
              initialValue: _showIf?.field,
              decoration: const InputDecoration(labelText: 'Earlier field'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Always show')),
                for (final field in widget.earlier)
                  DropdownMenuItem(value: field.id, child: Text(field.label)),
              ],
              onChanged: (value) => setState(() {
                if (value == null) {
                  _showIf = null;
                } else {
                  _showIf = ShowIfRule(field: value, op: _showIf?.op ?? 'equals', value: _showIf?.value);
                }
              }),
            ),
            if (_showIf != null) ...[
              DropdownButtonFormField<String>(
                initialValue: _showIf!.op,
                items: const [
                  DropdownMenuItem(value: 'equals', child: Text('equals')),
                  DropdownMenuItem(value: 'not_equals', child: Text('not equals')),
                  DropdownMenuItem(value: 'answered', child: Text('answered')),
                  DropdownMenuItem(value: 'not_answered', child: Text('not answered')),
                  DropdownMenuItem(value: 'gt', child: Text('greater than')),
                  DropdownMenuItem(value: 'lt', child: Text('less than')),
                ],
                onChanged: (value) => setState(() {
                  _showIf = _showIf!.copyWith(op: value);
                }),
              ),
              if (_showIf!.op != 'answered' && _showIf!.op != 'not_answered')
                TextFormField(
                  initialValue: _showIf!.value == null ? '' : '${_showIf!.value}',
                  decoration: const InputDecoration(labelText: 'Value'),
                  onChanged: (text) {
                    final earlier = widget.earlier.cast<SurveyField?>().firstWhere(
                      (field) => field!.id == _showIf!.field,
                      orElse: () => null,
                    );
                    Object? parsed = text;
                    if (earlier?.type == 'boolean') {
                      parsed = text.trim().toLowerCase() == 'true' || text.trim().toLowerCase() == 'yes';
                    } else if (earlier?.type == 'number') {
                      parsed = num.tryParse(text.trim()) ?? text;
                    }
                    _showIf = _showIf!.copyWith(value: parsed);
                  },
                ),
            ],
            const SizedBox(height: 12),
            FilledButton(onPressed: _apply, child: const Text('Apply')),
          ],
        ),
      ),
    );
  }
}
