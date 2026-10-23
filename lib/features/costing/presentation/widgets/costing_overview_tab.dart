import 'package:flutter/material.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/costing/data/models/costing_model.dart';

import 'bom_list_tab.dart';
import 'costing_list_tab.dart';

/// Overview tab — mixes the two document types (Costing + BOM) without
/// merging them 1:1 by customer.
class CostingOverviewTab extends StatefulWidget {
  const CostingOverviewTab({
    super.key,
    required this.isGreenEnergy,
    required this.showBom,
    required this.canSelectVendor,
    required this.canCreateCosting,
    required this.canCreateBom,
    required this.vendors,
    required this.onEditCosting,
    required this.onOpenBom,
  });

  final bool isGreenEnergy;
  final bool showBom;
  final bool canSelectVendor;
  final bool canCreateCosting;
  final bool canCreateBom;
  final List<CostingVendor> vendors;

  final void Function(CostingListRow row) onEditCosting;
  final void Function(BomListRow row) onOpenBom;

  @override
  State<CostingOverviewTab> createState() => _CostingOverviewTabState();
}

class _CostingOverviewTabState extends State<CostingOverviewTab> {
  bool _showProjects = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showBom)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Costings'),
                    icon: Icon(Icons.receipt_long_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Projects'),
                    icon: Icon(Icons.inventory_2_outlined, size: 18),
                  ),
                ],
                selected: {_showProjects},
                onSelectionChanged: (selection) =>
                    setState(() => _showProjects = selection.first),
              ),
            ),
          ),
        Expanded(
          child: _showProjects && widget.showBom
              ? BomListTab(
                  canCreateBom: widget.canCreateBom,
                  onOpen: widget.onOpenBom,
                )
              : CostingListTab(
                  isGreenEnergy: widget.isGreenEnergy,
                  canSelectVendor: widget.canSelectVendor,
                  canCreateCosting: widget.canCreateCosting,
                  vendors: widget.vendors,
                  onEdit: widget.onEditCosting,
                ),
        ),
      ],
    );
  }
}