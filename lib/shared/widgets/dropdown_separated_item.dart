import 'package:flutter/material.dart';

/// Dropdown row with a hairline under it so stacked labels stay distinct.
class DropdownSeparatedChild extends StatelessWidget {
  const DropdownSeparatedChild({
    super.key,
    required this.child,
    this.showDivider = true,
  });

  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: child,
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
      ],
    );
  }
}

/// [DropdownMenuItem]s with a divider below each row except the last.
List<DropdownMenuItem<V>> separatedDropdownMenuItems<T, V>({
  required List<T> items,
  required V Function(T item) value,
  required Widget Function(T item) child,
}) {
  return [
    for (var i = 0; i < items.length; i++)
      DropdownMenuItem<V>(
        value: value(items[i]),
        child: DropdownSeparatedChild(
          showDivider: i < items.length - 1,
          child: child(items[i]),
        ),
      ),
  ];
}
