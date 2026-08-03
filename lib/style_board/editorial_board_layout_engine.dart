import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'board_models.dart';

/// Editorial flat-lay layout engine.
///
/// Goal: outfit cutouts must occupy ~75-85% of the 9:16 board canvas while
/// still reading as a premium editorial flat-lay (overlap, slight rotation,
/// role-aware placement) — never a centred cluster floating in white space.
///
/// Cutout image dimensions are unknown at layout time (they only arrive after
/// the network image loads), so each role is sized from a typical garment
/// aspect ratio [_arForRole]. Matching the box aspect ratio to the garment's
/// natural shape keeps `BoxFit.contain` from leaving large empty gutters inside
/// each box — the main reason the old boards looked half-empty.
class EditorialBoardLayoutEngine {
  /// Typical garment aspect ratio as height / width. Used to derive a box
  /// height from its width so the contained cutout fills the box. Conservative
  /// (slightly tall) values keep garments from being clipped.
  static double _arForRole(BoardItemRole role) {
    switch (role) {
      case BoardItemRole.top:
        return 1.18; // shirts/tops: a touch taller than square
      case BoardItemRole.bottom:
        return 1.55; // jeans/trousers: tall and narrow
      case BoardItemRole.dress:
        return 1.70; // dresses/gowns: tallest
      case BoardItemRole.outerwear:
        return 1.35; // jackets/coats
      case BoardItemRole.footwear:
        return 0.62; // shoes: wide and short
      case BoardItemRole.accessory:
        return 1.05; // bags/watches: near-square
      case BoardItemRole.unknown:
        return 1.20;
    }
  }

  static EditorialLayoutResult resolve(
    StyleBoardData board, {
    required double width,
    required double height,
  }) {
    // Guard: a degenerate canvas (zero / NaN / Infinity) can crash Positioned.
    if (!_finitePositive(width) || !_finitePositive(height)) {
      return const EditorialLayoutResult(
        mode: EditorialLayoutMode.empty,
        placements: <BoardItemPlacement>[],
      );
    }

    if (board.items.isEmpty) {
      return const EditorialLayoutResult(
        mode: EditorialLayoutMode.empty,
        placements: <BoardItemPlacement>[],
      );
    }

    // The first eight validated items are the complete visual contract. The
    // backend order remains untouched; only the canvas placement is bounded.
    final raw = _premium(
      items: board.items.take(8).toList(growable: false),
      width: width,
      height: height,
    );

    // Enforce safe zones, then sanitize any non-finite/overflowing geometry.
    final safe = _applySafeZone(raw.placements, width, height);
    final sane = _sanitize(safe, width, height);
    // Coverage-gated composition pass: only sparse boards get enlarged; a dense
    // template (the common 3-piece already fills ~85%) is returned untouched.
    final dense = _normalizeComposition(sane, width, height);
    final finalPlacements = _sanitize(
      _applySafeZone(dense, width, height),
      width,
      height,
    ).map((p) => p.rotation == 0.0 ? p : p.copyWith(rotation: 0.0)).toList();
    _logLayout(raw.mode, finalPlacements, width, height);
    return EditorialLayoutResult(mode: raw.mode, placements: finalPlacements);
  }

  static EditorialLayoutResult _premium({
    required List<StyleBoardItem> items,
    required double width,
    required double height,
  }) {
    final count = items.length;
    final hasDress = items.any((item) => item.role == BoardItemRole.dress);
    final hasOuterwear = items.any(
      (item) => item.role == BoardItemRole.outerwear,
    );
    final slots = _premiumSlots(
      count,
      hasDress: hasDress,
      hasOuterwear: hasOuterwear,
    );
    final remaining = [...items];
    final accessoryCount = items
        .where((item) => item.role == BoardItemRole.accessory)
        .length;
    var accessoryIndex = 0;
    final placements = <BoardItemPlacement>[];

    for (final slot in slots) {
      if (remaining.isEmpty) break;
      final item = _takeForRole(remaining, slot.role);
      if (item == null) continue;

      final placement = item.role == BoardItemRole.accessory && count >= 3
          ? _placePremiumAccessory(
              item,
              index: accessoryIndex++,
              total: accessoryCount,
              compact: count >= 6 || hasDress,
              width: width,
              height: height,
            )
          : (slot.template ??
                    const _Template(
                      0.56,
                      0.46,
                      0.26,
                      0.0,
                      1,
                      maxHeightFraction: 0.28,
                    ))
                .place(item, width, height);
      placements.add(placement);
    }

    return EditorialLayoutResult(
      mode: _premiumModeForCount(count),
      placements: _sorted(placements),
    );
  }

