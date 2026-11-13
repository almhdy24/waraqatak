import 'dart:io';

import 'package:flutter/material.dart';

import '../screens/full_screen_image_viewer.dart';

/// A 44 × 44 (by default) thumbnail for a product image.
///
/// Shows a file image when [imagePath] points to an existing file,
/// otherwise falls back to the standard product/service icon swatch
/// (matching the visual style of the existing product cards).
///
/// Tap opens [FullScreenImageViewer] when an image is available.
class ProductImageThumbnail extends StatelessWidget {
  const ProductImageThumbnail({
    super.key,
    required this.imagePath,
    required this.isService,
    this.size = 44,
    this.heroTag,
    this.borderRadius = 12,
  });

  final String? imagePath;
  final bool isService;
  final double size;

  /// Optional hero tag for animated transitions to full-screen viewer.
  final String? heroTag;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImage =
        imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync();

    Widget content;
    if (hasImage) {
      content = Image.file(
        File(imagePath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _iconFallback(cs),
      );
    } else {
      content = _iconFallback(cs);
    }

    final rounded = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: size, height: size, child: content),
    );

    if (!hasImage) return rounded;

    // Wrap in hero + tap for full-screen if image is available.
    Widget tappable = GestureDetector(
      onTap: () => _openFullScreen(context),
      child: rounded,
    );

    if (heroTag != null) {
      tappable = Hero(tag: heroTag!, child: tappable);
    }

    return tappable;
  }

  Widget _iconFallback(ColorScheme cs) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isService
            ? Colors.blue.withValues(alpha: 0.12)
            : cs.primaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        isService ? Icons.build_circle_outlined : Icons.inventory_2_outlined,
        size: size * 0.5,
        color: isService ? Colors.blue.shade700 : cs.onPrimaryContainer,
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FullScreenImageViewer(imagePath: imagePath!, heroTag: heroTag),
      ),
    );
  }
}
