import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Text field for typing a code when the camera can't read it.
class ManualEntry extends StatefulWidget {
  const ManualEntry({super.key, required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<ManualEntry> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSubmit(_text.text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: 16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MicroLabel('Camera can’t read it? Type the code'),
            SizedBox(height: 8.r),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  style: mono(16, weight: FontWeight.w600),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  // keep the keyboard open so several codes can be typed in a row
                  onEditingComplete: () {},
                  decoration: const InputDecoration(hintText: 'e.g. LT-2026-012450', prefixIcon: Icon(Icons.keyboard_outlined)),
                ),
              ),
              SizedBox(width: 10.r),
              SizedBox.square(
                dimension: 56.r,
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: C.high, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                  icon: const Icon(Icons.arrow_forward, color: C.onSurface),
                  onPressed: _submit,
                ),
              ),
            ]),
          ],
        ),
      );
}
