import 'package:sizer/sizer.dart';

/// Phone screens follow the Stitch design frame (375 wide). Tablets use a wider 720 frame,
/// so they get more room for content (side rail, two columns) instead of oversized controls.
double get _designFrame => Device.screenType == ScreenType.mobile ? 375 : 720;

bool get isTablet => Device.screenType != ScreenType.mobile;

/// Screen / design ratio from sizer's `vmin` (percent of the shortest screen side), so the
/// layout keeps its proportions in portrait and landscape. Clamped to stay usable on very
/// small or very large screens.
double get _scale => (100 / _designFrame).vmin.clamp(0.85, 1.4).toDouble();

extension ResponsiveSize on num {
  /// Design pixels → screen pixels.
  double get r => this * _scale;
}
