import 'package:flutter/foundation.dart';

class ResolvedWardrobeImage {
  final String? url;
  final String field;
  final String sourceKind;
  final int tier;
  final bool expectedTransparent;
  final bool validated;
  final bool shouldFrame;

  const ResolvedWardrobeImage({
    required this.url,
    required this.field,
    required this.sourceKind,
    required this.tier,
    required this.expectedTransparent,
    required this.validated,
    required this.shouldFrame,
  });

  bool get usedMasked => sourceKind == 'masked';
}

class _Candidate {
  final String field;
  final String? url;
  final String sourceKind;
  final int tier;
  final bool expectedTransparent;
  final bool validated;

  const _Candidate(
    this.field,
    this.url,
    this.sourceKind,
    this.tier,
    this.expectedTransparent,
    this.validated,
  );
}

final Set<String> _diagnosticKeys = <String>{};

@visibleForTesting
void resetWardrobeImageDiagnosticCache() => _diagnosticKeys.clear();

String? _clean(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}

String _status(Map<String, dynamic> raw, String snake, String camel) =>
    _clean(raw[snake] ?? raw[camel])?.toLowerCase() ?? '';

bool _objectPathMatches(String? url, RegExp pattern) {
  if (url == null) return false;
  final path = Uri.tryParse(url)?.path ?? url.split(RegExp(r'[?#]')).first;
  try {
    return pattern.hasMatch(Uri.decodeComponent(path));
  } on FormatException {
    return pattern.hasMatch(path);
  }
}

bool _isCatalogObject(String? url) => _objectPathMatches(
  url,
  RegExp(r'(?:^|/)catalog_[^/]*\.(?:png|jpg)(?:$|/)', caseSensitive: false),
);

bool _isWardrobeCutoutObject(String? url) => _objectPathMatches(
  url,
  RegExp(
    r'(?:^|/)wardrobe_[^/]+(?:_cutout_v[^/]*)?\.png(?:$|/)',
    caseSensitive: false,
  ),
);

