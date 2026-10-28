import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/data/tracker_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/camera_probe.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/adaptive_layout.dart';
import '../../../core/widgets/app_widgets.dart';
import '../cubit/scan_cubit.dart';
import '../model/scan_state.dart';
import '../widget/camera_check_panel.dart';
import '../widget/flash_on_change.dart';
import '../widget/invert_toggle.dart';
import '../widget/log_mode_toggle.dart';
import '../widget/scan_log_dialog.dart';
import '../widget/manual_entry.dart';
import '../widget/not_in_list_card.dart';
import '../widget/result_card.dart';
import '../widget/scan_status_bar.dart';
import '../widget/viewfinder.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => ScanCubit(context.read<TrackerRepository>()),
        child: const _ScanView(),
      );
}

/// Owns the camera controller, which lives and dies with this widget; scan logic is in [ScanCubit].
class _ScanView extends StatefulWidget {
  const _ScanView();

  @override
  State<_ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<_ScanView> {
  /// Null while the camera is being swapped (invert setting changed).
  MobileScannerController? _controller = _makeController(false);

  static MobileScannerController _makeController(bool invert) => MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
        invertImage: invert,
      );

  /// Browser / device camera check; null until it finishes.
  CameraEnv? _env;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final env = await probeCamera();
    if (mounted) setState(() => _env = env);
  }

  /// The camera allows one active controller, so the old one is removed from the tree and
  /// fully disposed before the new one starts.
  Future<void> _restartCamera() async {
    final old = _controller;
    setState(() => _controller = null);
    await WidgetsBinding.instance.endOfFrame;
    await old?.dispose();
    if (mounted) setState(() => _controller = _makeController(context.read<ScanCubit>().state.invert));
  }

  /// "Check again": re-run the camera check and restart the camera, which retries the permission.
  Future<void> _recheck() async {
    await _check();
    if (mounted) await _restartCamera();
  }

  /// "Allow camera": shows the browser's permission prompt first (Android asks when the camera restarts).
  Future<void> _allow() async {
    await requestCameraAccess();
    if (mounted) await _recheck();
  }

  /// True while the Log by scan popup is open; camera reads are ignored meanwhile.
  bool _logging = false;

  /// A scanned or typed code: checked as usual, or with Log by scan on, the counter popup for the day
  /// (yesterday by default, as in the morning log). Confirming records the scan and saves the log.
  Future<void> _onCode(String code, {bool fromCamera = false}) async {
    final cubit = context.read<ScanCubit>();
    if (!cubit.state.logMode) return cubit.submit(code, fromCamera: fromCamera);
    if (_logging || code.trim().isEmpty) return;
    _logging = true;
    try {
      final repository = context.read<TrackerRepository>();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      unawaited(HapticFeedback.mediumImpact());
      final choice = await showScanLogDialog(context, repository.scanLogDraft(code, yesterday), draftFor: (d) => repository.scanLogDraft(code, d));
      if (choice case ScanLogConfirm(:final draft, :final counter)) {
        await cubit.submit(code);
        await repository.saveScanLog(draft, counter);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showSnack(context, '${fmtDate(draft.date)} logged: ${fmt(counter)} printed');
        }
      }
      // "Scan again" and Cancel just close the popup; the camera keeps running
    } finally {
      _logging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ScanCubit>();

    return MultiBlocListener(
      listeners: [
        BlocListener<ScanCubit, ScanState>(listenWhen: (a, b) => a.invert != b.invert, listener: (_, _) => _restartCamera()),
        // the camera keeps running; a buzz confirms each new code, and a toast each match
        BlocListener<ScanCubit, ScanState>(
          listenWhen: (a, b) => a.sessionCount != b.sessionCount,
          listener: (context, s) {
            final r = s.result;
            unawaited(r?.inList == false ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact());
            if (r == null || !r.inList) return;
            // replace the previous toast instead of queueing behind it during fast scanning
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            showSnack(context, 'Scan successful · #${fmt(r.scan.pos!)} of ${fmt(r.total)}');
          },
        ),
      ],
      child: Scaffold(
        appBar: const TrackerAppBar('Scan'),
        body: BlocBuilder<ScanCubit, ScanState>(builder: (context, state) {
          final notice = state.hasCodes
              ? null
              : Panel(
                  color: C.high,
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: C.warning),
                    SizedBox(width: 12.r),
                    Expanded(
                      child: Text('No QR list imported yet. Scans are saved, but positions show only after you import the list in Data.', style: sans(14)),
                    ),
                  ]),
                );
          final status = ScanStatusBar(controller: _controller, scanCount: state.sessionCount);
          final check = CameraCheckPanel(env: _env, controller: _controller, onAllow: _allow, onRecheck: _recheck);
          // a new key per scan replays the card's highlight, so each update is visible
          final result = switch (state.result) {
            final r? => FlashOnChange(
                key: ValueKey(r.scan.ts),
                child: r.inList ? ResultCard(result: r) : NotInListCard(code: r.scan.code, scannedAt: r.scan.ts),
              ),
            null => const _WaitingCard(),
          };
          // browsers can't invert the camera image (the scanner ignores the setting on the web)
          final controls = [InvertToggle(value: state.invert, onChanged: kIsWeb ? null : cubit.setInvert), ManualEntry(onSubmit: _onCode)];
          final logMode = LogModeToggle(value: state.logMode, onChanged: cubit.setLogMode);

          return LayoutBuilder(builder: (context, box) {
            final wide = isTablet && box.maxWidth >= twoColumnMinWidth;
            // a global key moves the running camera view when the layout switches instead of starting it twice
            final viewfinder = Viewfinder(
              key: _controller == null ? null : GlobalObjectKey(_controller!),
              controller: _controller,
              height: wide ? 360.r : 260.r,
              onCode: (code) => _onCode(code, fromCamera: true),
            );

            // wide tablet: camera and controls on the left, the latest result beside it
            if (wide) return TwoPane(left: [?notice, status, logMode, check, viewfinder, ...controls], right: [result]);

            // phone / portrait tablet: camera on top, the latest result right under it
            final gutter = isTablet ? ((box.maxWidth - 600.r) / 2).clamp(24.r, double.infinity) : 16.r;
            return ListView(
              padding: EdgeInsets.symmetric(horizontal: gutter, vertical: isTablet ? 24.r : 16.r),
              children: [?notice, status, logMode, check, viewfinder, result, ...controls],
            );
          });
        }),
      ),
    );
  }
}

/// Tablet placeholder beside the camera before anything is scanned.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.all(32.r),
        child: Column(children: [
          IconTile(Icons.qr_code_scanner, size: 72.r),
          SizedBox(height: 16.r),
          Text('Waiting for a scan', style: sans(22, weight: FontWeight.w700)),
          SizedBox(height: 8.r),
          Text(
            'Point the camera at the code the machine is printing, or type it. The camera keeps scanning: each new code shows here.',
            textAlign: TextAlign.center,
            style: sans(15, color: C.onVariant),
          ),
        ]),
      );
}
