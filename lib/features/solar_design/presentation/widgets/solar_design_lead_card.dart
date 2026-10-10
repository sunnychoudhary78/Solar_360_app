import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/solar_design/presentation/providers/solar_design_providers.dart';
import 'package:solar_sales/features/solar_design/presentation/screens/solar_designs_screen.dart';
import 'package:solar_sales/features/solar_design/presentation/solar_design_access.dart';

class SolarDesignLeadCard extends ConsumerStatefulWidget {
  const SolarDesignLeadCard({super.key, required this.lead});

  final LeadModel lead;

  @override
  ConsumerState<SolarDesignLeadCard> createState() =>
      _SolarDesignLeadCardState();
}

class _SolarDesignLeadCardState extends ConsumerState<SolarDesignLeadCard> {
  int? _count;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!SolarDesignAccess.canRead(ref.read(authProvider))) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final result = await ref
          .read(solarDesignApiProvider)
          .listForLead(widget.lead.id);
      if (!mounted) return;
      setState(() {
        _count = result.designs.length;
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
        builder: (_) => SolarDesignsScreen(lead: widget.lead),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = _loading
        ? 'Loading…'
        : _count == null
            ? 'Open 3D rooftop designs'
            : _count == 0
                ? 'No designs yet'
                : '$_count design${_count == 1 ? '' : 's'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.view_in_ar_outlined, color: scheme.primary),
        ),
        title: const Text(
          '3D Solar Design',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: _open,
      ),
    );
  }
}