ResolvedWardrobeImage resolveWardrobeImage(
  Map<String, dynamic> raw, {
  String? normalizedUrl,
  String? imageUrl,
  String? maskedUrl,
  String surface = 'wardrobe',
  String itemId = '',
  bool emitDiagnostic = true,
}) {
  final boardStatus = _status(raw, 'board_status', 'boardStatus');
  final cutoutStatus = _status(raw, 'cutout_status', 'cutoutStatus');
  final imageStatus = _status(raw, 'image_status', 'imageStatus');
  final source =
      _clean(
        raw['source'] ?? raw['item_source'] ?? raw['itemSource'],
      )?.toLowerCase() ??
      '';
  final cutoutReady = cutoutStatus == 'ready';
  final boardReady = boardStatus == 'cutout_ready';
  final boardValidated = boardReady || source == 'style_asset';
  final rmbgReady = imageStatus == 'rmbg_complete';
  final originalUrls = <String>{
    ...[
      imageUrl,
      raw['image_url'],
      raw['imageUrl'],
      raw['original_image_url'],
      raw['originalImageUrl'],
      raw['raw_url'],
      raw['rawUrl'],
      raw['preview_url'],
      raw['previewUrl'],
    ].map(_clean).whereType<String>(),
  };

  final boardImage = _clean(raw['board_image_url'] ?? raw['boardImageUrl']);
  final cutoutImage = _clean(raw['cutout_url'] ?? raw['cutoutUrl']);
  final resolvedMasked = _clean(
    maskedUrl ?? raw['masked_url'] ?? raw['maskedUrl'],
  );
  final maskedImage = _clean(raw['masked_image_url'] ?? raw['maskedImageUrl']);
  final maskedIsOriginal =
      resolvedMasked != null && originalUrls.contains(resolvedMasked);
  final maskedIsCatalog = _isCatalogObject(resolvedMasked);
  final maskedImageIsCatalog = _isCatalogObject(maskedImage);
  final frozenField = _clean(raw['selected_field']);
  final frozenSource = _clean(raw['source_kind']);
  final frozenUrl = frozenField != null && frozenSource != null
      ? _clean(raw['image_url'] ?? raw['imageUrl'])
      : null;
  final frozenIsCatalog = _isCatalogObject(frozenUrl);
  final frozenExpected = raw['expected_transparent'] == true;

  final candidates = <_Candidate>[
    if (frozenUrl != null)
      _Candidate(
        frozenField!,
        frozenUrl,
        frozenIsCatalog ? 'catalog_fallback' : frozenSource!,
        frozenIsCatalog ? 3 : (frozenExpected ? 0 : 4),
        frozenIsCatalog ? false : frozenExpected,
        !frozenIsCatalog && frozenExpected,
      ),
    if (boardValidated)
      _Candidate(
        'board_image_url',
        boardImage,
        'validated_cutout',
        0,
        true,
        true,
      ),
    if (cutoutReady)
      _Candidate('cutout_url', cutoutImage, 'validated_cutout', 0, true, true),
    if (boardReady)
      _Candidate(
        'image_url',
        _clean(raw['image_url'] ?? raw['imageUrl'] ?? imageUrl),
        'validated_cutout',
        0,
        true,
        true,
      ),
    if (!maskedIsOriginal && !maskedIsCatalog)
      _Candidate(
        'masked_url',
        resolvedMasked,
        'masked',
        1,
        true,
        rmbgReady || _isWardrobeCutoutObject(resolvedMasked),
      ),
    if (!maskedIsOriginal && !maskedImageIsCatalog)
      _Candidate(
        'masked_image_url',
        maskedImage,
        'masked',
        1,
        true,
        rmbgReady || _isWardrobeCutoutObject(maskedImage),
      ),
    _Candidate(
      'rmbg_url',
      _clean(raw['rmbg_url'] ?? raw['rmbgUrl']),
      'processed_cutout',
      2,
      true,
      rmbgReady,
    ),
    _Candidate(
      'transparent_image_url',
      _clean(raw['transparent_image_url'] ?? raw['transparentImageUrl']),
      'processed_cutout',
      2,
      true,
      boardValidated || cutoutReady,
    ),
    _Candidate(
      'processed_url',
      _clean(raw['processed_url'] ?? raw['processedUrl']),
      'processed_cutout',
      2,
      true,
      rmbgReady,
    ),
    _Candidate(
      'board_image_url',
      boardImage,
      'processed_cutout',
      2,
      true,
      false,
    ),
    _Candidate('cutout_url', cutoutImage, 'processed_cutout', 2, true, false),
    _Candidate(
      'normalized_url',
      _clean(
        normalizedUrl ??
            raw['normalized_url'] ??
            raw['normalizedUrl'] ??
            raw['normalized_image_url'] ??
            raw['normalizedImageUrl'],
      ),
      'catalog_fallback',
      3,
      false,
      false,
    ),
    _Candidate(
      'catalog_image_url',
      _clean(raw['catalog_image_url'] ?? raw['catalogImageUrl']),
      'catalog_fallback',
      3,
      false,
      false,
    ),
    _Candidate(
      'display_image_url',
      _clean(raw['display_image_url'] ?? raw['displayImageUrl']),
      'catalog_fallback',
      3,
      false,
      false,
    ),
    if (maskedIsCatalog)
      _Candidate(
        'masked_url',
        resolvedMasked,
        'catalog_fallback',
        3,
        false,
        false,
      ),
    if (maskedImageIsCatalog)
      _Candidate(
        'masked_image_url',
        maskedImage,
        'catalog_fallback',
        3,
        false,
        false,
      ),
    _Candidate(
      'image_url',
      _clean(imageUrl ?? raw['image_url'] ?? raw['imageUrl']),
      'original',
      4,
      false,
      false,
    ),
    _Candidate(
      'raw_url',
      _clean(raw['raw_url'] ?? raw['rawUrl']),
      'original',
      4,
      false,
      false,
    ),
    _Candidate(
      'preview_url',
      _clean(raw['preview_url'] ?? raw['previewUrl']),
      'original',
      4,
      false,
      false,
    ),
    _Candidate(
      'url',
      _clean(raw['url'] ?? raw['thumbnailUrl']),
      'original',
      4,
      false,
      false,
    ),
  ];

  final selected = candidates.firstWhere(
    (candidate) => candidate.url != null,
    orElse: () => const _Candidate('none', null, 'missing', 5, false, false),
  );
  final result = ResolvedWardrobeImage(
    url: selected.url,
    field: selected.field,
    sourceKind: selected.sourceKind,
    tier: selected.tier,
    expectedTransparent: selected.expectedTransparent,
    validated: selected.validated,
    shouldFrame: selected.url != null && !selected.validated,
  );

  if (emitDiagnostic) {
    final diagnosticId = itemId.trim().isNotEmpty
        ? itemId.trim()
        : _clean(raw['item_id'] ?? raw['id'] ?? raw[r'$id']) ?? 'unknown';
    final key = '$diagnosticId|$surface|${result.field}|${result.sourceKind}';
    if (_diagnosticKeys.add(key)) {
      debugPrint(
        'AHVI_WARDROBE_IMAGE_RESOLVE '
        'item_id=$diagnosticId '
        'surface=$surface '
        'selected_field=${result.field} '
        'source_kind=${result.sourceKind} '
        'expected_transparent=${result.expectedTransparent}',
      );
    }
  }
  return result;
}