  static StyleBoardItem? _takeForRole(
    List<StyleBoardItem> remaining,
    BoardItemRole? role,
  ) {
    if (remaining.isEmpty) return null;
    final index = role == null
        ? 0
        : remaining.indexWhere((item) => item.role == role);
    return remaining.removeAt(index < 0 ? 0 : index);
  }

  static EditorialLayoutMode _premiumModeForCount(int count) => switch (count) {
    1 => EditorialLayoutMode.premiumOneItem,
    2 => EditorialLayoutMode.premiumTwoItem,
    3 => EditorialLayoutMode.premiumThreeItem,
    4 => EditorialLayoutMode.premiumFourItem,
    5 => EditorialLayoutMode.premiumFiveItem,
    6 => EditorialLayoutMode.premiumSixItem,
    7 => EditorialLayoutMode.premiumSevenItem,
    _ => EditorialLayoutMode.premiumEightItem,
  };

  static List<_PremiumSlot> _premiumSlots(
    int count, {
    required bool hasDress,
    required bool hasOuterwear,
  }) {
    if (count == 1) {
      return [
        _PremiumSlot(
          const _Template(0.14, 0.04, 0.72, 0.0, 2, maxHeightFraction: 0.82),
          hasDress ? BoardItemRole.dress : null,
        ),
      ];
    }
    if (count == 2) {
      if (hasDress) {
        return [
          _PremiumSlot(
            const _Template(0.10, 0.04, 0.781, 0.0, 2, maxHeightFraction: 0.82),
            BoardItemRole.dress,
          ),
          _PremiumSlot(
            const _Template(0.08, 0.72, 0.40, 0.0, 3, maxHeightFraction: 0.18),
            BoardItemRole.footwear,
          ),
        ];
      }
      return [
        _PremiumSlot(
          const _Template(0.05, 0.06, 0.62, 0.0, 2, maxHeightFraction: 0.62),
          hasDress ? BoardItemRole.dress : null,
        ),
        _PremiumSlot(
          const _Template(0.60, 0.50, 0.30, 0.0, 3, maxHeightFraction: 0.30),
          hasDress ? BoardItemRole.footwear : null,
        ),
      ];
    }
    if (hasDress) {
      return _dressPremiumSlots(count, hasOuterwear: hasOuterwear);
    }
    if (hasOuterwear && count >= 4) return _outerwearPremiumSlots(count);
    return _classicPremiumSlots(count);
  }

