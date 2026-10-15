import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:solar_sales/core/network/api_constants.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/solar_design/data/models/solar_design_models.dart';
import 'package:solar_sales/features/solar_design/data/solar_design_api_service.dart';
import 'package:solar_sales/features/solar_design/presentation/providers/solar_design_providers.dart';
import 'package:solar_sales/features/solar_design/presentation/screens/solar_design_preview_screen.dart';
import 'package:solar_sales/features/solar_design/presentation/screens/solar_designer_screen.dart';
import 'package:solar_sales/features/solar_design/presentation/solar_design_access.dart';
import 'package:solar_sales/shared/utils/app_snackbar.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/utils/pdf_helper.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';

class SolarDesignsScreen extends ConsumerStatefulWidget {
  const SolarDesignsScreen({super.key, required this.lead});

  final LeadModel lead;

  @override
  ConsumerState<SolarDesignsScreen> createState() => _SolarDesignsScreenState();
}

class _SolarDesignsScreenState extends ConsumerState<SolarDesignsScreen> {
  SolarDesignListResult? _result;
  bool _loading = true;
  bool _creating = false;
  String? _error;
  final Set<String> _busyIds = {};
  /// Cached surroundings presence (list API omits the field).
  final Map<String, bool> _hasSurroundings = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(solarDesignApiProvider)
          .listForLead(widget.lead.id);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = cleanError(e);
      });
    }
  }

  bool _validCoords(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0 && lng == 0) return false;
    return lat.abs() <= 85 && lng.abs() <= 180;
  }

  /// Same starting-point rules as web `SolarDesignPanel.startingPoint`:
  /// lead GPS → pasted lat,lng → geocoded address (incl. place_id) → device GPS → India centre.
  Future<({double lat, double lng, int zoom})?> _resolveMapCenter() async {
    final leadLat = double.tryParse(widget.lead.latitude.trim());
    final leadLng = double.tryParse(widget.lead.longitude.trim());
    if (_validCoords(leadLat, leadLng)) {
      return (lat: leadLat!, lng: leadLng!, zoom: 20);
    }

    final fromApi = _result?.lead;
    if (_validCoords(fromApi?.latitude, fromApi?.longitude)) {
      return (lat: fromApi!.latitude!, lng: fromApi.longitude!, zoom: 20);
    }

    // Pasted "lat, lng" in address (same as web PlaceSearch).
    final pasted = SolarDesignApiService.parseLatLngPair(widget.lead.address) ??
        SolarDesignApiService.parseLatLngPair(
          [
            widget.lead.address,
            widget.lead.city,
            widget.lead.state,
            widget.lead.pincode,
          ].where((p) => p.trim().isNotEmpty).join(', '),
        );
    if (pasted != null && _validCoords(pasted.lat, pasted.lng)) {
      return (lat: pasted.lat, lng: pasted.lng, zoom: 19);
    }

    final address = [
      widget.lead.address,
      widget.lead.city,
      widget.lead.state,
      widget.lead.pincode,
    ].where((p) => p.trim().isNotEmpty).join(', ');
    if (address.length >= 2) {
      try {
        final api = ref.read(solarDesignApiProvider);
        final hits = await api.geocode(address);
        for (final hit in hits) {
          final resolved = await api.resolveGeocodeHit(hit);
          if (resolved != null &&
              _validCoords(resolved.lat, resolved.lng)) {
            return (lat: resolved.lat, lng: resolved.lng, zoom: 19);
          }
        }
      } catch (_) {
        // Fall through — designer has its own place search.
      }
    }

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (_validCoords(position.latitude, position.longitude)) {
          return (
            lat: position.latitude,
            lng: position.longitude,
            zoom: 18,
          );
        }
      }
    } catch (_) {
      // Fall through to India centre.
    }

    // Web fallback (INDIA_CENTER) so create never fails without a pin.
    return (lat: 20.5937, lng: 78.9629, zoom: 5);
  }

  Future<void> _openDesigner(SolarDesignSummary design) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SolarDesignerScreen(
          designId: design.id,
          title: design.name,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _createDesign() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final center = await _resolveMapCenter();
      if (center == null) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          'A map location is required. Set latitude/longitude on the lead, or allow GPS.',
          isError: true,
        );
        return;
      }
      final created = await ref.read(solarDesignApiProvider).create(
            leadId: widget.lead.id,
            centerLat: center.lat,
            centerLng: center.lng,
            mapZoom: center.zoom,
          );
      if (!mounted) return;
      showAppSnackBar(context, '${created.name} created');
      await _openDesigner(created.toSummary());
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, cleanError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _creating = false);
        await _load();
      }
    }
  }

  Future<void> _withBusy(String id, Future<void> Function() action) async {
    setState(() => _busyIds.add(id));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<SolarDesignDetail> _ensureShareEnabled(SolarDesignSummary design) async {
    final api = ref.read(solarDesignApiProvider);
    if (design.shareEnabled &&
        design.shareCode != null &&
        design.shareCode!.isNotEmpty) {
      return api.getById(design.id);
    }
    return api.setSharing(id: design.id, enabled: true);
  }

  String _shareUrlFor(SolarDesignSummary design) {
    final code = design.shareCode?.trim() ?? '';
    if (code.isEmpty) return '';
    return ApiConstants.publicSolarDesignUrl(code);
  }

  Future<void> _openPreview(SolarDesignSummary design) async {
    await _withBusy(design.id, () async {
      try {
        final shared = await _ensureShareEnabled(design);
        final url = _shareUrlFor(shared.toSummary());
        if (url.isEmpty) {
          throw const ApiException('Share link is not available');
        }
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SolarDesignPreviewScreen(
              url: url,
              title: shared.name,
            ),
          ),
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, cleanError(e), isError: true);
      }
    });
  }

  Future<void> _copyLink(SolarDesignSummary design) async {
    await _withBusy(design.id, () async {
      try {
        final shared = await _ensureShareEnabled(design);
        final url = _shareUrlFor(shared.toSummary());
        if (url.isEmpty) {
          throw const ApiException('Share link is not available');
        }
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        showAppSnackBar(context, 'Preview link copied');
        await _load();
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, cleanError(e), isError: true);
      }
    });
  }

  Future<void> _shareWhatsApp(SolarDesignSummary design) async {
    await _withBusy(design.id, () async {
      try {
        final shared = await _ensureShareEnabled(design);
        final url = _shareUrlFor(shared.toSummary());
        if (url.isEmpty) {
          throw const ApiException('Share link is not available');
        }

        final name = widget.lead.fullName.trim().isEmpty
            ? 'there'
            : widget.lead.fullName.trim();
        final size = shared.capacityKw > 0
            ? '${shared.capacityKw.toStringAsFixed(shared.capacityKw >= 10 ? 1 : 2)} kW'
            : 'rooftop';
        final message =
            'Hi $name, here is the 3D design of your $size rooftop solar system. '
            'Open it on your phone to rotate it and see how the sun falls on your roof: $url';

        final digits = widget.lead.mobile.replaceAll(RegExp(r'\D'), '');
        String? phone;
        if (digits.length == 10) {
          phone = '91$digits';
        } else if (digits.length >= 11 && digits.length <= 15) {
          phone = digits;
        }

        final uri = phone == null
            ? Uri.parse(
                'https://wa.me/?text=${Uri.encodeComponent(message)}',
              )
            : Uri.parse(
                'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
              );

        final opened =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!opened && mounted) {
          showAppSnackBar(context, 'Could not open WhatsApp', isError: true);
        }
        await _load();
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, cleanError(e), isError: true);
      }
    });
  }

  Future<void> _toggleShare(SolarDesignSummary design) async {
    await _withBusy(design.id, () async {
      try {
        await ref.read(solarDesignApiProvider).setSharing(
              id: design.id,
              enabled: !design.shareEnabled,
            );
        if (!mounted) return;
        showAppSnackBar(
          context,
          design.shareEnabled ? 'Share link turned off' : 'Share link turned on',
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, cleanError(e), isError: true);
      }
    });
  }

  Future<void> _downloadPdf(SolarDesignSummary design) async {
    await _withBusy(design.id, () async {
      try {
        final bytes =
            await ref.read(solarDesignApiProvider).downloadReport(design.id);
        final safe = design.name
            .replaceAll(RegExp(r'[^\w.-]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
        final filename =
            'Solar-Design-${safe.isEmpty ? 'design' : safe}.pdf';
        await PdfHelper.saveAndOpen(bytes, filename: filename);
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, cleanError(e), isError: true);
      }
    });
  }

  Future<void> _loadSurroundings(SolarDesignSummary design) async {
    await _withBusy(design.id, () async {
      try {
        final detail = await ref.read(solarDesignApiProvider).loadSurroundings(
              id: design.id,
            );
        if (!mounted) return;
        setState(() {
          _hasSurroundings[design.id] = detail.surroundings?.isLoaded == true;
        });
        final status = detail.surroundings?.statusLabel ?? 'Loaded';
        showAppSnackBar(context, '3D surroundings $status');
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, cleanError(e), isError: true);
      }
    });
  }

  Future<void> _clearSurroundings(SolarDesignSummary design) async {
    await _withBusy(design.id, () async {
      try {
        await ref.read(solarDesignApiProvider).clearSurroundings(design.id);
        if (!mounted) return;
        setState(() => _hasSurroundings[design.id] = false);
        showAppSnackBar(context, '3D surroundings cleared');
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, cleanError(e), isError: true);
      }
    });
  }

  /// Refresh surroundings flag from detail when opening actions (list omits it).
  Future<void> _refreshSurroundingsFlag(String designId) async {
    try {
      final detail = await ref.read(solarDesignApiProvider).getById(designId);
      if (!mounted) return;
      setState(() {
        _hasSurroundings[designId] = detail.surroundings?.isLoaded == true;
      });
    } catch (_) {
      // Keep cached value; actions still work.
    }
  }

  Future<void> _deleteDesign(SolarDesignSummary design) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete design?'),
        content: Text(
          '“${design.name}” will be removed and any share link will stop working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _withBusy(design.id, () async {
      try {
        await ref.read(solarDesignApiProvider).deactivate(design.id);
        if (!mounted) return;
        setState(() => _hasSurroundings.remove(design.id));
        showAppSnackBar(context, 'Design deleted');
        await _load();
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, cleanError(e), isError: true);
      }
    });
  }

  void _showActions(SolarDesignSummary design) {
    final auth = ref.read(authProvider);
    final canUpdate = SolarDesignAccess.canUpdate(auth);
    final busy = _busyIds.contains(design.id);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (canUpdate && !_hasSurroundings.containsKey(design.id)) {
              // Mark pending immediately so rebuilds don't re-fetch.
              _hasSurroundings[design.id] = false;
              _refreshSurroundingsFlag(design.id).then((_) {
                if (sheetContext.mounted) setSheetState(() {});
              });
            }
            final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
            final surroundingsLoaded = _hasSurroundings[design.id] == true;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(
                          design.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${design.capacityLabel} · ${design.panelsLabel}\n${design.energyLabel}',
                        ),
                        isThreeLine: true,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.architecture_outlined),
                        title: const Text('Open designer'),
                        subtitle:
                            const Text('Draw roof, place panels, 3D tools'),
                        enabled: !busy,
                        onTap: () {
                          Navigator.pop(context);
                          _openDesigner(design);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.view_in_ar_outlined),
                        title: const Text('Customer 3D preview'),
                        subtitle: const Text('Public share view'),
                        enabled: !busy,
                        onTap: () {
                          Navigator.pop(context);
                          _openPreview(design);
                        },
                      ),
                      if (canUpdate) ...[
                        ListTile(
                          leading: const Icon(Icons.terrain_outlined),
                          title: const Text('Load 3D surroundings'),
                          subtitle: Text(
                            surroundingsLoaded
                                ? 'Refresh Google Solar height map for shading'
                                : 'Fetch nearby buildings & trees (Google Solar)',
                          ),
                          enabled: !busy,
                          onTap: () {
                            Navigator.pop(context);
                            _loadSurroundings(design);
                          },
                        ),
                        if (surroundingsLoaded)
                          ListTile(
                            leading: const Icon(Icons.layers_clear_outlined),
                            title: const Text('Clear 3D surroundings'),
                            subtitle: const Text(
                              'Remove stored height / sunlight grid',
                            ),
                            enabled: !busy,
                            onTap: () {
                              Navigator.pop(context);
                              _clearSurroundings(design);
                            },
                          ),
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: const Text('Copy preview link'),
                          enabled: !busy,
                          onTap: () {
                            Navigator.pop(context);
                            _copyLink(design);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.chat),
                          title: const Text('Share on WhatsApp'),
                          enabled: !busy,
                          onTap: () {
                            Navigator.pop(context);
                            _shareWhatsApp(design);
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            design.shareEnabled
                                ? Icons.link_off_outlined
                                : Icons.link_outlined,
                          ),
                          title: Text(
                            design.shareEnabled
                                ? 'Turn share link off'
                                : 'Turn share link on',
                          ),
                          enabled: !busy,
                          onTap: () {
                            Navigator.pop(context);
                            _toggleShare(design);
                          },
                        ),
                      ],
                      ListTile(
                        leading: const Icon(Icons.picture_as_pdf_outlined),
                        title: const Text('Download PDF report'),
                        enabled: !busy,
                        onTap: () {
                          Navigator.pop(context);
                          _downloadPdf(design);
                        },
                      ),
                      if (canUpdate)
                        ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            'Delete design',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          enabled: !busy,
                          onTap: () {
                            Navigator.pop(context);
                            _deleteDesign(design);
                          },
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canCreate = SolarDesignAccess.canCreate(auth);
    final designs = _result?.designs ?? const <SolarDesignSummary>[];
    final scheme = Theme.of(context).colorScheme;
    final leadName = widget.lead.fullName.trim().isEmpty
        ? 'Lead'
        : widget.lead.fullName.trim();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: '3D Designs',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _creating ? null : _createDesign,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_creating ? 'Creating…' : 'New design'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  title: 'Could not load designs',
                  subtitle: _error,
                  icon: Icons.error_outline,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: designs.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            EmptyState(
                              title: 'No 3D designs yet',
                              subtitle: canCreate
                                  ? 'Create a design for $leadName, then draw the roof on satellite imagery and lay out panels — same designer as the web app.'
                                  : 'No designs have been saved for this lead.',
                              icon: Icons.view_in_ar_outlined,
                              action: canCreate
                                  ? FilledButton.icon(
                                      onPressed:
                                          _creating ? null : _createDesign,
                                      icon: const Icon(Icons.add),
                                      label: const Text('New design'),
                                    )
                                  : null,
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: designs.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '$leadName · ${designs.length} design${designs.length == 1 ? '' : 's'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              );
                            }
                            final design = designs[index - 1];
                            return _DesignCard(
                              design: design,
                              busy: _busyIds.contains(design.id),
                              hasSurroundings:
                                  _hasSurroundings[design.id] == true,
                              onOpen: () => _openDesigner(design),
                              onMore: () => _showActions(design),
                            );
                          },
                        ),
                ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({
    required this.design,
    required this.busy,
    required this.hasSurroundings,
    required this.onOpen,
    required this.onMore,
  });

  final SolarDesignSummary design;
  final bool busy;
  final bool hasSurroundings;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final created = formatDate(parseDate(design.createdAt));
    final creator = design.creator.name.trim();
    final meta = [
      if (creator.isNotEmpty) 'Created by $creator',
      if (created != '—') created,
    ].join(' · ');

    return Material(
      color: scheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : onOpen,
        onLongPress: busy ? null : onMore,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.solar_power_outlined, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      design.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${design.capacityLabel} · ${design.panelsLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      design.energyLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (design.shareEnabled || hasSurroundings) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (design.shareEnabled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Shared · ${design.shareViews} view${design.shareViews == 1 ? '' : 's'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          if (hasSurroundings)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Surroundings',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More actions',
                onPressed: busy ? null : onMore,
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
