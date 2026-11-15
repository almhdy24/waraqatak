import 'dart:math' as math;

import '../models/digital_seal.dart';

/// Represents a resolved geometric bounding box inside a container.
class SealBox {
  /// Left offset in logical container coordinates.
  final double x;

  /// Top offset in logical container coordinates.
  final double y;

  /// Absolute width.
  final double width;

  /// Absolute height (preserving aspect ratio).
  final double height;

  /// Offset from the reading-direction start edge.
  final double start;

  /// Offset from the top edge.
  final double top;

  const SealBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.start,
    required this.top,
  });

  @override
  String toString() =>
      'SealBox(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, '
      'w: ${width.toStringAsFixed(1)}, h: ${height.toStringAsFixed(1)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SealBox &&
          (x - other.x).abs() < 0.01 &&
          (y - other.y).abs() < 0.01 &&
          (width - other.width).abs() < 0.01 &&
          (height - other.height).abs() < 0.01;

  @override
  int get hashCode => Object.hash(
    (x * 100).round(),
    (y * 100).round(),
    (width * 100).round(),
    (height * 100).round(),
  );
}

/// The single source-of-truth geometry engine for Digital Seal positioning.
/// Used identically by Flutter widgets (visual editor preview) and the PDF generator.
class SealGeometryEngine {
  SealGeometryEngine._();

  static const double minWidthRatio = 0.08;
  static const double maxWidthRatio = 0.55;
  static const double minAbsoluteWidth = 24.0;

  static double _clamp(double v, double lo, double hi) {
    final lower = math.min(lo, hi);
    final val = v.isNaN ? lower : v;
    return val.clamp(lower, hi);
  }

  /// Resolves absolute bounding box for [config] given printable [containerWidth]
  /// and [containerHeight] and reading direction [isRtl].
  static SealBox resolve({
    required DigitalSealConfig config,
    required double containerWidth,
    required double containerHeight,
    required bool isRtl,
  }) {
    if (containerWidth <= 0 || containerHeight <= 0) {
      return const SealBox(x: 0, y: 0, width: 0, height: 0, start: 0, top: 0);
    }

    // 1. Calculate width clamped between safe ratios and container bounds
    final clampedWidthRatio = _clamp(
      config.widthRatio,
      minWidthRatio,
      maxWidthRatio,
    );
    final rawWidth = clampedWidthRatio * containerWidth;
    final width = _clamp(rawWidth, minAbsoluteWidth, containerWidth);

    // 2. Preserve intrinsic aspect ratio (width / height)
    final aspect = config.aspectRatio > 0 ? config.aspectRatio : 1.0;
    final rawHeight = width / aspect;
    final height = _clamp(
      rawHeight,
      minAbsoluteWidth / aspect,
      containerHeight * 0.45,
    );

    // 3. Resolve vertical position (top)
    final maxTop = _clamp(containerHeight - height, 0.0, containerHeight);
    final top = _clamp(config.topRatio * containerHeight, 0.0, maxTop);

    // 4. Resolve horizontal position (start)
    final maxStart = _clamp(containerWidth - width, 0.0, containerWidth);
    final start = _clamp(config.startRatio * containerWidth, 0.0, maxStart);

    // 5. Map start to X coordinate based on RTL vs LTR
    final x = isRtl ? (containerWidth - start - width) : start;

    return SealBox(
      x: x,
      y: top,
      width: width,
      height: height,
      start: start,
      top: top,
    );
  }

  /// Converts screen/touch drag deltas into updated normalized ratios.
  /// Ensures elements stay strictly clamped within printable boundaries.
  static DigitalSealConfig updatePositionFromDelta({
    required DigitalSealConfig config,
    required double deltaStart,
    required double deltaTop,
    required double containerWidth,
    required double containerHeight,
  }) {
    if (containerWidth <= 0 || containerHeight <= 0) return config;

    final box = resolve(
      config: config,
      containerWidth: containerWidth,
      containerHeight: containerHeight,
      isRtl: false,
    );

    final maxStart = _clamp(containerWidth - box.width, 0.0, containerWidth);
    final newStart = _clamp(box.start + deltaStart, 0.0, maxStart);
    final newStartRatio = maxStart > 0 ? newStart / containerWidth : 0.0;

    final maxTop = _clamp(containerHeight - box.height, 0.0, containerHeight);
    final newTop = _clamp(box.top + deltaTop, 0.0, maxTop);
    final newTopRatio = maxTop > 0 ? newTop / containerHeight : 0.0;

    return config.copyWith(
      startRatio: _clamp(newStartRatio, 0.0, 1.0),
      topRatio: _clamp(newTopRatio, 0.0, 1.0),
    );
  }

  /// Converts screen/touch resize drag into updated normalized width ratio.
  static DigitalSealConfig updateSizeFromDelta({
    required DigitalSealConfig config,
    required double deltaWidth,
    required double containerWidth,
  }) {
    if (containerWidth <= 0) return config;

    final currentWidth = config.widthRatio * containerWidth;
    final newWidth = currentWidth + deltaWidth;
    final newWidthRatio = _clamp(
      newWidth / containerWidth,
      minWidthRatio,
      maxWidthRatio,
    );

    return config.copyWith(widthRatio: newWidthRatio);
  }
}