  static List<_PremiumSlot> _classicPremiumSlots(int count) {
    if (count == 3) {
      return [
        _PremiumSlot(
          const _Template(0.05, 0.06, 0.48, 0.0, 2, maxHeightFraction: 0.46),
          BoardItemRole.top,
        ),
        _PremiumSlot(
          const _Template(0.50, 0.20, 0.40, 0.0, 1, maxHeightFraction: 0.58),
          BoardItemRole.bottom,
        ),
        _PremiumSlot(
          const _Template(0.12, 0.72, 0.30, 0.0, 3, maxHeightFraction: 0.18),
          BoardItemRole.footwear,
        ),
      ];
    }
    if (count == 4) {
      return [
        _PremiumSlot(
          const _Template(0.05, 0.06, 0.48, 0.0, 2, maxHeightFraction: 0.46),
          BoardItemRole.top,
        ),
        _PremiumSlot(null, BoardItemRole.accessory),
        _PremiumSlot(
          const _Template(0.50, 0.20, 0.40, 0.0, 1, maxHeightFraction: 0.58),
          BoardItemRole.bottom,
        ),
        _PremiumSlot(
          const _Template(0.12, 0.72, 0.30, 0.0, 3, maxHeightFraction: 0.18),
          BoardItemRole.footwear,
        ),
      ];
    }
    if (count == 5) {
      return [
        _PremiumSlot(
          const _Template(0.05, 0.06, 0.37, 0.0, 2, maxHeightFraction: 0.46),
          BoardItemRole.top,
        ),
        _PremiumSlot(
          const _Template(0.46, 0.24, 0.35, 0.0, 1, maxHeightFraction: 0.58),
          BoardItemRole.bottom,
        ),
        _PremiumSlot(
          const _Template(0.12, 0.72, 0.29, 0.0, 3, maxHeightFraction: 0.18),
          BoardItemRole.footwear,
        ),
        _PremiumSlot(null, BoardItemRole.accessory),
        _PremiumSlot(null, BoardItemRole.accessory),
      ];
    }
    final core = count >= 7
        ? <_PremiumSlot>[
            _PremiumSlot(
              const _Template(
                0.04,
                0.03,
                0.40,
                0.0,
                2,
                maxHeightFraction: 0.42,
              ),
              BoardItemRole.top,
            ),
            _PremiumSlot(
              const _Template(
                0.46,
                0.03,
                0.34,
                0.0,
                1,
                maxHeightFraction: 0.50,
              ),
              BoardItemRole.bottom,
            ),
            _PremiumSlot(
              const _Template(
                0.05,
                0.57,
                0.28,
                0.0,
                3,
                maxHeightFraction: 0.18,
              ),
              BoardItemRole.footwear,
            ),
          ]
        : <_PremiumSlot>[
            _PremiumSlot(
              const _Template(
                0.04,
                0.04,
                0.40,
                0.0,
                2,
                maxHeightFraction: 0.42,
              ),
              BoardItemRole.top,
            ),
            _PremiumSlot(
              const _Template(
                0.44,
                0.04,
                0.38,
                0.0,
                1,
                maxHeightFraction: 0.50,
              ),
              BoardItemRole.bottom,
            ),
            _PremiumSlot(
              const _Template(
                0.08,
                0.62,
                0.30,
                0.0,
                3,
                maxHeightFraction: 0.18,
              ),
              BoardItemRole.footwear,
            ),
          ];
    return [
      ...core,
      for (var i = core.length; i < count; i++)
        _PremiumSlot(null, BoardItemRole.accessory),
    ];
  }

  static List<_PremiumSlot> _outerwearPremiumSlots(int count) {
    final core = <_PremiumSlot>[
      _PremiumSlot(
        const _Template(0.04, 0.04, 0.58, 0.0, 1, maxHeightFraction: 0.60),
        BoardItemRole.outerwear,
      ),
      _PremiumSlot(
        const _Template(0.16, 0.10, 0.46, 0.0, 2, maxHeightFraction: 0.42),
        BoardItemRole.top,
      ),
      _PremiumSlot(
        const _Template(0.46, 0.42, 0.48, 0.0, 1, maxHeightFraction: 0.50),
        BoardItemRole.bottom,
      ),
      _PremiumSlot(
        const _Template(0.12, 0.72, 0.30, 0.0, 3, maxHeightFraction: 0.18),
        BoardItemRole.footwear,
      ),
    ];
    return [
      ...core,
      for (var i = core.length; i < count; i++)
        _PremiumSlot(null, BoardItemRole.accessory),
    ];
  }

  static List<_PremiumSlot> _dressPremiumSlots(
    int count, {
    required bool hasOuterwear,
  }) {
    final core = <_PremiumSlot>[
      _PremiumSlot(
        const _Template(0.10, 0.04, 0.78, 0.0, 2, maxHeightFraction: 0.82),
        BoardItemRole.dress,
      ),
    ];
    if (count >= 4) {
      if (hasOuterwear) {
        core.add(
          _PremiumSlot(
            const _Template(0.58, 0.08, 0.30, 0.0, 1, maxHeightFraction: 0.34),
            BoardItemRole.outerwear,
          ),
        );
      }
      if (!hasOuterwear) {
        core.add(
          _PremiumSlot(
            const _Template(0.56, 0.42, 0.30, 0.0, 1, maxHeightFraction: 0.34),
            BoardItemRole.bottom,
          ),
        );
      }
    }
    if (count >= 3) {
      core.add(
        _PremiumSlot(
          const _Template(0.56, 0.08, 0.30, 0.0, 1, maxHeightFraction: 0.34),
          BoardItemRole.top,
        ),
      );
    }
    if (count >= 5 && hasOuterwear) {
      core.add(
        _PremiumSlot(
          const _Template(0.56, 0.42, 0.30, 0.0, 1, maxHeightFraction: 0.34),
          BoardItemRole.bottom,
        ),
      );
    }
    if (count >= 3) {
      core.add(
        _PremiumSlot(
          const _Template(0.08, 0.72, 0.40, 0.0, 3, maxHeightFraction: 0.18),
          BoardItemRole.footwear,
        ),
      );
    }
    return [
      ...core,
      for (var i = core.length; i < count; i++)
        _PremiumSlot(null, BoardItemRole.accessory),
    ];
  }

