import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_localizations.dart';
import '../services/image_storage_service.dart';
import 'app_design_tokens.dart';
import 'app_snackbar.dart';

/// A tap-to-pick product image widget for use in the product form.
///
/// Shows the current image (or a theme-consistent placeholder) and opens a
/// bottom sheet when tapped, offering camera, gallery, and remove options.
///
/// [onChanged] is called with the new stored filename after a successful pick,
/// or `null` when the image is removed.
class ProductImagePicker extends StatefulWidget {
  const ProductImagePicker({
    super.key,
    required this.imagePath,
    required this.onChanged,
    this.readOnly = false,
    this.picker,
  });

  final String? imagePath;
  final ValueChanged<String?> onChanged;
  final bool readOnly;

  @visibleForTesting
  final ImagePicker? picker;

  @override
  State<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<ProductImagePicker> {
  bool _loading = false;
  late final ImagePicker _picker;
  String? _inFlightSavedFile;

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLostData());
  }

  @override
  void dispose() {
    // B8: If disposed while a save operation was in-flight, clean up the orphaned file
    if (_inFlightSavedFile != null) {
      ImageStorageService.deleteImage(_inFlightSavedFile);
    }
    super.dispose();
  }

  // ── Android Lost Data Recovery (B1) ───────────────────────────────────────

  Future<void> _checkLostData() async {
    if (!mounted || widget.readOnly) return;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return;

      if (response.file != null) {
        setState(() => _loading = true);
        try {
          final stored = await ImageStorageService.saveImage(
            response.file!.path,
          );
          _inFlightSavedFile = stored;
          if (!mounted) {
            await ImageStorageService.deleteImage(stored);
            return;
          }
          _inFlightSavedFile = null;
          widget.onChanged(stored);
          AppSnackBar.show(
            context,
            AppLocalizations.of(context).imagePhotoRecovered,
            severity: AppSnackBarSeverity.success,
          );
        } on ImageStorageException catch (e) {
          _handleStorageError(e);
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      } else if (response.exception != null) {
        _handlePlatformException(response.exception!);
      }
    } on PlatformException catch (e) {
      _handlePlatformException(e);
    } catch (_) {
      // Best-effort retrieval
    }
  }

  // ── Pick / Remove Actions ──────────────────────────────────────────────────

  Future<void> _pick(BuildContext sheetContext, ImageSource source) async {
    if (_loading) return;
    Navigator.of(
      sheetContext,
    ).pop(); // B4: pop bottom sheet with its own context

    setState(() => _loading = true);
    try {
      // B3: Single compression pass in ImageStorageService; drop imageQuality/maxWidth
      final xfile = await _picker.pickImage(source: source);
      if (xfile == null) return;

      final stored = await ImageStorageService.saveImage(xfile.path);
      _inFlightSavedFile = stored;

      if (!mounted) {
        await ImageStorageService.deleteImage(stored);
        return;
      }
      _inFlightSavedFile = null;
      widget.onChanged(stored);
    } on PlatformException catch (e) {
      _handlePlatformException(e);
    } on ImageStorageException catch (e) {
      _handleStorageError(e);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          AppLocalizations.of(context).imagePickFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _remove(BuildContext sheetContext) {
    Navigator.of(
      sheetContext,
    ).pop(); // B4: pop bottom sheet with its own context
    widget.onChanged(null);
  }

  void _handlePlatformException(PlatformException e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final code = e.code.toLowerCase();

    if (code.contains('camera_access_denied') || code.contains('camera')) {
      AppSnackBar.show(
        context,
        l10n.cameraPermissionDenied,
        severity: AppSnackBarSeverity.warning,
      );
    } else if (code.contains('photo_access_denied') || code.contains('photo')) {
      AppSnackBar.show(
        context,
        l10n.photoPermissionDenied,
        severity: AppSnackBarSeverity.warning,
      );
    } else {
      AppSnackBar.show(
        context,
        l10n.imagePickFailed,
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  void _handleStorageError(ImageStorageException e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    String message;
    switch (e.error) {
      case ImageStorageError.invalidImage:
        message = l10n.imageInvalid;
        break;
      case ImageStorageError.tooLarge:
        message = l10n.imageTooLarge;
        break;
      case ImageStorageError.diskFull:
        message = l10n.imageDiskFull;
        break;
      case ImageStorageError.permissionDenied:
        message = l10n.photoPermissionDenied;
        break;
      case ImageStorageError.unexpected:
        message = l10n.imagePickFailed;
        break;
    }
    AppSnackBar.show(context, message, severity: AppSnackBarSeverity.error);
  }

  // ── Bottom Sheet UI ────────────────────────────────────────────────────────

  void _showSheet() {
    if (widget.readOnly || _loading) return;
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final hasImage =
        widget.imagePath != null && widget.imagePath!.trim().isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.takePicture),
              onTap: () => _pick(sheetCtx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () => _pick(sheetCtx, ImageSource.gallery),
            ),
            if (hasImage)
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text(
                  l10n.removePhoto,
                  style: TextStyle(color: cs.error),
                ),
                onTap: () => _remove(sheetCtx),
              ),
          ],
        ),
      ),
    );
  }

  // ── Build UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final hasImage =
        widget.imagePath != null && widget.imagePath!.trim().isNotEmpty;
    final resolvedPath = hasImage
        ? ImageStorageService.resolve(widget.imagePath)
        : null;

    Widget imageContent;
    if (_loading) {
      imageContent = SizedBox(
        width: 100,
        height: 100,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    } else if (resolvedPath != null) {
      imageContent = ClipRRect(
        borderRadius: BorderRadius.circular(AppDesignTokens.radius12),
        child: Image.file(
          File(resolvedPath),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          cacheWidth: (100 * pixelRatio).round(),
          errorBuilder: (_, __, ___) => _placeholder(cs, l10n, hasImage: false),
        ),
      );
    } else {
      imageContent = _placeholder(cs, l10n, hasImage: false);
    }

    final semanticLabel = hasImage
        ? l10n.imageChangeSemanticLabel
        : l10n.addPhoto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: !widget.readOnly,
          label: semanticLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.readOnly || _loading ? null : _showSheet,
              borderRadius: BorderRadius.circular(AppDesignTokens.radius12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppDesignTokens.minTouchTarget,
                  minHeight: AppDesignTokens.minTouchTarget,
                ),
                child: imageContent,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDesignTokens.space4),
        Text(
          l10n.imageCroppedHint,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _placeholder(
    ColorScheme cs,
    AppLocalizations l10n, {
    required bool hasImage,
  }) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesignTokens.radius12),
        border: Border.all(
          color: cs.outlineVariant,
          width: 1.5,
          style: BorderStyle.solid,
        ),
        color: cs.surfaceContainerLow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: AppDesignTokens.icon28,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: AppDesignTokens.space6),
          Text(
            widget.readOnly ? '' : l10n.addPhoto,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
