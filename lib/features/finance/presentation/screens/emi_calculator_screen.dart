import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/finance/data/emi_calculator.dart';
import 'package:solar_sales/features/finance/data/finance_api_service.dart';
import 'package:solar_sales/shared/utils/pdf_helper.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class EmiCalculatorScreen extends ConsumerStatefulWidget {
  const EmiCalculatorScreen({
    super.key,
    this.moduleLabel = 'Finance',
  });

  /// Shown in the app bar subtitle (Billbook vs Green Energy).
  final String moduleLabel;

  @override
  ConsumerState<EmiCalculatorScreen> createState() =>
      _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends ConsumerState<EmiCalculatorScreen> {
  String _segment = 'Residential';
  EmiScheme _scheme = EmiScheme.emi;
  double _amount = 100000;
  int _months = 6;
  double _rate = kDefaultInterestRate;
  String _openYear = 'Year 1';
  bool _downloading = false;
  bool _sharing = false;

  double get _committedAmount =>
      clampNum(_amount, kEmiMinAmount, kEmiMaxAmount);

  int get _committedMonths =>
      clampNum(_months, kEmiMinMonths, kEmiMaxMonths).round();

  double get _committedRate => clampNum(_rate, 0, 36);

  bool get _rateLocked =>
      _scheme == EmiScheme.advanceEmi &&
      _committedMonths <= kAdvanceZeroMonths;

  double get _effectiveRate => _rateLocked ? 0 : _committedRate;

  EmiScheduleResult get _result => buildSchedule(
        principal: _committedAmount,
        annualPercent: _effectiveRate,
        months: _committedMonths,
        scheme: _scheme,
      );

  void _reset() {
    setState(() {
      _segment = 'Residential';
      _scheme = EmiScheme.emi;
      _amount = 100000;
      _months = 6;
      _rate = kDefaultInterestRate;
      _openYear = 'Year 1';
    });
  }

  Future<void> _downloadPdf({required bool share}) async {
    if (_downloading || _sharing) return;
    setState(() {
      if (share) {
        _sharing = true;
      } else {
        _downloading = true;
      }
    });
    try {
      final bytes = await ref.read(financeApiServiceProvider).downloadEmiPdf(
            segment: _segment,
            scheme: _scheme,
            amount: _committedAmount,
            months: _committedMonths,
            rate: _committedRate,
            includeGuide: false,
          );
      final slug = _segment.toLowerCase().replaceAll(' ', '-');
      final filename = 'solar-loan-emi-$slug.pdf';
      if (share) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/pdf')],
            subject: 'Solar loan EMI estimate',
            text: '$_segment · ${_scheme.caption}',
          ),
        );
      } else {
        await PdfHelper.saveAndOpen(bytes, filename: filename);
        if (mounted) {
          showAppMessage(context, 'PDF downloaded — you can share it with the client');
        }
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(context, '$error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _sharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canAccess = auth.hasPermission('quotation.read') ||
        auth.hasPermission('invoice.read') ||
        auth.hasPermission('module.billbook.access') ||
        auth.hasPermission('lead.read') ||
        auth.hasPermission('leads.read') ||
        auth.hasPermission('module.solar.access');

    final scheme = Theme.of(context).colorScheme;
    final result = _result;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Finance',
        subtitle: '${widget.moduleLabel} · EMI calculator',
      ),
      body: !canAccess
          ? const EmptyState(
              title: 'Finance is not available',
              subtitle:
                  'Your role does not include Finance access. Ask an admin to grant permission.',
              icon: Icons.lock_outline_rounded,
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                _SegmentChips(
                  selected: _segment,
                  onChanged: (v) => setState(() => _segment = v),
                ),
                const SizedBox(height: 14),
                PremiumCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SchemePicker(
                        scheme: _scheme,
                        onChanged: (v) => setState(() {
                          _scheme = v;
                          _openYear = 'Year 1';
                        }),
                      ),
                      const SizedBox(height: 18),
                      _AmountField(
                        amount: _amount,
                        onChanged: (v) => setState(() {
                          // Do not hard-clamp while typing; blur / presets clamp.
                          _amount = v.isNaN || v.isInfinite ? _amount : v;
                          _openYear = 'Year 1';
                        }),
                        onCommit: (v) => setState(() {
                          _amount = clampNum(v, kEmiMinAmount, kEmiMaxAmount);
                          _openYear = 'Year 1';
                        }),
                      ),
                      const SizedBox(height: 18),
                      _TenureField(
                        months: _months,
                        onChanged: (v) => setState(() {
                          _months = v;
                          _openYear = 'Year 1';
                        }),
                        onCommit: (v) => setState(() {
                          _months =
                              clampNum(v, kEmiMinMonths, kEmiMaxMonths).round();
                          _openYear = 'Year 1';
                        }),
                      ),
                      const SizedBox(height: 18),
                      _RateField(
                        rate: _rate,
                        locked: _rateLocked,
                        onChanged: (v) => setState(() {
                          _rate = v.isNaN || v.isInfinite ? _rate : v;
                          _openYear = 'Year 1';
                        }),
                        onCommit: (v) => setState(() {
                          _rate = clampNum(v, 0, 36);
                          _openYear = 'Year 1';
                        }),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _reset,
                            child: const Text('Reset'),
                          ),
                          FilledButton.icon(
                            onPressed: _downloading
                                ? null
                                : () => _downloadPdf(share: false),
                            icon: _downloading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 18),
                            label: Text(
                              _downloading ? 'Preparing…' : 'Download PDF',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                _sharing ? null : () => _downloadPdf(share: true),
                            icon: _sharing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.share_rounded, size: 18),
                            label: Text(_sharing ? 'Sharing…' : 'Share'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SummaryCard(
                  segment: _segment,
                  scheme: _scheme,
                  displayRate: _effectiveRate,
                  result: result,
                ),
                const SizedBox(height: 14),
                _RepaymentTable(
                  years: result.years,
                  months: result.months,
                  openYear: _openYear,
                  onToggle: (key) => setState(() {
                    _openYear = _openYear == key ? '' : key;
                  }),
                ),
              ],
            ),
    );
  }
}

