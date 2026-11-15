import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../localization/app_localizations.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_status_colors.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool continuousMode;
  final ValueChanged<String>? onContinuousScan;

  const BarcodeScannerScreen({
    super.key,
    this.continuousMode = false,
    this.onContinuousScan,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _scanned = false;
  DateTime? _lastScanTime;
  String? _lastScannedCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;

    if (widget.continuousMode && widget.onContinuousScan != null) {
      final now = DateTime.now();
      if (_lastScanTime != null &&
          _lastScannedCode == value &&
          now.difference(_lastScanTime!).inMilliseconds < 1200) {
        return;
      }
      _lastScanTime = now;
      _lastScannedCode = value;
      HapticFeedback.mediumImpact();
      widget.onContinuousScan!(value);
      setState(() {});
      return;
    }

    if (_scanned) return;
    _scanned = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.barcodeScanner),
        centerTitle: true,
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, state, __) {
              return IconButton(
                tooltip: l10n.flashlight,
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: state.torchState == TorchState.on
                      ? AppStatusColors.fg(context, AppStatus.warning)
                      : Colors.white,
                ),
                onPressed: _controller.toggleTorch,
              );
            },
          ),
          if (widget.continuousMode)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.close,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (_, error, __) => _buildError(context, l10n, error),
          ),
          // Semi-transparent overlay with scan window cutout
          _ScanOverlay(),
          // Scan hint at bottom
          PositionedDirectional(
            bottom: bottomPadding + 24,
            start: 0,
            end: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.continuousMode && _lastScannedCode != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${l10n.barcodeScanner}: $_lastScannedCode',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.continuousMode
                        ? l10n.posContinuousScanning
                        : l10n.scannerHint,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    AppLocalizations l10n,
    MobileScannerException error,
  ) {
    final isPerm = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPerm ? Icons.camera_alt_outlined : Icons.error_outline,
                color: Colors.white54,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isPerm ? l10n.scannerPermDenied : l10n.operationFailed,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isPerm ? l10n.scannerPermMsg : error.errorCode.name,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (isPerm)
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(AppIcons.arrowBack(context)),
                  label: Text(l10n.cancel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(
        borderColor: Theme.of(context).colorScheme.primary,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Color borderColor;
  _OverlayPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    const frameW = 260.0;
    const frameH = 180.0;
    const cornerLen = 24.0;
    const cornerWidth = 4.0;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: frameW,
      height: frameH,
    );

    // Dim overlay
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    canvas.drawPath(path..fillType = PathFillType.evenOdd, dimPaint);

    // Corner markers
    final cornerPaint = Paint()
      ..color = borderColor
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (final c in corners) {
      final isLeft = c.dx == rect.left;
      final isTop = c.dy == rect.top;
      final hDir = isLeft ? 1.0 : -1.0;
      final vDir = isTop ? 1.0 : -1.0;

      canvas.drawLine(c, Offset(c.dx + hDir * cornerLen, c.dy), cornerPaint);
      canvas.drawLine(c, Offset(c.dx, c.dy + vDir * cornerLen), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.borderColor != borderColor;
}
