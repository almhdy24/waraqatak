import 'dart:io';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/image_storage_service.dart';
import 'full_screen_image_viewer.dart';

/// A display thumbnail for a product image.
///
/// Decodes at display size using thumbnail image if available, with lazy background
/// backfill, and smooth error fallback to a theme-aware icon placeholder.
class ProductImageThumbnail extends StatelessWidget {
  const ProductImageThumbnail({
    super.key,
    required this.imagePath,
    required this.isService,
    this.size = 44,
    this.heroTag,
    this.borderRadius = 12,
    this.enableFullScreen = true,
    this.excludeSemantics = false,
  });

  final String? imagePath;
  final bool isService;
  final double size;

  /// Optional hero tag for animated transitions to full-screen viewer.
  final String? heroTag;
  final double borderRadius;

  /// When false, no gesture detector or hero is mounted, allowing parent taps.
  final bool enableFullScreen;

  /// When true, semantics are excluded (e.g. in list rows where name is already read).
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final hasCandidate = imagePath != null && imagePath!.trim().isNotEmpty;

    Widget content;

    if (hasCandidate) {
      // Prefer thumbnail file when available on disk, fallback to main file
      final thumbPath = ImageStorageService.thumbPathFor(imagePath);
      final mainPath = ImageStorageService.resolve(imagePath);

      final String? targetPath;
      if (thumbPath != null && File(thumbPath).existsSync()) {
        targetPath = thumbPath;
      } else if (mainPath != null && File(mainPath).existsSync()) {
        targetPath = mainPath;
      } else {
        targetPath = null;
      }

      if (mainPath != null) {
        // Lazy backfill in background without blocking UI
        ImageStorageService.requestThumbnailBackfill(imagePath);
      }

      if (targetPath != null) {
        content = Image.file(
          File(targetPath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          cacheWidth: (size * pixelRatio).round(),
          frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return AnimatedOpacity(
              opacity: frame == null ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (_, __, ___) {
            if (targetPath == thumbPath &&
                mainPath != null &&
                File(mainPath).existsSync()) {
              return Image.file(
                File(mainPath),
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheWidth: (size * pixelRatio).round(),
                errorBuilder: (_, __, ___) => _iconFallback(cs),
              );
            }
            return _iconFallback(cs);
          },
        );
      } else {
        content = _iconFallback(cs);
      }
    } else {
      content = _iconFallback(cs);
    }

    final rounded = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: size, height: size, child: content),
    );

    // C3: If full screen is disabled or no candidate image exists, return non-tappable widget
    if (!enableFullScreen || !hasCandidate) {
      if (excludeSemantics) {
        return ExcludeSemantics(child: rounded);
      }
      return Semantics(
        label: l10n.imageSemanticLabel,
        image: true,
        child: rounded,
      );
    }

    // Wrap in gesture detector and hero only when enabled
    Widget tappable = GestureDetector(
      onTap: () => _openFullScreen(context),
      child: rounded,
    );

    if (heroTag != null) {
      tappable = Hero(tag: heroTag!, child: tappable);
    }

    if (excludeSemantics) {
      return ExcludeSemantics(child: tappable);
    }

    return Semantics(
      button: true,
      label: l10n.imageSemanticLabel,
      child: tappable,
    );
  }

  // C5: Theme-aware placeholder colors
  Widget _iconFallback(ColorScheme cs) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isService ? cs.tertiaryContainer : cs.primaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        isService ? Icons.build_circle_outlined : Icons.inventory_2_outlined,
        size: size * 0.5,
        color: isService ? cs.onTertiaryContainer : cs.onPrimaryContainer,
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    if (imagePath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FullScreenImageViewer(imagePath: imagePath!, heroTag: heroTag),
      ),
    );
  }
}
