import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Large number field with −/+ buttons (steps of [step]).
class StepperField extends StatelessWidget {
  const StepperField({super.key, required this.controller, required this.color, this.step = 100});

  final TextEditingController controller;
  final Color color;
  final int step;

  void _add(int by) {
    final v = (int.tryParse(controller.text) ?? 0) + by;
    controller.text = '${v < 0 ? 0 : v}';
  }

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, int by) => SizedBox(
          width: 64.r,
          child: IconButton(
            style: IconButton.styleFrom(backgroundColor: C.high, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
            icon: Icon(icon, color: C.onSurface),
            onPressed: () => _add(by),
          ),
        );

    return Container(
      height: 80.r,
      padding: EdgeInsets.all(6.r),
      decoration: BoxDecoration(color: C.lowest, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: C.outlineVariant, width: 1.5.r)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          button(Icons.remove, -step),
          Expanded(
            child: Center(
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: mono(38, weight: FontWeight.w700, color: color),
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: '0',
                  hintStyle: mono(38, weight: FontWeight.w700, color: C.highest),
                  isCollapsed: true,
                ),
              ),
            ),
          ),
          button(Icons.add, step),
        ],
      ),
    );
  }
}