  static BoardItemPlacement _placePremiumAccessory(
    StyleBoardItem item, {
    required int index,
    required int total,
    required bool compact,
    required double width,
    required double height,
  }) {
    if (total <= 2 && !compact) {
      return _placeAccessory(
        item,
        index: index,
        width: width,
        height: height,
        compact: false,
      );
    }
    final positions = <(double, double, double)>[
      (0.64, 0.56, 0.18),
      (0.82, 0.56, 0.12),
      (0.64, 0.70, 0.18),
      (0.82, 0.70, 0.12),
      (0.50, 0.79, 0.14),
    ];
    final position = positions[math.min(index, positions.length - 1)];
    final boxWidth = width * position.$3;
    return BoardItemPlacement(
      item: item,
      x: width * position.$1,
      y: height * position.$2,
      width: boxWidth,
      height: _boxHeightForItem(item, boxWidth, height * 0.13),
      rotation: 0,
      zIndex: 4,
    );
  }

  static double _boxHeightForItem(
    StyleBoardItem item,
    double boxWidth,
    double maxHeight,
  ) {
    final aspectRatio = item.role == BoardItemRole.accessory
        ? _accessoryAspectRatio(item)
        : _arForRole(item.role);
    return (boxWidth * aspectRatio).clamp(0.0, maxHeight);
  }

  static _AccessoryKind _accessoryKind(StyleBoardItem item) {
    final value = [
      item.accessoryType,
      item.category,
      item.subCategory,
      item.boardRole,
      item.slot,
      item.name,
    ].join(' ').toLowerCase();
    if (RegExp(
      r'\b(bag|handbag|tote|clutch|purse|satchel|backpack)\b',
    ).hasMatch(value)) {
      return _AccessoryKind.bag;
    }
    if (RegExp(r'\b(belt|waistband|waist belt)\b').hasMatch(value)) {
      return _AccessoryKind.belt;
    }
    if (RegExp(r'\b(watch|timepiece)\b').hasMatch(value)) {
      return _AccessoryKind.watch;
    }
    if (RegExp(
      r'\b(jewellery|jewelry|necklace|bracelet|ring|earring|earrings)\b',
    ).hasMatch(value)) {
      return _AccessoryKind.jewellery;
    }
    if (RegExp(r'\b(headwear|hat|cap|beanie|turban)\b').hasMatch(value)) {
      return _AccessoryKind.headwear;
    }
    if (RegExp(r'\b(scarf|stole|shawl)\b').hasMatch(value)) {
      return _AccessoryKind.scarf;
    }
    return _AccessoryKind.generic;
  }

  static double _accessoryAspectRatio(StyleBoardItem item) =>
      switch (_accessoryKind(item)) {
        _AccessoryKind.belt => 0.34,
        _AccessoryKind.watch || _AccessoryKind.jewellery => 0.86,
        _AccessoryKind.headwear || _AccessoryKind.scarf => 0.72,
        _AccessoryKind.bag => 0.82,
        _AccessoryKind.generic => 0.92,
      };

  static BoardItemPlacement _placeAccessory(
    StyleBoardItem item, {
    required int index,
    required double width,
    required double height,
    bool compact = false,
  }) {
    final kind = _accessoryKind(item);
    final widthFraction = switch (kind) {
      _AccessoryKind.bag => compact ? 0.20 : 0.27,
      _AccessoryKind.belt => compact ? 0.18 : 0.24,
      _AccessoryKind.headwear || _AccessoryKind.scarf => 0.18,
      _AccessoryKind.watch || _AccessoryKind.jewellery => 0.11,
      _AccessoryKind.generic => compact ? 0.14 : 0.16,
    };
    final xFraction = switch (kind) {
      _AccessoryKind.bag => 0.68,
      _AccessoryKind.belt => 0.58,
      _AccessoryKind.headwear || _AccessoryKind.scarf => 0.70,
      _AccessoryKind.watch || _AccessoryKind.jewellery => 0.80,
      _AccessoryKind.generic => 0.78,
    };
    final yFraction = switch (kind) {
      _AccessoryKind.bag => 0.08 + index * 0.24,
      _AccessoryKind.belt => 0.48 + index * 0.16,
      _AccessoryKind.headwear || _AccessoryKind.scarf => 0.05 + index * 0.16,
      _AccessoryKind.watch || _AccessoryKind.jewellery => 0.40 + index * 0.14,
      _AccessoryKind.generic => 0.10 + index * 0.20,
    };
    final boxWidth = width * widthFraction;
    final maxHeight = switch (kind) {
      _AccessoryKind.bag => height * 0.26,
      _AccessoryKind.belt => height * 0.10,
      _AccessoryKind.headwear || _AccessoryKind.scarf => height * 0.16,
      _AccessoryKind.watch || _AccessoryKind.jewellery => height * 0.12,
      _AccessoryKind.generic => height * 0.16,
    };
    return BoardItemPlacement(
      item: item,
      x: width * xFraction,
      y: height * yFraction,
      width: boxWidth,
      height: _boxHeightForItem(item, boxWidth, maxHeight),
      rotation: 0,
      zIndex: 4,
    );
  }

