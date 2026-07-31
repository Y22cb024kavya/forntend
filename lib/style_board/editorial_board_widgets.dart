import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../util/wardrobe_image_resolver.dart';
import 'board_models.dart';
import 'style_board_network_image.dart';

/// Central per-role visual zoom applied to each garment cutout INSIDE its
/// existing placement box. Transparent-PNG cutouts leave the visible garment
/// small inside the image rectangle (footwear worst), so a mild role-aware zoom
/// lifts visible density without touching layout rectangles, card size, action
/// bars or board behaviour. Aspect ratio is preserved (uniform scale).
double editorialVisualScaleForRole(BoardItemRole role) {
  switch (role) {
    case BoardItemRole.top:
      return 1.24;
    case BoardItemRole.bottom:
      return 1.18;
    case BoardItemRole.dress:
      return 1.20;
    case BoardItemRole.outerwear:
      return 1.18;
    case BoardItemRole.footwear:
      return 1.48; // shoes carry the most transparent padding
    case BoardItemRole.accessory:
      return 1.20; // bags / jewellery collapse into accessory
    case BoardItemRole.unknown:
      return 1.12;
  }
}

/// Zoom anchor per role. Bottoms anchor to the top so the waistband stays put
/// and the zoom grows downward; every other role zooms about its centre.
Alignment editorialAlignmentForRole(BoardItemRole role) {
  switch (role) {
    case BoardItemRole.bottom:
      return Alignment.topCenter;
    case BoardItemRole.top:
    case BoardItemRole.dress:
    case BoardItemRole.outerwear:
    case BoardItemRole.footwear:
    case BoardItemRole.accessory:
    case BoardItemRole.unknown:
      return Alignment.center;
  }
}

class EditorialBoardItem extends StatelessWidget {
  final StyleBoardItem item;
  final double rotation;

  const EditorialBoardItem({super.key, required this.item, this.rotation = 0});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resolved = item.resolveImage(surface: 'style_board_render');
    // Ordered fallback candidates (cutout → masked → catalog → raw). The widget
    // advances to the next source if one fails at runtime, so a single dead
    // cutout URL no longer breaks the board.
    final candidates = resolved.candidates.isNotEmpty
        ? resolved.candidates
        : <ResolvedWardrobeImage>[resolved];

    // Framing, shadow and role scale are decided PER current candidate, so a
    // transparent cutout falling back to an opaque catalog reframes correctly.
    Widget frame(BuildContext context, ResolvedWardrobeImage current,
        Widget garment) {
      final shouldFrame = current.requiresFrame;
      final content = Transform.rotate(
        angle: rotation,
        child: shouldFrame
            ? Container(
                key: item.hasStableIdentity
                    ? ValueKey<String>('fallback-${item.itemId}')
                    : null,
                padding: EdgeInsets.all(
                  shouldFrame && item.role == BoardItemRole.accessory ? 2 : 5,
                ),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: garment,
              )
            : Stack(
                key: item.hasStableIdentity
                    ? ValueKey<String>('cutout-${item.itemId}')
                    : null,
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Transform.translate(
                      offset: const Offset(0, 4),
                      child: ImageFiltered(
                        imageFilter:
                            ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                        child: Image.network(
                          current.url ?? '',
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          color: Colors.black.withValues(alpha: 0.22),
                          colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  garment,
                ],
              ),
      );
      // Per-role visual zoom (paint-only): applied once here, never in the
      // resolver or fallback widget. Framed opaque fallbacks are not zoomed.
      return Transform.scale(
        key: item.hasStableIdentity
            ? ValueKey<String>('vscale-${item.itemId}')
            : null,
        scale: shouldFrame ? 1 : editorialVisualScaleForRole(item.role),
        alignment: editorialAlignmentForRole(item.role),
        filterQuality: FilterQuality.high,
        child: content,
      );
    }

    return StyleBoardNetworkImage(
      candidates: candidates,
      surface: 'style_board_render',
      role: item.role.name,
      itemId: item.itemId,
      alignment: Alignment.center,
      fitBuilder: (c) =>
          c.requiresFrame && item.role == BoardItemRole.accessory
              ? BoxFit.cover
              : BoxFit.contain,
      placeholder: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 22,
          color: Colors.black26,
        ),
      ),
      builder: frame,
    );
  }
}
