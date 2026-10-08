import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/survey_progress.dart';
import 'package:solar_sales/features/site_survey/data/survey_visibility.dart';

class SurveyFormView extends StatelessWidget {
  const SurveyFormView({
    super.key,
    required this.schema,
    required this.answers,
    required this.fieldErrors,
    required this.readOnly,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onSign,
    required this.onCaptureLocation,
    required this.imageBytes,
    this.fieldKeys = const {},
    this.formEpoch = 0,
  });

  final SurveySchema schema;
  final Map<String, dynamic> answers;
  final Map<String, String> fieldErrors;
  final bool readOnly;
  final void Function(String fieldId, dynamic value) onChanged;
  final Future<void> Function(SurveyField field) onAddPhoto;
  final void Function(SurveyField field, String fileId) onRemovePhoto;
  final Future<void> Function(SurveyField field) onSign;
  final Future<void> Function(SurveyField field) onCaptureLocation;
  final Future<Uint8List?> Function(String fileId) imageBytes;
  final Map<String, GlobalKey> fieldKeys;
  final int formEpoch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = visibleFieldIds(schema, answers);
    final progress = answerProgress(schema, answers);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${progress.answered} of ${progress.total} answered',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    progress.requiredLeft == 0
                        ? 'All required answered'
                        : '${progress.requiredLeft} required left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: progress.requiredLeft == 0
                          ? const Color(0xFF047857)
                          : scheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.percent,
                  minHeight: 8,
                  color: progress.requiredLeft == 0
                      ? const Color(0xFF10B981)
                      : null,
                ),
              ),
            ],
          ),
        ),
        for (var index = 0; index < schema.sections.length; index++)
          if (sectionIsVisible(schema.sections[index], answers, visible))
            _SectionCard(
              index: index,
              section: schema.sections[index],
              visible: visible,
              answers: answers,
              fieldErrors: fieldErrors,
              readOnly: readOnly,
              fieldKeys: fieldKeys,
              formEpoch: formEpoch,
              onChanged: onChanged,
              onAddPhoto: onAddPhoto,
              onRemovePhoto: onRemovePhoto,
              onSign: onSign,
              onCaptureLocation: onCaptureLocation,
              imageBytes: imageBytes,
            ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.index,
    required this.section,
    required this.visible,
    required this.answers,
    required this.fieldErrors,
    required this.readOnly,
    required this.fieldKeys,
    required this.formEpoch,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onSign,
    required this.onCaptureLocation,
    required this.imageBytes,
  });

  final int index;
  final SurveySection section;
  final Set<String> visible;
  final Map<String, dynamic> answers;
  final Map<String, String> fieldErrors;
  final bool readOnly;
  final Map<String, GlobalKey> fieldKeys;
  final int formEpoch;
  final void Function(String fieldId, dynamic value) onChanged;
  final Future<void> Function(SurveyField field) onAddPhoto;
  final void Function(SurveyField field, String fileId) onRemovePhoto;
  final Future<void> Function(SurveyField field) onSign;
  final Future<void> Function(SurveyField field) onCaptureLocation;
  final Future<Uint8List?> Function(String fileId) imageBytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fields = section.fields.where((field) => visible.contains(field.id)).toList();
    final answered = fields.where((field) => !isEmptyAnswer(answers[field.id])).length;
    final requiredLeft = fields
        .where((field) => field.required && isEmptyAnswer(answers[field.id]))
        .length;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            section.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          subtitle: Text(
            '$answered / ${fields.length} answered'
            '${requiredLeft > 0 ? ' · $requiredLeft required left' : ''}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          children: [
            if ((section.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(section.description!),
                ),
              ),
            for (final field in fields)
              KeyedSubtree(
                key: fieldKeys[field.id],
                child: _FieldBlock(
                  key: ValueKey('field-$formEpoch-${field.id}'),
                  field: field,
                  value: answers[field.id],
                  error: fieldErrors[field.id],
                  readOnly: readOnly,
                  onChanged: (value) => onChanged(field.id, value),
                  onAddPhoto: () => onAddPhoto(field),
                  onRemovePhoto: (fileId) => onRemovePhoto(field, fileId),
                  onSign: () => onSign(field),
                  onCaptureLocation: () => onCaptureLocation(field),
                  imageBytes: imageBytes,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({
    super.key,
    required this.field,
    required this.value,
    required this.error,
    required this.readOnly,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onSign,
    required this.onCaptureLocation,
    required this.imageBytes,
  });

  final SurveyField field;
  final dynamic value;
  final String? error;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final VoidCallback onAddPhoto;
  final ValueChanged<String> onRemovePhoto;
  final VoidCallback onSign;
  final VoidCallback onCaptureLocation;
  final Future<Uint8List?> Function(String fileId) imageBytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = isEmptyAnswer(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              text: field.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
              children: [
                if (field.required)
                  const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          if ((field.helpText ?? '').isNotEmpty)
            Text(
              field.helpText!,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 6),
          if (readOnly && empty)
            Text(
              'Not answered',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            _input(context),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error!,
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _input(BuildContext context) {
    switch (field.type) {
      case 'textarea':
        return TextFormField(
          initialValue: value is String ? value as String : '',
          readOnly: readOnly,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: const OutlineInputBorder(),
            isDense: true,
            errorText: error == null ? null : '',
          ),
          onChanged: readOnly ? null : (text) => onChanged(text.trim().isEmpty ? null : text),
        );
      case 'number':
        return TextFormField(
          initialValue: value == null ? '' : '$value',
          readOnly: readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
          decoration: InputDecoration(
            hintText: field.placeholder,
            suffixText: field.unit,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: readOnly
              ? null
              : (text) {
                  final parsed = num.tryParse(text.trim());
                  onChanged(text.trim().isEmpty ? null : (parsed ?? text));
                },
        );
      case 'boolean':
        final current = value == true || value == 'true'
            ? true
            : value == false || value == 'false'
            ? false
            : null;
        return Row(
          children: [
            _choice('Yes', current == true, readOnly ? null : () => onChanged(true)),
            const SizedBox(width: 8),
            _choice('No', current == false, readOnly ? null : () => onChanged(false)),
          ],
        );
      case 'select':
        if (field.options.length <= 4) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in field.options)
                _choice(
                  option,
                  '$value' == option,
                  readOnly ? null : () => onChanged(option),
                ),
            ],
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: field.options.contains('$value') ? '$value' : null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final option in field.options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: readOnly ? null : onChanged,
        );
      case 'multiselect':
        final selected = value is List
            ? value.map((e) => '$e').toSet()
            : <String>{};
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in field.options)
              FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: readOnly
                    ? null
                    : (on) {
                        final next = Set<String>.from(selected);
                        if (on) {
                          next.add(option);
                        } else {
                          next.remove(option);
                        }
                        onChanged(next.toList());
                      },
              ),
          ],
        );
      case 'date':
        final text = value is String ? value as String : '';
        return OutlinedButton.icon(
          onPressed: readOnly
              ? null
              : () async {
                  final initial = DateTime.tryParse(text) ?? DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    onChanged(DateFormat('yyyy-MM-dd').format(picked));
                  }
                },
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(text.isEmpty ? 'Choose date' : text),
        );
      case 'photo':
        final ids = value is List ? value.map((e) => '$e').toList() : <String>[];
        final maxPhotos = field.maxPhotos ?? 5;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in ids)
              _PhotoThumb(
                fileId: id,
                imageBytes: imageBytes,
                onRemove: readOnly ? null : () => onRemovePhoto(id),
                onOpen: () => _openImage(context, id),
              ),
            if (!readOnly && ids.length < maxPhotos)
              OutlinedButton.icon(
                onPressed: onAddPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text('Add (${ids.length}/$maxPhotos)'),
              ),
          ],
        );
      case 'signature':
        final id = value is String ? value as String : '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (id.isNotEmpty)
              SizedBox(
                height: 90,
                child: _PhotoThumb(
                  fileId: id,
                  imageBytes: imageBytes,
                  onRemove: null,
                  onOpen: () => _openImage(context, id),
                ),
              ),
            if (!readOnly)
              OutlinedButton.icon(
                onPressed: onSign,
                icon: const Icon(Icons.draw_outlined),
                label: Text(id.isEmpty ? 'Sign' : 'Replace signature'),
              ),
          ],
        );
      case 'location':
        final map = value is Map ? value : null;
        final lat = map?['lat'];
        final lng = map?['lng'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lat != null && lng != null) ...[
              Text('$lat, $lng'),
              if (map?['accuracy'] != null) Text('Accuracy ${map!['accuracy']} m'),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.google.com/maps?q=$lat,$lng'),
                ),
                child: const Text('View on map'),
              ),
            ],
            if (!readOnly)
              OutlinedButton.icon(
                onPressed: onCaptureLocation,
                icon: const Icon(Icons.my_location),
                label: Text(lat == null ? 'Capture location' : 'Update location'),
              ),
          ],
        );
      default:
        return TextFormField(
          initialValue: value is String
              ? value as String
              : (value == null ? '' : '$value'),
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: readOnly
              ? null
              : (text) => onChanged(text.trim().isEmpty ? null : text),
        );
    }
  }

  Future<void> _openImage(BuildContext context, String fileId) async {
    final bytes = await imageBytes(fileId);
    if (bytes == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(field.label),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(bytes),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback? onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap(),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.fileId,
    required this.imageBytes,
    required this.onRemove,
    required this.onOpen,
  });

  final String fileId;
  final Future<Uint8List?> Function(String fileId) imageBytes;
  final VoidCallback? onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: imageBytes(fileId),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Stack(
          children: [
            GestureDetector(
              onTap: onOpen,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: bytes == null
                    ? const Icon(Icons.image_outlined)
                    : Image.memory(bytes, fit: BoxFit.cover),
              ),
            ),
            if (onRemove != null)
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 16),
                ),
              ),
          ],
        );
      },
    );
  }
}