  static List<BoardItemPlacement> _sorted(List<BoardItemPlacement> placements) {
    return <BoardItemPlacement>[...placements]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }

  /// Enforce safe zones on every placement:
  ///   top 5%, sides 6%, bottom 10%.
  /// Items whose bottom exceeds the safe-bottom boundary are moved UP; items
  /// past the top/side margins are clamped to the margin. Boxes are only shrunk
  /// when they are physically too large to fit the safe band (last resort) so
  /// nothing is ever clipped outside the board.
  static List<BoardItemPlacement> _applySafeZone(
    List<BoardItemPlacement> placements,
    double width,
    double height,
  ) {
    final safeTopY = height * 0.05;
    final safeBottomY = height * 0.90;
    final safeLeftX = width * 0.06;
    final safeRightX = width * 0.94;
    final maxW = safeRightX - safeLeftX;
    final maxH = safeBottomY - safeTopY;

    return placements.map((p) {
      double w = p.width;
      double h = p.height;
      // Last-resort shrink: never wider/taller than the safe band.
      if (w > maxW) w = maxW;
      if (h > maxH) h = maxH;

      double x = p.x;
      double y = p.y;
      if (y + h > safeBottomY) y = safeBottomY - h;
      if (y < safeTopY) y = safeTopY;
      if (x + w > safeRightX) x = safeRightX - w;
      if (x < safeLeftX) x = safeLeftX;

      if (w == p.width && h == p.height && x == p.x && y == p.y) return p;
      return p.copyWith(x: x, y: y, width: w, height: h);
    }).toList();
  }

  /// Final guard: replace any non-finite geometry with safe values and clamp
  /// everything inside the canvas. Protects Positioned/Stack from NaN/Infinity
  /// (which throw at layout) when upstream math misbehaves.
  static List<BoardItemPlacement> _sanitize(
    List<BoardItemPlacement> placements,
    double width,
    double height,
  ) {
    return placements.map((p) {
      double w = _finitePositive(p.width) ? p.width : width * 0.3;
      double h = _finitePositive(p.height) ? p.height : height * 0.3;
      w = w.clamp(1.0, width);
      h = h.clamp(1.0, height);
      double x = p.x.isFinite ? p.x : 0.0;
      double y = p.y.isFinite ? p.y : 0.0;
      x = x.clamp(0.0, math.max(0.0, width - w));
      y = y.clamp(0.0, math.max(0.0, height - h));
      final rot = p.rotation.isFinite ? p.rotation : 0.0;
      if (w == p.width &&
          h == p.height &&
          x == p.x &&
          y == p.y &&
          rot == p.rotation) {
        return p;
      }
      return p.copyWith(x: x, y: y, width: w, height: h, rotation: rot);
    }).toList();
  }

  static void _logLayout(
    EditorialLayoutMode mode,
    List<BoardItemPlacement> placements,
    double width,
    double height,
  ) {
    if (!kDebugMode) return;
    for (final p in placements) {
      final scale = (p.width / width);
      debugPrint(
        'AHVI_BOARD_LAYOUT mode=${mode.name} '
        'role=${p.item.role.name} '
        'scale=${scale.toStringAsFixed(3)} '
        'x=${(p.x / width).toStringAsFixed(3)} '
        'y=${(p.y / height).toStringAsFixed(3)} '
        'w=${(p.width / width).toStringAsFixed(3)} '
        'h=${(p.height / height).toStringAsFixed(3)} '
        'z=${p.zIndex}',
      );
    }
  }

