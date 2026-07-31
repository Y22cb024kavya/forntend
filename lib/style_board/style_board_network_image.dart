import 'package:flutter/material.dart';

import '../util/wardrobe_image_resolver.dart';

/// Walks an ordered list of Style-board image candidates, advancing to the
/// next source when the current one fails at runtime (403/404/timeout/decode).
/// The caller styles each candidate via [builder] using the candidate's own
/// provenance (so framing flips when a transparent cutout falls back to an
/// opaque catalog image). Scaling stays in the caller — never here.
///
/// The placeholder shows only after every candidate has failed.
class StyleBoardNetworkImage extends StatefulWidget {
  const StyleBoardNetworkImage({
    super.key,
    required this.candidates,
    required this.builder,
    required this.placeholder,
    this.surface = 'style_board_render',
    this.role,
    this.itemId = '',
    this.fit = BoxFit.contain,
    this.fitBuilder,
    this.alignment = Alignment.center,
  });

  final List<ResolvedWardrobeImage> candidates;

  /// Renders the current candidate. `current` carries source_kind /
  /// expected_transparent / requires_frame; `image` is the live Image widget
  /// (already wired to advance on error).
  final Widget Function(
    BuildContext context,
    ResolvedWardrobeImage current,
    Widget image,
  ) builder;

  final Widget placeholder;
  final String surface;
  final String? role;
  final String itemId;
  final BoxFit fit;

  /// Per-candidate fit override (e.g. framed accessories use cover). Falls back
  /// to [fit].
  final BoxFit Function(ResolvedWardrobeImage current)? fitBuilder;
  final Alignment alignment;

  @override
  State<StyleBoardNetworkImage> createState() => _StyleBoardNetworkImageState();
}

class _StyleBoardNetworkImageState extends State<StyleBoardNetworkImage> {
  int _index = 0;

  List<ResolvedWardrobeImage> get _usable => widget.candidates
      .where((c) => (c.url ?? '').trim().isNotEmpty && _isHttp(c.url!))
      .toList(growable: false);

  static bool _isHttp(String url) {
    final u = Uri.tryParse(url.trim());
    return u != null && (u.scheme == 'http' || u.scheme == 'https');
  }

  @override
  void didUpdateWidget(StyleBoardNetworkImage old) {
    super.didUpdateWidget(old);
    // Reset when the item or its candidate URLs change.
    final oldUrls = old.candidates.map((c) => c.url).join('|');
    final newUrls = widget.candidates.map((c) => c.url).join('|');
    if (old.itemId != widget.itemId || oldUrls != newUrls) {
      _index = 0;
    }
  }

  void _advanceFrom(int failedIndex, Object error) {
    if (!mounted || failedIndex != _index) return; // stale error, ignore
    final list = _usable;
    final from = list[failedIndex];
    if (failedIndex + 1 >= list.length) {
      debugPrint(
        'AHVI_STYLE_ITEM_IMAGE_EXHAUSTED '
        'surface=${widget.surface} role=${widget.role ?? ''} '
        'last_field=${from.field} last_source=${from.sourceKind} '
        'candidate_count=${list.length}',
      );
      setState(() => _index = list.length); // -> placeholder
      return;
    }
    final next = list[failedIndex + 1];
    debugPrint(
      'AHVI_STYLE_ITEM_IMAGE_FALLBACK '
      'surface=${widget.surface} role=${widget.role ?? ''} '
      'failed_field=${from.field} failed_source=${from.sourceKind} '
      'next_field=${next.field} next_source=${next.sourceKind} '
      'failure=${_category(error)} attempt=${failedIndex + 1}',
    );
    setState(() => _index = failedIndex + 1);
  }

  static String _category(Object error) {
    if (error is NetworkImageLoadException) {
      return error.statusCode > 0 ? 'http' : 'network';
    }
    final s = error.toString().toLowerCase();
    if (s.contains('timeout')) return 'timeout';
    if (s.contains('socket') || s.contains('connection')) return 'network';
    if (s.contains('codec') || s.contains('decode') || s.contains('format')) {
      return 'decode';
    }
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    final list = _usable;
    if (list.isEmpty || _index >= list.length) return widget.placeholder;
    final current = list[_index];
    final failedIndex = _index;
    final image = Image.network(
      current.url!,
      fit: widget.fitBuilder?.call(current) ?? widget.fit,
      alignment: widget.alignment,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, error, _) {
        // errorBuilder runs during build; defer the advance a frame.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _advanceFrom(failedIndex, error),
        );
        return const SizedBox.shrink();
      },
    );
    return widget.builder(context, current, image);
  }
}
