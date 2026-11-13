import 'dart:io';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';

/// Full-screen zoomable viewer for a product image.
///
/// Supports pinch-to-zoom and pan via [InteractiveViewer].
/// Accepts an optional [heroTag] for animated entry from a thumbnail.
class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({
    super.key,
    required this.imagePath,
    this.heroTag,
  });

  final String imagePath;
  final String? heroTag;

  /// Push this screen onto the navigator.
  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    String? heroTag,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            FullScreenImageViewer(imagePath: imagePath, heroTag: heroTag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget image = Image.file(
      File(imagePath),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.imageLoadError,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: image),
      ),
    );
  }
}
