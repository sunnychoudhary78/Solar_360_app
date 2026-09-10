import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/leads/data/india_cities.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';
import 'package:solar_sales/shared/utils/validators.dart';

/// Web-style India State + City pickers.
/// City list fills only after a state is chosen.
class IndiaStateCityFields extends StatefulWidget {
  const IndiaStateCityFields({
    super.key,
    required this.stateController,
    required this.cityController,
    this.stateRequired = false,
    this.cityRequired = false,
    this.enabled = true,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
  });

  final TextEditingController stateController;
  final TextEditingController cityController;
  final bool stateRequired;
  final bool cityRequired;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  @override
  State<IndiaStateCityFields> createState() => _IndiaStateCityFieldsState();
}

class _IndiaStateCityFieldsState extends State<IndiaStateCityFields> {
  @override
  void initState() {
    super.initState();
    widget.stateController.addListener(_onControllersChanged);
    widget.cityController.addListener(_onControllersChanged);
  }

  @override
  void didUpdateWidget(covariant IndiaStateCityFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stateController != widget.stateController) {
      oldWidget.stateController.removeListener(_onControllersChanged);
      widget.stateController.addListener(_onControllersChanged);
    }
    if (oldWidget.cityController != widget.cityController) {
      oldWidget.cityController.removeListener(_onControllersChanged);
      widget.cityController.addListener(_onControllersChanged);
    }
  }

  @override
  void dispose() {
    widget.stateController.removeListener(_onControllersChanged);
    widget.cityController.removeListener(_onControllersChanged);
    super.dispose();
  }

  void _onControllersChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickState() async {
    final selected = await showIndiaChoiceSheet(
      context: context,
      title: 'Select state',
      options: indiaStateOptionsIncluding(widget.stateController.text),
      selected: normalizeStateName(widget.stateController.text),
    );
    if (selected == null || !mounted) return;
    final canonical = normalizeStateName(selected);
    widget.stateController.text = canonical;
    if (!cityBelongsToState(widget.cityController.text, canonical)) {
      widget.cityController.clear();
    }
    setState(() {});
  }

  Future<void> _pickCity() async {
    final state = normalizeStateName(widget.stateController.text);
    if (state.isEmpty) return;
    final selected = await showIndiaChoiceSheet(
      context: context,
      title: 'Select city',
      options: indiaCityOptionsIncluding(state, widget.cityController.text),
      selected: resolveIndiaCityName(widget.cityController.text, state),
    );
    if (selected == null || !mounted) return;
    widget.cityController.text = resolveIndiaCityName(selected, state);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = normalizeStateName(widget.stateController.text);
    final city = widget.cityController.text.trim();
    final hasState = state.isNotEmpty;

    return Padding(
      padding: widget.padding,
      child: Column(
        children: [
          _PickerField(
            label: 'State',
            value: state,
            hint: 'Select state',
            requiredField: widget.stateRequired,
            enabled: widget.enabled,
            onTap: widget.enabled ? _pickState : null,
            validator: widget.stateRequired
                ? (value) => AppValidators.required(value, 'State')
                : (value) => AppValidators.maxLength(
                      value,
                      max: 50,
                      field: 'State',
                    ),
          ),
          const SizedBox(height: AppSpacing.md),
          _PickerField(
            label: 'City',
            value: city,
            hint: hasState ? 'Select city' : 'Select state first',
            requiredField: widget.cityRequired,
            enabled: widget.enabled && hasState,
            onTap: widget.enabled && hasState ? _pickCity : null,
            validator: widget.cityRequired
                ? (value) => AppValidators.required(value, 'City')
                : (value) => AppValidators.maxLength(
                      value,
                      max: 50,
                      field: 'City',
                    ),
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.hint,
    required this.requiredField,
    required this.enabled,
    required this.onTap,
    required this.validator,
  });

  final String label;
  final String value;
  final String hint;
  final bool requiredField;
  final bool enabled;
  final VoidCallback? onTap;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      validator: (_) => validator(value),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (field) {
        return InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: requiredField ? '$label *' : label,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              errorText: field.errorText,
              enabled: enabled,
              suffixIcon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: enabled
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).disabledColor,
              ),
            ),
            child: Text(
              value.isEmpty ? hint : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: value.isEmpty
                        ? Theme.of(context).hintColor
                        : Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
        );
      },
    );
  }
}

Future<String?> showIndiaChoiceSheet({
  required BuildContext context,
  required String title,
  required List<String> options,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _IndiaChoiceSheet(
        title: title,
        options: options,
        selected: selected ?? '',
      );
    },
  );
}

class _IndiaChoiceSheet extends StatefulWidget {
  const _IndiaChoiceSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String selected;

  @override
  State<_IndiaChoiceSheet> createState() => _IndiaChoiceSheetState();
}

class _IndiaChoiceSheetState extends State<_IndiaChoiceSheet> {
  late final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options
            .where((item) => item.toLowerCase().contains(q))
            .toList(growable: false);
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No matches'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected =
                          item.toLowerCase() == widget.selected.toLowerCase();
                      return ListTile(
                        title: Text(item),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
