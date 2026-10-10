import 'package:flutter/material.dart';

import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';

class SurveyFieldTypeVisual {
  final IconData icon;
  final Color background;
  final Color foreground;

  const SurveyFieldTypeVisual({
    required this.icon,
    required this.background,
    required this.foreground,
  });
}

SurveyFieldTypeVisual surveyFieldTypeVisual(String type) {
  switch (type) {
    case 'text':
    case 'textarea':
      return const SurveyFieldTypeVisual(
        icon: Icons.title,
        background: Color(0xFFF0F9FF),
        foreground: Color(0xFF0369A1),
      );
    case 'number':
      return const SurveyFieldTypeVisual(
        icon: Icons.tag,
        background: Color(0xFFF5F3FF),
        foreground: Color(0xFF6D28D9),
      );
    case 'date':
      return const SurveyFieldTypeVisual(
        icon: Icons.calendar_today_outlined,
        background: Color(0xFFFFF1F2),
        foreground: Color(0xFFBE123C),
      );
    case 'boolean':
      return const SurveyFieldTypeVisual(
        icon: Icons.toggle_on_outlined,
        background: Color(0xFFFFFBEB),
        foreground: Color(0xFFB45309),
      );
    case 'select':
      return const SurveyFieldTypeVisual(
        icon: Icons.radio_button_checked_outlined,
        background: Color(0xFFFFFBEB),
        foreground: Color(0xFFB45309),
      );
    case 'multiselect':
      return const SurveyFieldTypeVisual(
        icon: Icons.checklist_rtl,
        background: Color(0xFFFFFBEB),
        foreground: Color(0xFFB45309),
      );
    case 'photo':
      return const SurveyFieldTypeVisual(
        icon: Icons.photo_camera_outlined,
        background: Color(0xFFECFDF5),
        foreground: Color(0xFF047857),
      );
    case 'signature':
      return const SurveyFieldTypeVisual(
        icon: Icons.draw_outlined,
        background: Color(0xFFEEF2FF),
        foreground: Color(0xFF4338CA),
      );
    case 'location':
      return const SurveyFieldTypeVisual(
        icon: Icons.location_on_outlined,
        background: Color(0xFFFEF2F2),
        foreground: Color(0xFFB91C1C),
      );
    default:
      return const SurveyFieldTypeVisual(
        icon: Icons.notes_outlined,
        background: Color(0xFFF3F4F6),
        foreground: Color(0xFF4B5563),
      );
  }
}

/// Palette-style row matching the web field-type picker.
class SurveyFieldTypeTile extends StatelessWidget {
  const SurveyFieldTypeTile({
    super.key,
    required this.info,
    this.onTap,
    this.dense = false,
    this.trailing,
  });

  final SurveyFieldTypeInfo info;
  final VoidCallback? onTap;
  final bool dense;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = surveyFieldTypeVisual(info.key);
    final iconSize = dense ? 28.0 : 36.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 4 : 8,
            vertical: dense ? 8 : 10,
          ),
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(dense ? 8 : 10),
                ),
                child: Icon(
                  visual.icon,
                  size: dense ? 16 : 18,
                  color: visual.foreground,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.2,
                          ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> showSurveyFieldTypePicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final byKey = {for (final item in surveyFieldTypes) item.key: item};

      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  'Field types',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a field to add to this section.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                for (final group in surveyFieldTypeGroups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Text(
                      group.$1.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  for (final type in group.$2)
                    if (byKey[type] != null)
                      SurveyFieldTypeTile(
                        info: byKey[type]!,
                        onTap: () => Navigator.pop(context, type),
                      ),
                ],
              ],
            );
          },
        ),
      );
    },
  );
}
