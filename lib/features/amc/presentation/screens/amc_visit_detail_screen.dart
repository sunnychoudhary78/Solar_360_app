import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/utils/upload_url.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';
import 'package:solar_sales/features/amc/presentation/amc_access.dart';
import 'package:solar_sales/features/amc/presentation/providers/amc_providers.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_status_chip.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/utils/app_snackbar.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';

class AmcVisitDetailScreen extends ConsumerStatefulWidget {
  const AmcVisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<AmcVisitDetailScreen> createState() =>
      _AmcVisitDetailScreenState();
}

class _AmcVisitDetailScreenState extends ConsumerState<AmcVisitDetailScreen> {
  AmcVisit? _visit;
  String _scheduledDate = '';
  String _status = 'scheduled';
  String _assigneeId = '';
  List<AmcChecklistItem> _checklist = const [];
  final _findings = TextEditingController();
  final Map<String, TextEditingController> _noteControllers = {};
  bool _customerSignoff = false;
  bool _saving = false;
  String? _hydratedId;
  String? _photoPreview;

  bool get _isClosed =>
      _status == 'completed' ||
      _status == 'skipped' ||
      _status == 'cancelled';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(amcHomeProvider.notifier).ensureAssigneesLoaded();
    });
  }

  @override
  void dispose() {
    _findings.dispose();
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncNoteControllers(List<AmcChecklistItem> checklist) {
    final keys = checklist.map((e) => e.key).toSet();
    for (final key in _noteControllers.keys.toList()) {
      if (!keys.contains(key)) {
        _noteControllers.remove(key)?.dispose();
      }
    }
    for (final item in checklist) {
      final existing = _noteControllers[item.key];
      if (existing == null) {
        _noteControllers[item.key] = TextEditingController(text: item.notes);
      } else if (existing.text != item.notes) {
        existing.text = item.notes;
      }
    }
  }

  void _hydrate(AmcVisit visit) {
    if (_hydratedId == visit.id) return;
    _hydratedId = visit.id;
    _visit = visit;
    _scheduledDate = visit.scheduledDate;
    _status = visit.status;
    _assigneeId = visit.assigneeId ?? '';
    _checklist = visit.checklist.map((e) => e.copyWith()).toList();
    _syncNoteControllers(_checklist);
    _findings.text = visit.findings;
    _customerSignoff = visit.customerSignoff;
  }

  List<String> get _completeWarnings {
    final progress = amcChecklistProgress(_checklist);
    final notes = <String>[];
    if (progress.total > 0 && progress.done < progress.total) {
      final left = progress.total - progress.done;
      notes.add(
        '$left checklist item${left == 1 ? '' : 's'} still open',
      );
    }
    if (!_customerSignoff) notes.add('Customer has not signed off');
    if ((_visit?.photos ?? const []).isEmpty) {
      notes.add('No site photos attached');
    }
    return notes;
  }

  Future<void> _reload() async {
    _hydratedId = null;
    ref.invalidate(amcVisitDetailProvider(widget.visitId));
  }

  Future<void> _save({String? statusOverride, bool popOnClosed = true}) async {
    if (!AmcAccess.canUpdate(ref.read(authProvider))) {
      showAppSnackBar(context, 'No permission to update visits', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final nextStatus = statusOverride ?? _status;
      final updated = await ref.read(amcApiServiceProvider).updateVisit(
        widget.visitId,
        {
          'scheduled_date': _scheduledDate,
          'status': nextStatus,
          'assignee_id': _assigneeId.isEmpty ? null : _assigneeId,
          'findings': _findings.text.trim(),
          'customer_signoff': _customerSignoff,
          'checklist': _checklist.map((e) => e.toJson()).toList(),
        },
      );
      if (!mounted) return;
      setState(() {
        _visit = updated;
        _hydratedId = updated.id;
        _scheduledDate = updated.scheduledDate;
        _status = updated.status;
        _assigneeId = updated.assigneeId ?? '';
        _checklist = updated.checklist.map((e) => e.copyWith()).toList();
        _syncNoteControllers(_checklist);
        _findings.text = updated.findings;
        _customerSignoff = updated.customerSignoff;
        _saving = false;
      });
      final message = switch (nextStatus) {
        'completed' => 'Visit completed',
        'skipped' => 'Visit skipped',
        'in_progress' => 'Visit started',
        'cancelled' => 'Visit cancelled',
        _ => 'Visit saved',
      };
      showAppSnackBar(context, message);
      ref.invalidate(amcVisitDetailProvider(widget.visitId));
      ref.read(amcHomeProvider.notifier).refresh();
      if (popOnClosed &&
          const ['completed', 'skipped', 'cancelled'].contains(nextStatus)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (e is ApiException && e.statusCode == 401) {
        await ref.read(authProvider.notifier).logout();
        return;
      }
      showAppSnackBar(context, cleanError(e), isError: true);
    }
  }

  Future<void> _pickPhotos() async {
    if (!AmcAccess.canUpdate(ref.read(authProvider))) return;
    final visit = _visit;
    if (visit == null) return;
    if (visit.photos.length >= 8) {
      showAppSnackBar(context, 'Maximum 8 photos per visit', isError: true);
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picker = ImagePicker();
      final paths = <String>[];
      if (source == ImageSource.gallery) {
        final remaining = 8 - visit.photos.length;
        final picked = await picker.pickMultiImage(imageQuality: 85);
        for (final x in picked.take(remaining)) {
          paths.add(x.path);
        }
      } else {
        final shot = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (shot != null) paths.add(shot.path);
      }
      if (paths.isEmpty || !mounted) return;
      setState(() => _saving = true);
      final updated = await ref
          .read(amcApiServiceProvider)
          .uploadPhotos(widget.visitId, paths);
      if (!mounted) return;
      setState(() {
        _visit = updated;
        _saving = false;
      });
      showAppSnackBar(context, 'Photos added');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, cleanError(e), isError: true);
    }
  }

  Future<void> _removePhoto(String path) async {
    final visit = _visit;
    if (visit == null) return;
    setState(() => _saving = true);
    try {
      final photos = visit.photos.where((p) => p != path).toList();
      final updated = await ref.read(amcApiServiceProvider).updateVisit(
        widget.visitId,
        {'photos': photos},
      );
      if (!mounted) return;
      setState(() {
        _visit = updated;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, cleanError(e), isError: true);
    }
  }

  Future<void> _deleteVisit() async {
    if (!AmcAccess.canDelete(ref.read(authProvider))) return;
    final visit = _visit;
    if (visit == null || visit.isCompleted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this visit?'),
        content: const Text(
          'The visit will be cancelled and hidden from the calendar. Completed visits cannot be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(amcApiServiceProvider).removeVisit(widget.visitId);
      if (!mounted) return;
      showAppSnackBar(context, 'Visit removed');
      ref.read(amcHomeProvider.notifier).refresh();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, cleanError(e), isError: true);
    }
  }

  Future<void> _confirmComplete() async {
    final warnings = _completeWarnings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete this visit?'),
        content: Text(
          warnings.isEmpty
              ? 'Checklist, findings, and photos will be saved as the finished visit.'
              : 'You can still complete it. ${warnings.join('. ')}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok == true) await _save(statusOverride: 'completed');
  }

  Future<void> _confirmSkip() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip this visit?'),
        content: const Text(
          'Use skip when the customer postponed or the site was not accessible. You can add an extra visit later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok == true) await _save(statusOverride: 'skipped');
  }

  Future<void> _pickScheduledDate() async {
    final initial = DateTime.tryParse(_scheduledDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _scheduledDate =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  void _updateChecklist(int index, {bool? done, String? notes}) {
    final next = List<AmcChecklistItem>.from(_checklist);
    if (index < 0 || index >= next.length) return;
    next[index] = next[index].copyWith(
      done: done ?? next[index].done,
      notes: notes ?? next[index].notes,
    );
    setState(() {
      _checklist = next;
      if (done == true && _status == 'scheduled') {
        _status = 'in_progress';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final async = ref.watch(amcVisitDetailProvider(widget.visitId));
    final home = ref.watch(amcHomeProvider);
    final canUpdate = AmcAccess.canUpdate(auth);
    final canDelete = AmcAccess.canDelete(auth);
    final scheme = Theme.of(context).colorScheme;

    ref.listen(amcVisitDetailProvider(widget.visitId), (prev, next) {
      next.whenData((visit) {
        if (!mounted) return;
        if (_hydratedId != visit.id) {
          setState(() => _hydrate(visit));
        }
      });
    });

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: _visit?.title.isNotEmpty == true
            ? _visit!.title
            : 'AMC visit',
        actions: [
          if (canDelete && _visit?.status != 'completed')
            IconButton(
              tooltip: 'Remove visit',
              onPressed: _saving ? null : _deleteVisit,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading visit…'),
        error: (e, _) => ErrorState(message: cleanError(e), onRetry: _reload),
        data: (visit) {
          _hydrate(visit);
          final current = _visit ?? visit;
          final progress = amcChecklistProgress(_checklist);
          final readOnly = !canUpdate || _isClosed;
          final assignees = home.assignees;
          final assigneeInList =
              _assigneeId.isEmpty || assignees.any((a) => a.id == _assigneeId);
          final assigneeDropdownValue =
              assigneeInList ? _assigneeId : _assigneeId;

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            AmcStatusChip(status: _status),
                            if (current.isOverdue)
                              const AmcStatusChip(
                                status: 'scheduled',
                                forceOverdueLabel: true,
                              ),
                            if (_customerSignoff)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669)
                                      .withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFF059669)
                                        .withValues(alpha: .25),
                                  ),
                                ),
                                child: const Text(
                                  'Signed off',
                                  style: TextStyle(
                                    color: Color(0xFF059669),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (current.plant != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.outlineVariant
                                    .withValues(alpha: .5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        current.plant!.fullName.isEmpty
                                            ? current.plantLabel
                                            : current.plant!.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        current.plant!.systemSummary.isEmpty
                                            ? 'Installed plant'
                                            : current.plant!.systemSummary,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      if (current
                                          .plant!
                                          .inverterSerialNumber
                                          .isNotEmpty)
                                        Text(
                                          'Inverter ${current.plant!.inverterSerialNumber}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                                if (current.plant!.mobile.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Call',
                                    onPressed: () => launchUrl(
                                      Uri(
                                        scheme: 'tel',
                                        path: current.plant!.mobile,
                                      ),
                                    ),
                                    icon: const Icon(Icons.phone_outlined),
                                  ),
                                if (AmcAccess.canOpenLead(auth) &&
                                    current.leadId.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Lead',
                                    onPressed: () =>
                                        Navigator.of(context).pushNamed(
                                      '/solar/leads/detail',
                                      arguments: current.leadId,
                                    ),
                                    icon: const Icon(Icons.open_in_new),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Visit date'),
                          subtitle: Text(
                            '${formatAmcDate(_scheduledDate)} · ${amcRelativeDue(_scheduledDate)}',
                            style: TextStyle(
                              color: current.isOverdue
                                  ? const Color(0xFFE11D48)
                                  : null,
                              fontWeight: current.isOverdue
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: readOnly
                              ? null
                              : const Icon(Icons.edit_outlined, size: 18),
                          onTap: readOnly ? null : _pickScheduledDate,
                        ),
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'scheduled',
                              child: Text('Scheduled'),
                            ),
                            DropdownMenuItem(
                              value: 'in_progress',
                              child: Text('In progress'),
                            ),
                            DropdownMenuItem(
                              value: 'completed',
                              child: Text('Completed'),
                            ),
                            DropdownMenuItem(
                              value: 'skipped',
                              child: Text('Skipped'),
                            ),
                            DropdownMenuItem(
                              value: 'cancelled',
                              child: Text('Cancelled'),
                            ),
                          ],
                          onChanged: readOnly
                              ? null
                              : (v) => setState(() => _status = v ?? _status),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: assigneeDropdownValue,
                          decoration: const InputDecoration(
                            labelText: 'Technician',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Unassigned'),
                            ),
                            if (!assigneeInList && _assigneeId.isNotEmpty)
                              DropdownMenuItem(
                                value: _assigneeId,
                                child: Text(
                                  current.assignee?.name.isNotEmpty == true
                                      ? current.assignee!.name
                                      : 'Assigned (inactive)',
                                ),
                              ),
                            ...assignees.map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            ),
                          ],
                          onChanged: readOnly
                              ? null
                              : (v) =>
                                  setState(() => _assigneeId = v ?? ''),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'On-site checklist',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            Text(
                              '${progress.done}/${progress.total}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: progress.percent / 100,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(_checklist.length, (index) {
                          final item = _checklist[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                              child: Column(
                                children: [
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: item.done,
                                    onChanged: readOnly
                                        ? null
                                        : (v) => _updateChecklist(
                                              index,
                                              done: v ?? false,
                                            ),
                                    title: Text(
                                      item.label.isEmpty
                                          ? item.key
                                          : item.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        decoration: item.done
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: item.done
                                            ? scheme.onSurfaceVariant
                                            : null,
                                      ),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  TextField(
                                    controller: _noteControllers.putIfAbsent(
                                      item.key,
                                      () => TextEditingController(
                                        text: item.notes,
                                      ),
                                    ),
                                    enabled: !readOnly,
                                    decoration: const InputDecoration(
                                      hintText: 'Notes',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) =>
                                        _updateChecklist(index, notes: v),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        Text(
                          'Findings',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _findings,
                          enabled: !readOnly,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText:
                                'Faults, spare parts needed, customer comments…',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Customer signed off'),
                          value: _customerSignoff,
                          onChanged: readOnly
                              ? null
                              : (v) => setState(() => _customerSignoff = v),
                        ),
                        Row(
                          children: [
                            Text(
                              'Photos',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            if (!readOnly)
                              TextButton.icon(
                                onPressed: _saving ? null : _pickPhotos,
                                icon: const Icon(Icons.add_a_photo_outlined),
                                label: const Text('Add'),
                              ),
                          ],
                        ),
                        if ((current.photos).isEmpty)
                          Text(
                            'No photos yet',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          )
                        else
                          SizedBox(
                            height: 96,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: current.photos.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final path = current.photos[index];
                                final url = resolveStoredUploadUrl(path);
                                return Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _photoPreview = url,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        child: Image.network(
                                          url,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              Container(
                                            width: 96,
                                            height: 96,
                                            color: scheme
                                                .surfaceContainerHighest,
                                            child: const Icon(
                                              Icons.broken_image,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!readOnly)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Material(
                                          color: Colors.black54,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder:
                                                const CircleBorder(),
                                            onTap: () => _removePhoto(path),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(
                                                Icons.close,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          [
                            'Created by ${current.creator?.name ?? '—'}',
                            if (current.createdAt != null)
                              'on ${formatDateTime(current.createdAt)}',
                            if (current.updater?.name != null)
                              '· Updated by ${current.updater!.name}',
                            if (current.updater?.name != null &&
                                current.updatedAt != null)
                              'on ${formatDateTime(current.updatedAt)}',
                          ].join(' '),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (canUpdate && !_isClosed)
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: scheme.outlineVariant
                                  .withValues(alpha: .5),
                            ),
                          ),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            if (_status == 'scheduled')
                              OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => _save(
                                          statusOverride: 'in_progress',
                                          popOnClosed: false,
                                        ),
                                child: const Text('Start visit'),
                              ),
                            OutlinedButton(
                              onPressed: _saving ? null : _confirmSkip,
                              child: const Text('Skip'),
                            ),
                            OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => _save(popOnClosed: false),
                              child: const Text('Save'),
                            ),
                            FilledButton.icon(
                              onPressed: _saving ? null : _confirmComplete,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Complete visit'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (_photoPreview != null)
                Positioned.fill(
                  child: Material(
                    color: Colors.black87,
                    child: Stack(
                      children: [
                        Center(
                          child: InteractiveViewer(
                            child: Image.network(_photoPreview!),
                          ),
                        ),
                        SafeArea(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              onPressed: () =>
                                  setState(() => _photoPreview = null),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
