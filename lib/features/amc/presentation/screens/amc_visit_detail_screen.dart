import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
  AmcVisit? _draft;
  final _findings = TextEditingController();
  bool _saving = false;
  String? _hydratedId;

  @override
  void dispose() {
    _findings.dispose();
    super.dispose();
  }

  void _ensureHydrated(AmcVisit visit) {
    if (_hydratedId == visit.id && _draft != null) return;
    _hydratedId = visit.id;
    _draft = visit;
    _findings.text = visit.findings;
  }

  Future<void> _reload() async {
    _hydratedId = null;
    _draft = null;
    ref.invalidate(amcVisitDetailProvider(widget.visitId));
  }

  Future<void> _save({String? status}) async {
    final draft = _draft;
    if (draft == null) return;
    if (!AmcAccess.canUpdateVisit(ref.read(authProvider))) {
      showAppSnackBar(context, 'No permission to update visits', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'checklist': draft.checklist.map((e) => e.toJson()).toList(),
        'findings': _findings.text.trim(),
        'customer_signoff': draft.customerSignoff,
        'photos': draft.photos,
        'assignee_id': draft.assigneeId,
        if (draft.scheduledDate.isNotEmpty)
          'scheduled_date': draft.scheduledDate,
        'status': ?status,
      };
      final updated = await ref
          .read(amcApiServiceProvider)
          .updateVisit(widget.visitId, body);
      if (!mounted) return;
      setState(() {
        _draft = updated;
        _findings.text = updated.findings;
        _hydratedId = updated.id;
        _saving = false;
      });
      final message = switch (status) {
        'completed' => 'Visit completed',
        'skipped' => 'Visit skipped',
        'cancelled' => 'Visit cancelled',
        'in_progress' => 'Marked in progress',
        _ => 'Progress saved',
      };
      showAppSnackBar(context, message);
      ref.invalidate(amcVisitDetailProvider(widget.visitId));
      ref.read(amcHomeProvider.notifier).refresh();
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
    if (!AmcAccess.canUpdateVisit(ref.read(authProvider))) {
      showAppSnackBar(context, 'No permission to upload photos', isError: true);
      return;
    }
    final draft = _draft;
    if (draft == null) return;
    if (draft.photos.length >= 8) {
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
        final remaining = 8 - draft.photos.length;
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
        _draft = updated;
        _hydratedId = updated.id;
        _saving = false;
      });
      showAppSnackBar(context, 'Photos uploaded');
      ref.invalidate(amcVisitDetailProvider(widget.visitId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, cleanError(e), isError: true);
    }
  }

  Future<void> _removePhoto(String path) async {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _draft = draft.copyWith(
        photos: draft.photos.where((p) => p != path).toList(),
      );
    });
    await _save();
  }

  Future<void> _deleteVisit() async {
    if (!AmcAccess.canDeleteVisit(ref.read(authProvider))) {
      showAppSnackBar(context, 'No permission to delete visits', isError: true);
      return;
    }
    final draft = _draft;
    if (draft == null || draft.isCompleted) {
      showAppSnackBar(
        context,
        'Completed visits cannot be removed',
        isError: true,
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove visit?'),
        content: const Text('This cancels and soft-deletes the visit.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
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

  Future<void> _pickAssignee(List<AmcAssignee> assignees) async {
    final draft = _draft;
    if (draft == null) return;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Assign technician')),
            ListTile(
              title: const Text('Unassigned'),
              onTap: () => Navigator.pop(context, ''),
            ),
            ...assignees.map(
              (a) => ListTile(
                title: Text(a.optionLabel),
                selected: a.id == draft.assigneeId,
                onTap: () => Navigator.pop(context, a.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.isEmpty) {
      setState(() => _draft = draft.copyWith(clearAssignee: true));
      return;
    }
    AmcAssignee? match;
    for (final a in assignees) {
      if (a.id == selected) {
        match = a;
        break;
      }
    }
    setState(() {
      _draft = draft.copyWith(assigneeId: selected, assignee: match);
    });
  }

  Future<void> _pickScheduledDate() async {
    final draft = _draft;
    if (draft == null) return;
    final initial = DateTime.tryParse(draft.scheduledDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final value =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    setState(() => _draft = draft.copyWith(scheduledDate: value));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final async = ref.watch(amcVisitDetailProvider(widget.visitId));
    final home = ref.watch(amcHomeProvider);
    final canUpdate = AmcAccess.canUpdateVisit(auth);
    final canDelete = AmcAccess.canDeleteVisit(auth);
    final scheme = Theme.of(context).colorScheme;

    ref.listen(amcVisitDetailProvider(widget.visitId), (prev, next) {
      next.whenData((visit) {
        if (!mounted) return;
        if (_hydratedId != visit.id || _draft == null) {
          setState(() => _ensureHydrated(visit));
        }
      });
    });

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Visit detail',
        actions: [
          if (canDelete)
            IconButton(
              tooltip: 'Remove visit',
              onPressed: _saving ? null : _deleteVisit,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading visit…'),
        error: (e, _) => ErrorState(
          message: cleanError(e),
          onRetry: _reload,
        ),
        data: (visit) {
          _ensureHydrated(visit);
          final draft = _draft ?? visit;
          final readOnly = !canUpdate || draft.isCompleted;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            draft.title.isEmpty
                                ? 'AMC visit ${draft.visitNo}'
                                : draft.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        AmcStatusChip(
                          status: draft.status,
                          isOverdue: draft.isOverdue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      draft.plantLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _InfoTile(
                      icon: Icons.event_outlined,
                      label: 'Scheduled',
                      value: formatAmcDate(draft.scheduledDate),
                      onTap: readOnly ? null : _pickScheduledDate,
                    ),
                    _InfoTile(
                      icon: Icons.person_outline,
                      label: 'Technician',
                      value: draft.assignee?.name.isNotEmpty == true
                          ? draft.assignee!.name
                          : 'Unassigned',
                      onTap: readOnly
                          ? null
                          : () => _pickAssignee(home.assignees),
                    ),
                    if (draft.contract != null)
                      _InfoTile(
                        icon: Icons.assignment_outlined,
                        label: 'Contract',
                        value:
                            '${draft.contract!.visitsPerYear}/yr · ${draft.contract!.status}',
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Checklist',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(draft.checklist.length, (index) {
                      final item = draft.checklist[index];
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
                                    : (v) {
                                        final next =
                                            List<AmcChecklistItem>.from(
                                          draft.checklist,
                                        );
                                        next[index] =
                                            item.copyWith(done: v ?? false);
                                        setState(() {
                                          _draft =
                                              draft.copyWith(checklist: next);
                                        });
                                      },
                                title: Text(
                                  item.label.isEmpty ? item.key : item.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                              TextFormField(
                                initialValue: item.notes,
                                enabled: !readOnly,
                                decoration: const InputDecoration(
                                  hintText: 'Notes',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) {
                                  final next = List<AmcChecklistItem>.from(
                                    (_draft ?? draft).checklist,
                                  );
                                  if (index >= next.length) return;
                                  next[index] =
                                      next[index].copyWith(notes: v);
                                  _draft =
                                      (_draft ?? draft).copyWith(checklist: next);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (draft.checklist.isEmpty)
                      Text(
                        'No checklist items from server.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Findings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _findings,
                      enabled: !readOnly,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Site findings…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Customer sign-off'),
                      value: draft.customerSignoff,
                      onChanged: readOnly
                          ? null
                          : (v) {
                              setState(() {
                                _draft = draft.copyWith(customerSignoff: v);
                              });
                            },
                    ),
                    const SizedBox(height: 8),
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
                    if (draft.photos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No photos yet',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    else
                      SizedBox(
                        height: 96,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: draft.photos.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final path = draft.photos[index];
                            final url = resolveStoredUploadUrl(path);
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                  child: Image.network(
                                    url,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 96,
                                      height: 96,
                                      color: scheme.surfaceContainerHighest,
                                      child: const Icon(Icons.broken_image),
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
                                        customBorder: const CircleBorder(),
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
                  ],
                ),
              ),
              if (canUpdate && !draft.isCompleted)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: .5),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : () => _save(),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save progress'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => _save(status: 'skipped'),
                                child: const Text('Skip'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: _saving
                                    ? null
                                    : () async {
                                        if (draft.status == 'scheduled') {
                                          await _save(status: 'in_progress');
                                        }
                                        if (!mounted) return;
                                        await _save(status: 'completed');
                                      },
                                child: const Text('Complete'),
                              ),
                            ),
                          ],
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: onTap == null ? null : const Icon(Icons.edit_outlined, size: 18),
      onTap: onTap,
    );
  }
}
