import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../services/pos_cart.dart';
import '../utils/format_utils.dart';
import 'product_image_thumbnail.dart';

/// Pure helper function computing the grid tile extent for POS products.
///
/// When [showImage] is false: returns 116.0 * textScale.clamp(1.0, 1.4).
/// When [showImage] is true: returns (116.0 * textScale.clamp(1.0, 1.4)) + 100.0,
/// comfortably fitting the 100dp square thumbnail, 2 lines of product name,
/// price, and stock info without RenderFlex overflows.
double posTileExtent({required bool showImage, required double textScale}) {
  final clampedScale = textScale.clamp(1.0, 1.4);
  if (!showImage) {
    return 116.0 * clampedScale;
  }
  return (116.0 * clampedScale) + 100.0;
}

/// A product card displayed within the Quick Sale (POS) grid.
class PosProductTile extends StatelessWidget {
  final Product product;
  final int cartQuantity;
  final bool showImage;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSoldOut;
  final bool isBlocked;
  final String? price;
  final double? availableQuantity;

  const PosProductTile({
    super.key,
    required this.product,
    required this.cartQuantity,
    required this.showImage,
    required this.onTap,
    this.onLongPress,
    this.isSoldOut = false,
    this.isBlocked = false,
    this.price,
    this.availableQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final tracks = PosCart.tracksStock(product);
    final avail =
        availableQuantity ??
        (tracks ? product.stockQuantity - cartQuantity : double.infinity);
    final soldOut = isSoldOut || (tracks && avail <= 0);
    final blocked = isBlocked;
    final displayPrice =
        price ??
        (product.salePrice > 0 ? product.salePrice.toStringAsFixed(2) : '');

    final stockText = !tracks
        ? l10n.posService
        : soldOut
        ? l10n.outOfStock
        : l10n.posInStock(FormatUtils.formatQuantity(avail));

    final offContent = Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: soldOut ? cs.onSurfaceVariant : null,
                  ),
                ),
              ),
              if (cartQuantity > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    FormatUtils.formatQuantity(cartQuantity),
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayPrice,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stockText,
                style: TextStyle(
                  fontSize: 11.5,
                  color: soldOut ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final onContent = Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: AlignmentDirectional.topEnd,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: Opacity(
                        opacity: (soldOut || blocked) ? 0.4 : 1.0,
                        child: ProductImageThumbnail(
                          imagePath: product.imagePath,
                          isService: product.isService,
                          size: 100,
                          enableFullScreen: false,
                          heroTag: null,
                          excludeSemantics: true,
                        ),
                      ),
                    ),
                  ),
                  if (soldOut || blocked)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.errorContainer.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.outOfStock,
                            style: TextStyle(
                              color: cs.onErrorContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (cartQuantity > 0)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Semantics(
                        label: l10n.posItemsCount(
                          FormatUtils.formatQuantity(cartQuantity),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            FormatUtils.formatQuantity(cartQuantity),
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: soldOut ? cs.onSurfaceVariant : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayPrice,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stockText,
                style: TextStyle(
                  fontSize: 11.5,
                  color: soldOut ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return RepaintBoundary(
      child: Material(
        color: cartQuantity > 0
            ? cs.primary.withValues(alpha: 0.08)
            : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: cartQuantity > 0 ? cs.primary : cs.outlineVariant,
            width: cartQuantity > 0 ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: blocked ? null : onTap,
          onLongPress: blocked ? null : onLongPress,
          child: showImage ? onContent : offContent,
        ),
      ),
    );
  }
}
