import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_localizations.dart';
import '../services/image_storage_service.dart';
import 'app_snackbar.dart';

/// A tap-to-pick product image widget for use in the product form.
///
/// Shows the current image (or a dashed-border placeholder) and opens a
/// bottom sheet when tapped, offering camera, gallery, and remove options.
///
/// [onChanged] is called with the new local path after a successful pick,
/// or `null` when the image is removed.
class ProductImagePicker extends StatefulWidget {
  const ProductImagePicker({
    super.key,
    required this.imagePath,
    required this.onChanged,
  });

  final String? imagePath;
  final ValueChanged<String?> onChanged;

  @override
  State<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<ProductImagePicker> {
  bool _loading = false;
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    Navigator.pop(context); // close bottom sheet
    setState(() => _loading = true);
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 90, // pre-filter; ImageStorageService also compresses
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (xfile == null) return;
      final stored = await ImageStorageService.saveImage(xfile.path);
      if (!mounted) {
        await ImageStorageService.deleteImage(stored);
        return;
      }
      widget.onChanged(stored);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        AppLocalizations.of(context).imagePickFailed,
        severity: AppSnackBarSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove() async {
    Navigator.pop(context); // close bottom sheet
    widget.onChanged(null);
  }

  void _showSheet() {
    final l10n = AppLocalizations.of(context);
    final hasImage =
        widget.imagePath != null &&
        widget.imagePath!.isNotEmpty &&
        File(widget.imagePath!).existsSync();

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.takePicture),
              onTap: () => _pick(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () => _pick(ImageSource.gallery),
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  l10n.removePhoto,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: _remove,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final hasImage =
        widget.imagePath != null &&
        widget.imagePath!.isNotEmpty &&
        File(widget.imagePath!).existsSync();

    Widget inner;
    if (_loading) {
      inner = SizedBox(
        width: 100,
        height: 100,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    } else if (hasImage) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(widget.imagePath!),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(cs, l10n),
        ),
      );
    } else {
      inner = _placeholder(cs, l10n);
    }

    return GestureDetector(onTap: _loading ? null : _showSheet, child: inner);
  }

  Widget _placeholder(ColorScheme cs, AppLocalizations l10n) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
            size: 28,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.addPhoto,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
