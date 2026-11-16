import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/product.dart';
import '../services/pos_cart.dart';
import '../utils/format_utils.dart';
import 'app_design_tokens.dart';
import 'product_image_thumbnail.dart';

/// Pure helper function computing the grid tile extent for POS products.
///
/// When [showImage] is false: returns 116.0 * textScale.clamp(1.0, 1.4).
/// When [showImage] is true: returns (116.0 * textScale.clamp(1.0, 1.4)) + 64.0,
/// comfortably fitting the 84dp thumbnail, 2 lines of product name,
/// price, and stock info without RenderFlex overflows.
double posTileExtent({required bool showImage, required double textScale}) {
  final clampedScale = textScale.clamp(1.0, 1.4);
  if (!showImage) {
    return 116.0 * clampedScale;
  }
  return (116.0 * clampedScale) + 64.0;
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

    final isLowStock = tracks &&
        !soldOut &&
        product.minStock > 0 &&
        product.stockQuantity > 0 &&
        product.stockQuantity <= product.minStock;

    final stockColor = soldOut
        ? cs.error
        : isLowStock
        ? AppDesignTokens.semanticWarning(context)
        : cs.onSurfaceVariant;

    Widget buildNarrowNoImage() {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
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
                  if (cartQuantity > 0) ...[
                    const SizedBox(width: 4),
                    Semantics(
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
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayPrice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stockText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: stockColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildWideRow({required bool withImage}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (withImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Opacity(
                    opacity: (soldOut || blocked) ? 0.4 : 1.0,
                    child: ProductImageThumbnail(
                      imagePath: product.imagePath,
                      isService: product.isService,
                      size: 42,
                      width: 42,
                      height: 42,
                      enableFullScreen: false,
                      heroTag: null,
                      excludeSemantics: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: soldOut ? cs.onSurfaceVariant : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              displayPrice,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stockText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: stockColor,
              ),
            ),
            if (cartQuantity > 0) ...[
              const SizedBox(width: 8),
              Semantics(
                label: l10n.posItemsCount(
                  FormatUtils.formatQuantity(cartQuantity),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
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
            ],
          ],
        ),
      );
    }

    final onContent = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: AlignmentDirectional.topEnd,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 84,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Opacity(
                        opacity: (soldOut || blocked) ? 0.4 : 1.0,
                        child: ProductImageThumbnail(
                          imagePath: product.imagePath,
                          isService: product.isService,
                          size: 84,
                          width: constraints.maxWidth,
                          height: 84,
                          enableFullScreen: false,
                          heroTag: null,
                          excludeSemantics: true,
                        ),
                      );
                    },
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
          const SizedBox(height: 3),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: soldOut ? cs.onSurfaceVariant : null,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            displayPrice,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            stockText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: stockColor,
            ),
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppDesignTokens.minTouchTarget,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 260;
                if (isNarrow) {
                  return showImage ? onContent : buildNarrowNoImage();
                }
                return buildWideRow(withImage: showImage);
              },
            ),
          ),
        ),
      ),
    );
  }
}
