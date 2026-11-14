# Product Images Architecture & Storage Specification

## 1. Storage Architecture Overview
Product images in Waraqatak use a filename-only storage pattern inside the SQLite database (`image_path` column stores basenames like `img_1700000000_123456.jpg`, never absolute filesystem paths). All image files and their companion thumbnails are stored inside the application-managed directory `<app_docs_dir>/product_images/`.
- **Main Image:** Longest dimension is capped at $\le 1024$ pixels (`quality: 85`), maintaining original aspect ratio.
- **Square Thumbnail:** Generated alongside the main image with `_t` suffix (e.g. `img_1700000000_123456_t.jpg`), capped at $\le 256$ pixels.
- **Orphan Sweeping:** `ImageStorageService.sweepOrphans()` runs once at app startup, asynchronously identifying and purging files older than 24 hours that are no longer referenced in the `products` table.
- **Path Resolution:** File existence checks in UI avoid synchronous I/O. The directory path is cached in memory (`_cachedImagesDirPath`), allowing `resolve(filename)` to return synchronously without blocking the UI thread.
- **Backward Compatibility:** SQLite migration v33 sanitizes any legacy absolute file paths by stripping directories and converting them to base filenames.

## 2. Image Compression & Aspect Ratio Behavior (Answer to A1)
`flutter_image_compress` interprets `minWidth` and `minHeight` as minimum bounds while preserving aspect ratio. Under this mechanism:
- Passing raw `minWidth: 1024, minHeight: 1024` for an asymmetric image (such as a 4000x1000 panoramic photo or banner) causes the compressor to preserve the 4:1 aspect ratio by setting height to 1024 and scaling width up to 4096 px—vastly exceeding the 1024 px budget and causing out-of-memory crashes on 4 GB RAM devices.
- **Pure-Dart Solution:** Waraqatak parses the image header first using `readImageDimensions(file)` to extract width and height without decoding full pixel buffers. `computeTargetDimensions(origWidth, origHeight, maxDimension)` scales both dimensions proportionally such that `max(width, height) <= maxDimension`.
- For a 4000x1000 image capped at 1024 px, `computeTargetDimensions` calculates target dimensions of exactly `1024 x 256`, preventing memory spikes.

## 3. Quick Sale & UI Integration
- **Display Setting:** Controlled per-device via `QuickSaleSettings.instance.showProductImages` (backed by `SharedPreferences`, key `'quick_sale_show_product_images'`). It does not require administrative permission.
- **Grid Layout Extent:** Determined by `posTileExtent({required bool showImage, required double textScale})`:
  - When images are OFF: returns `116.0 * textScale.clamp(1.0, 1.4)`, matching legacy Quick Sale layout.
  - When images are ON: returns `(116.0 * textScale.clamp(1.0, 1.4)) + 100.0`, safely hosting a 100dp square thumbnail, 2 lines of product name, bold price, and stock info with zero RenderFlex overflows under textScale up to 1.4.
- **Repaint Isolation:** Each `PosProductTile` is wrapped in a `RepaintBoundary` to prevent image decode/repainting from invalidating the rest of the grid during high-speed scrolling.
- **App Bar Quick Toggle:** AppBar action toggles images ON/OFF with zero interruption to current cart, active search query, or category selection.

## 4. On-Device QA Script (4 GB RAM Android Target)
1. **Quick Sale with 50 products:**
   - Seed 50 products with images.
   - Verify smooth 60 fps scrolling and instant search response.
   - Toggle images OFF and ON via the AppBar action icon.
   - Inspect Android Studio Profiler: verify app RSS stays $< 200$ MB without memory creep.
2. **Camera capture on low-RAM device (Activity Destruction):**
   - Enable Developer Options > "Don't keep activities".
   - Open Product Form, tap camera icon to capture a photo.
   - Snap photo and accept.
   - On returning to Waraqatak, verify the Android activity recovery handler restores the captured file, shows the localized snackbar (`imagePhotoRecovered`), and renders the image preview.
3. **Backup export and restore:**
   - Create products with images and export a `.waraq` backup file.
   - Clear application storage / reinstall app.
   - Restore the `.waraq` backup.
   - Verify products display their restored images, corrupt/missing images are safely skipped, and thumbnails backfill on demand.
4. **Product deletion safety:**
   - Attempt to delete a product associated with existing invoices: verify deletion is blocked with localized error `errProductInUse`.
   - Delete an unreferenced product: verify database row is deleted, and both main image and thumbnail are deleted from disk.
5. **Permission denial handling:**
   - Revoke camera permission in Android system settings.
   - In Product Form, tap camera button.
   - Verify `cameraPermissionDenied` snackbar appears with an "Open app settings" action button that opens system app settings.
