import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../model/import_preview.dart';

/// Bottom sheet showing the picked file before import. Pops with true once imported.
class ImportSheet extends StatefulWidget {
  const ImportSheet({super.key, required this.preview, required this.hasExistingList, required this.onImport});

  final ImportPreview preview;
  final bool hasExistingList;
  final Future<void> Function(ImportPreview preview) onImport;

  @override
  State<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<ImportSheet> {
  late ImportPreview _preview = widget.preview;

  @override
  Widget build(BuildContext context) {
    final list = _preview.codes;
    final dupes = _preview.duplicates;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.r, 0.r, 16.r, 16.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MicroLabel('Import preview', icon: Icons.upload, color: C.primary),
              SizedBox(height: 8.r),
              Text(_preview.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(28, weight: FontWeight.w700)),
              SizedBox(height: 12.r),
              Tile(
                color: C.lowest,
                child: Row(children: [
                  IconTile(Icons.verified_outlined, color: Color(0x2625A475), iconColor: C.success, size: 40.r),
                  SizedBox(width: 12.r),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${fmt(list.length)} codes', style: sans(18, weight: FontWeight.w700)),
                        if (dupes > 0) Text('⚠ ${fmt(dupes)} duplicates (first one is used)', style: mono(13, weight: FontWeight.w600, color: C.warning)),
                      ],
                    ),
                  ),
                ]),
              ),
              SizedBox(height: 12.r),
              _CheckTile(
                value: _preview.hasHeader,
                onChanged: (v) => setState(() => _preview = _preview.copyWith(hasHeader: v)),
                title: 'First row is a header',
                subtitle: 'Skip the first row (a column title like “QR Code”)',
              ),
              if (widget.hasExistingList) ...[
                SizedBox(height: 10.r),
                _CheckTile(
                  value: _preview.clearScans,
                  onChanged: (v) => setState(() => _preview = _preview.copyWith(clearScans: v)),
                  title: 'Clear old scans',
                  subtitle: 'Their positions belong to the old list',
                  danger: true,
                ),
              ],
              SizedBox(height: 16.r),
              const Row(children: [Expanded(child: MicroLabel('Code sequence')), MicroLabel('Column 1', color: C.primary)]),
              SizedBox(height: 8.r),
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Column(children: [
                  Container(
                    color: C.low,
                    padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 10.r),
                    child: Row(children: [SizedBox(width: 96.r, child: MicroLabel('Row')), MicroLabel('QR data')]),
                  ),
                  for (var i = 0; i < list.length && i < 5; i++) _CodeLine(index: i + 1, code: list[i], shade: i.isEven),
                  if (list.length > 6)
                    Container(
                      color: C.low,
                      padding: EdgeInsets.symmetric(vertical: 10.r),
                      alignment: Alignment.center,
                      child: MicroLabel('⋮  ${fmt(list.length - 6)} more codes'),
                    ),
                  if (list.length > 5) _CodeLine(index: list.length, code: list.last, last: true),
                ]),
              ),
              SizedBox(height: 16.r),
              Row(children: [
                SizedBox(width: 120.r, child: BigButton(label: 'Cancel', style: BigButtonStyle.tonal, onPressed: () => Navigator.pop(context, false))),
                SizedBox(width: 12.r),
                Expanded(
                  child: BigButton(
                    label: 'Import (${fmt(list.length)})',
                    icon: Icons.download_done,
                    onPressed: list.isEmpty
                        ? null
                        : () async {
                            await widget.onImport(_preview);
                            if (context.mounted) Navigator.pop(context, true);
                          },
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.value, required this.onChanged, required this.title, required this.subtitle, this.danger = false});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;
  final bool danger;

  @override
  Widget build(BuildContext context) => Material(
        color: C.low,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: EdgeInsets.fromLTRB(4.r, 8.r, 12.r, 8.r),
            child: Row(children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: danger ? C.dangerContainer : const Color(0xFF3B82F6),
                checkColor: Colors.white,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: sans(16, weight: FontWeight.w600, color: danger ? C.danger : C.onSurface)),
                    Text(subtitle, style: sans(13, color: C.onVariant)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}

class _CodeLine extends StatelessWidget {
  const _CodeLine({required this.index, required this.code, this.shade = false, this.last = false});

  final int index;
  final String code;
  final bool shade;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        color: last ? C.primaryContainer.withValues(alpha: 0.3) : (shade ? C.lowest : const Color(0xFF0A1122)),
        padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 12.r),
        child: Row(children: [
          SizedBox(width: 96.r, child: Text('#${fmt(index)}', style: mono(14, weight: FontWeight.w600, color: last ? C.primary : C.onVariant))),
          Expanded(child: Text(code, overflow: TextOverflow.ellipsis, style: mono(17, weight: FontWeight.w600, color: last ? C.success : C.onSurface))),
        ]),
      );
}
