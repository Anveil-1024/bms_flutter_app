import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_localizations.dart';

/// 合法 BMS 二维码为 trim 后以 GRT 开头的广播名（长度须大于 3）。
String? parseBmsQrPayload(String raw) {
  final text = raw.trim();
  if (text.toUpperCase().startsWith('GRT') && text.length > 3) {
    return text;
  }
  return null;
}

class QrScanScreen extends StatefulWidget {
  final AppLocalizations loc;

  const QrScanScreen({super.key, required this.loc});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _handled = false;
  String? _invalidHint;

  AppLocalizations get loc => widget.loc;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    final name = parseBmsQrPayload(raw);
    if (name == null) {
      if (_invalidHint != loc.btQrInvalid) {
        setState(() => _invalidHint = loc.btQrInvalid);
      }
      return;
    }

    _handled = true;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF4DA8DA);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.errorCode.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              );
            },
          ),
          const IgnorePointer(child: _ScannerOverlay(color: primaryBlue)),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const Spacer(),
                if (_invalidHint != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _invalidHint!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: Text(
                    loc.btQrHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final Color color;

  const _ScannerOverlay({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScannerOverlayPainter(color: color));
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color color;

  _ScannerOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final holeSize = size.width * 0.7;
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: holeSize,
        height: holeSize,
      ),
      const Radius.circular(16),
    );
    final overlay = Path()..addRect(Offset.zero & size);
    final cut = Path()..addRRect(hole);
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlay, cut),
      Paint()..color = Colors.black54,
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