  // --- Composition density pass -----------------------------------------
  static const double _covWMin = 0.78;
  static const double _covHMin = 0.74;
  static const double _covWTarget = 0.88;
  static const double _covHTarget = 0.86;
  static const double _compMaxScale = 1.18;

  /// Fractional width/height coverage of the union of [placements] over the
  /// canvas. Exposed for tests.
  static ({double width, double height}) unionCoverage(
    List<BoardItemPlacement> placements,
    double width,
    double height,
  ) {
    if (placements.isEmpty ||
        !_finitePositive(width) ||
        !_finitePositive(height)) {
      return (width: 0.0, height: 0.0);
    }
    final b = _unionBounds(placements);
    final uw = (b[2] - b[0]).clamp(0.0, width);
    final uh = (b[3] - b[1]).clamp(0.0, height);
    return (width: uw / width, height: uh / height);
  }

  static List<double> _unionBounds(List<BoardItemPlacement> placements) {
    double minX = double.infinity,
        minY = double.infinity,
        maxX = -double.infinity,
        maxY = -double.infinity;
    for (final p in placements) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x + p.width);
      maxY = math.max(maxY, p.y + p.height);
    }
    return <double>[minX, minY, maxX, maxY];
  }

  /// Uniformly scale + recentre the whole composition ONLY when its union
  /// covers too little of the canvas (width < [_covWMin] OR height < [_covHMin]).
  /// Dense boards are returned untouched. Never enlarges past [_compMaxScale];
  /// downstream _applySafeZone + _sanitize keep everything in-bounds.
  static List<BoardItemPlacement> _normalizeComposition(
    List<BoardItemPlacement> placements,
    double width,
    double height,
  ) {
    if (placements.length < 2 ||
        !_finitePositive(width) ||
        !_finitePositive(height)) {
      return placements;
    }
    final cov = unionCoverage(placements, width, height);
    if (cov.width >= _covWMin && cov.height >= _covHMin) return placements;
    if (cov.width <= 0 || cov.height <= 0) return placements;

    final scale = math
        .min(_covWTarget / cov.width, _covHTarget / cov.height)
        .clamp(1.0, _compMaxScale);
    if (scale <= 1.0) return placements;

    final b = _unionBounds(placements);
    final cx = (b[0] + b[2]) / 2;
    final cy = (b[1] + b[3]) / 2;
    final scaled = placements
        .map(
          (p) => p.copyWith(
            x: cx + (p.x - cx) * scale,
            y: cy + (p.y - cy) * scale,
            width: p.width * scale,
            height: p.height * scale,
          ),
        )
        .toList();

    // Recentre the enlarged union on the canvas centre.
    final nb = _unionBounds(scaled);
    final dx = width / 2 - (nb[0] + nb[2]) / 2;
    final dy = height / 2 - (nb[1] + nb[3]) / 2;
    return scaled.map((p) => p.copyWith(x: p.x + dx, y: p.y + dy)).toList();
  }

  /// Test hook for the composition pass.
  @visibleForTesting
  static List<BoardItemPlacement> debugNormalizeComposition(
    List<BoardItemPlacement> placements,
    double width,
    double height,
  ) => _normalizeComposition(placements, width, height);

  static bool _finitePositive(double v) => v.isFinite && v > 0;
}

class _Template {
  final double x;
  final double y;
  final double w;
  final double rotation;
  final int z;
  final double maxHeightFraction;

  const _Template(
    this.x,
    this.y,
    this.w,
    this.rotation,
    this.z, {
    this.maxHeightFraction = 0.46,
  });

  /// Height is derived from the item's role aspect ratio (not a fixed fraction)
  /// so the contained cutout fills the box; capped to the lower canvas band.
  BoardItemPlacement place(StyleBoardItem item, double width, double height) {
    final boxW = width * w;
    final boxH = EditorialBoardLayoutEngine._boxHeightForItem(
      item,
      boxW,
      height * maxHeightFraction,
    );
    return BoardItemPlacement(
      item: item,
      x: width * x,
      y: height * y,
      width: boxW,
      height: boxH,
      rotation: rotation,
      zIndex: z,
    );
  }
}

class _PremiumSlot {
  final _Template? template;
  final BoardItemRole? role;

  const _PremiumSlot(this.template, this.role);
}

enum _AccessoryKind { bag, belt, watch, jewellery, headwear, scarf, generic }
