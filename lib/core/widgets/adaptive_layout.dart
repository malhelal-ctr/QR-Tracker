import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Width from which two columns fit without squeezing the phone-sized cards.
const double twoColumnMinWidth = 840;

/// Phone: one scrolling column ([left] then [right]).
/// Tablet, wide (landscape): two columns side by side.
/// Tablet, narrow (portrait): one centred column with a comfortable reading width.
class TwoPane extends StatelessWidget {
  const TwoPane({super.key, required this.left, required this.right, this.leftFlex = 1, this.rightFlex = 1, this.stackGap = 0});

  final List<Widget> left;
  final List<Widget> right;
  final int leftFlex;
  final int rightFlex;

  /// Space between [left] and [right] when they are stacked in one column.
  final double stackGap;

  @override
  Widget build(BuildContext context) {
    if (!isTablet) {
      return ListView(padding: EdgeInsets.all(16.r), children: [...left, SizedBox(height: stackGap), ...right]);
    }
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < twoColumnMinWidth) {
        return ListView(
          padding: EdgeInsets.symmetric(vertical: 24.r, horizontal: ((box.maxWidth - 600.r) / 2).clamp(24.r, double.infinity)),
          children: [...left, SizedBox(height: stackGap), ...right],
        );
      }
      return SingleChildScrollView(
        padding: EdgeInsets.all(24.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
            SizedBox(width: 24.r),
            Expanded(flex: rightFlex, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
          ],
        ),
      );
    });
  }
}