class _SegmentChips extends StatelessWidget {
  const _SegmentChips({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kFinanceSegments.map((item) {
        final active = selected == item;
        return ChoiceChip(
          label: Text(item),
          selected: active,
          onSelected: (_) => onChanged(item),
          selectedColor: scheme.primary,
          labelStyle: TextStyle(
            color: active ? scheme.onPrimary : scheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}

class _SchemePicker extends StatelessWidget {
  const _SchemePicker({required this.scheme, required this.onChanged});

  final EmiScheme scheme;
  final ValueChanged<EmiScheme> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scheme',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        RadioGroup<EmiScheme>(
          groupValue: scheme,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          child: Column(
            children: [
              const RadioListTile<EmiScheme>(
                value: EmiScheme.emi,
                title: Text('EMI'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              RadioListTile<EmiScheme>(
                value: EmiScheme.advanceEmi,
                title: Row(
                  children: [
                    const Text('Advance EMI'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '0 interest · 6 months',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountField extends StatefulWidget {
  const _AmountField({
    required this.amount,
    required this.onChanged,
    required this.onCommit,
  });

  final double amount;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommit;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.amount.round().toString());
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) return;
    final next = widget.amount.round().toString();
    if (_controller.text != next) {
      _controller.text = next;
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    final parsed = double.tryParse(_controller.text) ?? widget.amount;
    final clamped = clampNum(parsed, kEmiMinAmount, kEmiMaxAmount);
    widget.onCommit(clamped);
    final text = clamped.round().toString();
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan amount',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: '₹ ',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (raw) {
            final v = double.tryParse(raw);
            if (v != null) widget.onChanged(v);
          },
          onEditingComplete: () {
            _focusNode.unfocus();
          },
        ),
        Slider(
          value: widget.amount.clamp(kEmiMinAmount, kEmiMaxAmount),
          min: kEmiMinAmount,
          max: kEmiMaxAmount,
          divisions: ((kEmiMaxAmount - kEmiMinAmount) / 10000).round(),
          label: formatEmiInr(widget.amount),
          onChanged: widget.onCommit,
        ),
        _PresetRow(
          items: kAmountPresets
              .map((e) => (label: e.label, value: e.value))
              .toList(),
          selected: widget.amount,
          onPick: widget.onCommit,
        ),
      ],
    );
  }
}

class _TenureField extends StatefulWidget {
  const _TenureField({
    required this.months,
    required this.onChanged,
    required this.onCommit,
  });

  final int months;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onCommit;

  @override
  State<_TenureField> createState() => _TenureFieldState();
}

class _TenureFieldState extends State<_TenureField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.months.toString());
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _TenureField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) return;
    final next = widget.months.toString();
    if (_controller.text != next) {
      _controller.text = next;
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    final parsed = int.tryParse(_controller.text) ?? widget.months;
    final clamped =
        clampNum(parsed, kEmiMinMonths, kEmiMaxMonths).round();
    widget.onCommit(clamped);
    final text = clamped.toString();
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan term',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            suffixText: 'months',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (raw) {
            final v = int.tryParse(raw);
            if (v != null) widget.onChanged(v);
          },
          onEditingComplete: () {
            _focusNode.unfocus();
          },
        ),
        Slider(
          value: widget.months.toDouble().clamp(
                kEmiMinMonths.toDouble(),
                kEmiMaxMonths.toDouble(),
              ),
          min: kEmiMinMonths.toDouble(),
          max: kEmiMaxMonths.toDouble(),
          divisions: kEmiMaxMonths - kEmiMinMonths,
          label: '${widget.months} mo',
          onChanged: (v) => widget.onCommit(v.round()),
        ),
        _PresetRow(
          items: kTenurePresets
              .map((e) => (label: e.label, value: e.value.toDouble()))
              .toList(),
          selected: widget.months.toDouble(),
          onPick: (v) => widget.onCommit(v.round()),
        ),
      ],
    );
  }
}

class _RateField extends StatefulWidget {
  const _RateField({
    required this.rate,
    required this.locked,
    required this.onChanged,
    required this.onCommit,
  });

  final double rate;
  final bool locked;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommit;

  @override
  State<_RateField> createState() => _RateFieldState();
}

class _RateFieldState extends State<_RateField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  String _formatRate(double rate) => rate.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatRate(widget.locked ? 0 : widget.rate),
    );
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _RateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locked != oldWidget.locked) {
      final next = _formatRate(widget.locked ? 0 : widget.rate);
      if (_controller.text != next) {
        _controller.text = next;
      }
      return;
    }
    if (_focusNode.hasFocus || widget.locked) return;
    final next = _formatRate(widget.rate);
    if (_controller.text != next) {
      _controller.text = next;
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus || widget.locked) return;
    final parsed = double.tryParse(_controller.text) ?? widget.rate;
    final clamped = clampNum(parsed, 0, 36);
    widget.onCommit(clamped);
    final text = _formatRate(clamped);
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interest rate (% p.a.)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !widget.locked,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            suffixText: '%',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (raw) {
            final v = double.tryParse(raw);
            if (v != null) widget.onChanged(v);
          },
          onEditingComplete: () {
            _focusNode.unfocus();
          },
        ),
        if (widget.locked) ...[
          const SizedBox(height: 6),
          Text(
            'Advance EMI on a 6-month term is interest-free.',
            style: TextStyle(
              fontSize: 12,
              color: scheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.items,
    required this.selected,
    required this.onPick,
  });

  final List<({String label, double value})> items;
  final double selected;
  final ValueChanged<double> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((item) {
        final active = (selected - item.value).abs() < 0.5;
        return InkWell(
          onTap: () => onPick(item.value),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? scheme.primary.withValues(alpha: 0.12)
                  : scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: active
                    ? scheme.primary.withValues(alpha: 0.35)
                    : scheme.outlineVariant,
              ),
            ),
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.segment,
    required this.scheme,
    required this.displayRate,
    required this.result,
  });

  final String segment;
  final EmiScheme scheme;
  final double displayRate;
  final EmiScheduleResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow(
            context,
            'Interest rate',
            '${displayRate.toStringAsFixed(2)}%',
            accent: true,
          ),
          _summaryRow(context, 'Loan amount', formatEmiInr(result.principal)),
          _summaryRow(context, 'Loan term', formatTenure(result.months)),
          _summaryRow(
            context,
            'Total interest',
            formatEmiScheduleInr(result.totalInterest),
          ),
          _summaryRow(
            context,
            'Total repayment',
            formatEmiScheduleInr(result.totalPayment),
          ),
          const Divider(height: 24),
          Text(
            'EMI',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            formatEmiScheduleInr(result.emi),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '$segment · ${scheme.caption}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool accent = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: accent ? 16 : 13,
              color: accent ? scheme.primary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepaymentTable extends StatelessWidget {
  const _RepaymentTable({
    required this.years,
    required this.months,
    required this.openYear,
    required this.onToggle,
  });

  final List<EmiYearGroup> years;
  final int months;
  final String openYear;
  final ValueChanged<String> onToggle;

  /// Short tenures (< 1 year) show e.g. "6 Months" instead of "Year 1".
  String _groupLabel(String yearKey) {
    if (months < 12 && yearKey == 'Year 1') {
      return '$months Month${months == 1 ? '' : 's'}';
    }
    return yearKey;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repayment table',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Principal, interest, and total payment by month.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                _headerCell('Principal'),
                _headerCell('Interest'),
                _headerCell('EMI'),
              ],
            ),
          ),
          ...years.map((year) {
            final open = openYear == year.key;
            return Column(
              children: [
                InkWell(
                  onTap: () => onToggle(year.key),
                  child: Container(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          open
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _groupLabel(year.key),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _moneyCell(formatEmiScheduleInr(year.principal)),
                        _moneyCell(formatEmiScheduleInr(year.interest)),
                        _moneyCell(formatEmiScheduleInr(year.payment)),
                      ],
                    ),
                  ),
                ),
                if (open)
                  ...year.months.map(
                    (row) => Padding(
                      padding: const EdgeInsets.fromLTRB(40, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.label,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          _moneyCell(formatEmiScheduleInr(row.principal)),
                          _moneyCell(formatEmiScheduleInr(row.interest)),
                          _moneyCell(formatEmiScheduleInr(row.payment)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _moneyCell(String text) {
    return SizedBox(
      width: 96,
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _headerCell(String text) {
    return SizedBox(
      width: 96,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
