import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/digital_seal.dart';
import '../services/seal_geometry_engine.dart';

/// Interactive touch overlay layered over the document preview.
/// Supports smooth 60fps drag, corner pinch/drag resizing, and RTL-aware placement.
class SealEditorOverlay extends StatefulWidget {
  final double containerWidth;
  final double containerHeight;
  final bool isRtl;
  final DigitalSealConfig? stamp;
  final DigitalSealConfig? signature;
  final Uint8List? stampBytes;
  final Uint8List? signatureBytes;
  final ValueChanged<DigitalSealConfig>? onStampChanged;
  final ValueChanged<DigitalSealConfig>? onSignatureChanged;
  final VoidCallback? onInteractionEnd;

  const SealEditorOverlay({
    super.key,
    required this.containerWidth,
    required this.containerHeight,
    required this.isRtl,
    this.stamp,
    this.signature,
    this.stampBytes,
    this.signatureBytes,
    this.onStampChanged,
    this.onSignatureChanged,
    this.onInteractionEnd,
  });

  @override
  State<SealEditorOverlay> createState() => _SealEditorOverlayState();
}

class _SealEditorOverlayState extends State<SealEditorOverlay> {
  SealType? _selectedType;

  // Temporary local configs for smooth 60fps pointer updates
  DigitalSealConfig? _localStamp;
  DigitalSealConfig? _localSignature;

  @override
  void initState() {
    super.initState();
    _localStamp = widget.stamp;
    _localSignature = widget.signature;
  }

  @override
  void didUpdateWidget(covariant SealEditorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stamp != oldWidget.stamp) {
      _localStamp = widget.stamp;
    }
    if (widget.signature != oldWidget.signature) {
      _localSignature = widget.signature;
    }
  }

  void _onPanUpdate(SealType type, DragUpdateDetails details) {
    final isStamp = type == SealType.stamp;
    final config = isStamp ? _localStamp : _localSignature;
    if (config == null) return;

    // In RTL, dragging right increases start from right edge (delta is -dx)
    final deltaStart = widget.isRtl ? -details.delta.dx : details.delta.dx;
    final deltaTop = details.delta.dy;

    final updated = SealGeometryEngine.updatePositionFromDelta(
      config: config,
      deltaStart: deltaStart,
      deltaTop: deltaTop,
      containerWidth: widget.containerWidth,
      containerHeight: widget.containerHeight,
    );

    setState(() {
      if (isStamp) {
        _localStamp = updated;
      } else {
        _localSignature = updated;
      }
    });

    if (isStamp) {
      widget.onStampChanged?.call(updated);
    } else {
      widget.onSignatureChanged?.call(updated);
    }
  }

  void _onResizeUpdate(SealType type, DragUpdateDetails details) {
    final isStamp = type == SealType.stamp;
    final config = isStamp ? _localStamp : _localSignature;
    if (config == null) return;

    final delta =
        (widget.isRtl ? -details.delta.dx : details.delta.dx) + details.delta.dy;
    final updated = SealGeometryEngine.updateSizeFromDelta(
      config: config,
      deltaWidth: delta,
      containerWidth: widget.containerWidth,
    );

    setState(() {
      if (isStamp) {
        _localStamp = updated;
      } else {
        _localSignature = updated;
      }
    });

    if (isStamp) {
      widget.onStampChanged?.call(updated);
    } else {
      widget.onSignatureChanged?.call(updated);
    }
  }

  void _onGestureEnd() {
    widget.onInteractionEnd?.call();
  }

  Widget _buildSealWidget({
    required SealType type,
    required DigitalSealConfig config,
    required Uint8List? bytes,
  }) {
    if (!config.isEnabled || bytes == null || bytes.isEmpty) {
      return const SizedBox.shrink();
    }

    final box = SealGeometryEngine.resolve(
      config: config,
      containerWidth: widget.containerWidth,
      containerHeight: widget.containerHeight,
      isRtl: widget.isRtl,
    );

    final isSelected = _selectedType == type;
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Positioned(
      left: box.x,
      top: box.y,
      width: box.width,
      height: box.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedType = isSelected ? null : type;
          });
        },
        onPanUpdate: (d) => _onPanUpdate(type, d),
        onPanEnd: (_) => _onGestureEnd(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The image content with opacity
            Positioned.fill(
              child: Opacity(
                opacity: config.opacity.clamp(0.1, 1.0),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            // Selection frame
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: accentColor, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            // Resize handle on bottom-end corner
            if (isSelected)
              Positioned(
                right: widget.isRtl ? null : -8,
                left: widget.isRtl ? -8 : null,
                bottom: -8,
                child: GestureDetector(
                  onPanUpdate: (d) => _onResizeUpdate(type, d),
                  onPanEnd: (_) => _onGestureEnd(),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.aspect_ratio,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stamp = _localStamp;
    final sig = _localSignature;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_selectedType != null) {
          setState(() => _selectedType = null);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (stamp != null)
            _buildSealWidget(
              type: SealType.stamp,
              config: stamp,
              bytes: widget.stampBytes,
            ),
          if (sig != null)
            _buildSealWidget(
              type: SealType.signature,
              config: sig,
              bytes: widget.signatureBytes,
            ),
        ],
      ),
    );
  }
}
