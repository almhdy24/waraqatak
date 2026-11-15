import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/image_storage_service.dart';
import 'full_screen_image_viewer.dart';

/// A display thumbnail for a product image.
///
/// Decodes at display size using thumbnail image if available, with lazy background
/// backfill, and smooth error fallback to a theme-aware icon placeholder.
class ProductImageThumbnail extends StatefulWidget {
  const ProductImageThumbnail({
    super.key,
    required this.imagePath,
    required this.isService,
    this.size = 44,
    this.width,
    this.height,
    this.heroTag,
    this.borderRadius = 12,
    this.enableFullScreen = true,
    this.excludeSemantics = false,
  });

  final String? imagePath;
  final bool isService;
  final double size;
  final double? width;
  final double? height;

  /// Optional hero tag for animated transitions to full-screen viewer.
  final String? heroTag;
  final double borderRadius;

  /// When false, no gesture detector or hero is mounted, allowing parent taps.
  final bool enableFullScreen;

  /// When true, semantics are excluded (e.g. in list rows where name is already read).
  final bool excludeSemantics;

  @override
  State<ProductImageThumbnail> createState() => _ProductImageThumbnailState();
}

class _ProductImageThumbnailState extends State<ProductImageThumbnail> {
  static final Set<String> _requestedBackfills = <String>{};

  String? _resolvedPath;
  String? _thumbPath;
  String? _mainPath;

  @override
  void initState() {
    super.initState();
    _resolveTarget();
  }

  @override
  void didUpdateWidget(ProductImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _resolveTarget();
    }
  }

  void _resolveTarget() {
    final imagePath = widget.imagePath;
    if (imagePath == null || imagePath.trim().isEmpty) {
      _resolvedPath = null;
      _thumbPath = null;
      _mainPath = null;
      return;
    }

    _thumbPath = ImageStorageService.thumbPathFor(imagePath);
    _mainPath = ImageStorageService.resolve(imagePath);

    if (_thumbPath != null && File(_thumbPath!).existsSync()) {
      _resolvedPath = _thumbPath;
    } else if (_mainPath != null && File(_mainPath!).existsSync()) {
      _resolvedPath = _mainPath;
    } else {
      _resolvedPath = null;
    }

    if (_mainPath != null) {
      final key = imagePath.trim();
      if (_requestedBackfills.add(key)) {
        ImageStorageService.requestThumbnailBackfill(imagePath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final hasCandidate =
        widget.imagePath != null && widget.imagePath!.trim().isNotEmpty;

    final renderWidth = widget.width ?? widget.size;
    final renderHeight = widget.height ?? widget.size;
    final cacheWidth = (renderWidth.isFinite && renderWidth > 0)
        ? (renderWidth * pixelRatio).round()
        : (widget.size * pixelRatio).round();

    Widget content;

    if (hasCandidate && _resolvedPath != null) {
      content = Image.file(
        File(_resolvedPath!),
        width: renderWidth,
        height: renderHeight,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        cacheWidth: cacheWidth,
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
          if (_resolvedPath == _thumbPath &&
              _mainPath != null &&
              File(_mainPath!).existsSync()) {
            return Image.file(
              File(_mainPath!),
              width: renderWidth,
              height: renderHeight,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              cacheWidth: cacheWidth,
              errorBuilder: (_, __, ___) =>
                  _iconFallback(cs, renderWidth, renderHeight),
            );
          }
          return _iconFallback(cs, renderWidth, renderHeight);
        },
      );
    } else {
      content = _iconFallback(cs, renderWidth, renderHeight);
    }

    final rounded = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: renderWidth,
        height: renderHeight,
        child: content,
      ),
    );

    // If full screen is disabled or no candidate image exists, return non-tappable widget
    if (!widget.enableFullScreen || !hasCandidate) {
      if (widget.excludeSemantics) {
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

    if (widget.heroTag != null) {
      tappable = Hero(tag: widget.heroTag!, child: tappable);
    }

    if (widget.excludeSemantics) {
      return ExcludeSemantics(child: tappable);
    }

    return Semantics(
      button: true,
      label: l10n.imageSemanticLabel,
      child: tappable,
    );
  }

  Widget _iconFallback(
    ColorScheme cs,
    double renderWidth,
    double renderHeight,
  ) {
    final iconDimension = math.min(renderWidth, renderHeight) * 0.5;
    return Container(
      width: renderWidth,
      height: renderHeight,
      decoration: BoxDecoration(
        color: widget.isService ? cs.tertiaryContainer : cs.primaryContainer,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Icon(
        widget.isService
            ? Icons.build_circle_outlined
            : Icons.inventory_2_outlined,
        size: iconDimension,
        color: widget.isService
            ? cs.onTertiaryContainer
            : cs.onPrimaryContainer,
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    if (widget.imagePath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imagePath: widget.imagePath!,
          heroTag: widget.heroTag,
        ),
      ),
    );
  }
}
