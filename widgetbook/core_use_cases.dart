import 'package:flutter/material.dart';
import 'package:qr_tracker/core/theme/app_theme.dart';
import 'package:qr_tracker/core/utils/period.dart';
import 'package:qr_tracker/core/widgets/app_widgets.dart';
import 'package:qr_tracker/core/widgets/date_row.dart';
import 'package:qr_tracker/core/widgets/field_label.dart';
import 'package:qr_tracker/core/widgets/history_header.dart';
import 'package:qr_tracker/core/widgets/period_chips.dart';
import 'package:qr_tracker/core/widgets/stepper_field.dart';
import 'package:widgetbook/widgetbook.dart';

const _icons = <String, IconData?>{
  'none': null,
  'qr_code_scanner': Icons.qr_code_scanner,
  'check_circle': Icons.check_circle_outline,
  'inventory': Icons.inventory_2_outlined,
  'warning': Icons.warning_amber_rounded,
  'insights': Icons.insights,
};

IconData? _icon(BuildContext context, {String label = 'Icon', String initial = 'none'}) =>
    _icons[context.knobs.object.dropdown(label: label, options: _icons.keys.toList(), initialOption: initial)];

void _tap() {}

final coreUseCases = <WidgetbookNode>[
  WidgetbookComponent(name: 'TrackerAppBar', useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (context) => TrackerAppBar(context.knobs.string(label: 'Screen', initialValue: 'Dashboard')),
    ),
  ]),
  WidgetbookComponent(name: 'BigButton', useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (context) => BigButton(
        label: context.knobs.string(label: 'Label', initialValue: 'Scan now'),
        icon: _icon(context, initial: 'qr_code_scanner'),
        style: context.knobs.object.dropdown(label: 'Style', options: BigButtonStyle.values, labelBuilder: (s) => s.name),
        onPressed: context.knobs.boolean(label: 'Enabled', initialValue: true) ? _tap : null,
      ),
    ),
    WidgetbookUseCase(
      name: 'All styles',
      builder: (context) => Column(children: [
        for (final s in BigButtonStyle.values) ...[
          BigButton(label: s.name, icon: Icons.bolt, style: s, onPressed: _tap),
          const SizedBox(height: 12),
        ],
      ]),
    ),
  ]),
  WidgetbookComponent(name: 'Pill', useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (context) => Align(
        alignment: Alignment.centerLeft,
        child: Pill(
          context.knobs.string(label: 'Text', initialValue: 'GOAL MET'),
          kind: context.knobs.object.dropdown(label: 'Kind', options: PillKind.values, labelBuilder: (k) => k.name),
          solid: context.knobs.boolean(label: 'Solid'),
          icon: _icon(context),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'All kinds',
      builder: (context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final solid in [false, true])
          for (final k in PillKind.values) Pill(k.name.toUpperCase(), kind: k, solid: solid),
      ]),
    ),
  ]),
  WidgetbookComponent(name: 'Meter', useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (context) => Meter(
        context.knobs.double.slider(label: 'Value', initialValue: 0.62, min: 0, max: 1),
        color: context.knobs.boolean(label: 'Solid green') ? C.success : null,
      ),
    ),
  ]),
  WidgetbookComponent(name: 'Metric', useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (context) => Metric(
        label: context.knobs.string(label: 'Label', initialValue: 'On hand'),
        value: context.knobs.string(label: 'Value', initialValue: '12,480'),
        unit: context.knobs.stringOrNull(label: 'Unit', initialValue: 'lids'),
        caption: context.knobs.stringOrNull(label: 'Caption', initialValue: 'Enough for the list'),
        icon: _icon(context),
      ),
    ),
    WidgetbookUseCase(
      name: 'Pair',
      builder: (context) => const Pair(
        Metric(label: 'Done', icon: Icons.check_circle_outline, value: '64%', caption: '32,000 printed'),
        Metric(label: 'Remaining', icon: Icons.pending_actions, value: '18,000', caption: '36% of list'),
      ),
    ),
  ]),
  WidgetbookComponent(name: 'Panel', useCases: [
    WidgetbookUseCase(
      name: 'With section title',
      builder: (context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(
            context.knobs.string(label: 'Title', initialValue: 'Lid stock'),
            icon: _icon(context, initial: 'inventory'),
            color: C.primary,
            upper: context.knobs.boolean(label: 'Uppercase'),
            trailing: const Pill('IN STOCK', kind: PillKind.success),
          ),
          const MicroLabel('Micro label', icon: Icons.tune),
          const SizedBox(height: 8),
          const Tile(child: Text('Inner tile')),
        ]),
      ),
    ),
  ]),
  WidgetbookComponent(name: 'IconTile', useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (context) => Row(children: [
        IconTile(_icon(context, initial: 'inventory') ?? Icons.circle),
        const SizedBox(width: 12),
        const Dot(),
        const SizedBox(width: 8),
        const Dot(color: C.danger),
      ]),
    ),
  ]),
  WidgetbookComponent(name: 'DateRow', useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (context) => DateRow(
        label: context.knobs.string(label: 'Label', initialValue: 'Date'),
        date: context.knobs.dateTime(label: 'Date', initialValue: DateTime.now(), start: DateTime(2020), end: DateTime(2030)),
        badge: context.knobs.stringOrNull(label: 'Badge', initialValue: null),
        onTap: _tap,
      ),
    ),
  ]),
  WidgetbookComponent(name: 'FieldLabel', useCases: [
    WidgetbookUseCase(name: 'Default', builder: (context) => FieldLabel(context.knobs.string(label: 'Text', initialValue: 'Counter reading'))),
  ]),
  WidgetbookComponent(name: 'HistoryHeader', useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (context) => HistoryHeader(count: context.knobs.int.slider(label: 'Count', initialValue: 3, max: 50)),
    ),
  ]),
  WidgetbookComponent(name: 'PeriodChips', useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (context) {
        final preset = context.knobs.object.dropdown(label: 'Preset', options: PeriodPreset.values, labelBuilder: (p) => p.name);
        final (from, to) = presetRange(preset, days: const []);
        return PeriodChips(preset: preset, from: from, to: to, onPreset: (_) {}, onRange: (_, _) {});
      },
    ),
  ]),
  WidgetbookComponent(name: 'StepperField', useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (context) => StepperField(
        controller: TextEditingController(text: '1200'),
        color: context.knobs.color(label: 'Color', initialValue: C.success),
        step: context.knobs.int.input(label: 'Step', initialValue: 100),
      ),
    ),
  ]),
];
