import 'package:flutter/foundation.dart';

/// Count-only diagnostics for the active AHVI style surfaces.
///
/// Values are deliberately allowlisted. This class must never receive or log
/// auth headers, user identifiers, wardrobe records, message bodies, URLs, or
/// unmasked board/item identifiers.
class AhviStyleDiagnostics {
  static int _requestSequence = 0;

  static String nextCorrelationId() => 'style-${++_requestSequence}';

  static Map<String, int> responseAliasCounts(Map<String, dynamic> response) {
    final data = _asMap(response['data']);
    return {
      'data.rendered_boards': _listCount(data['rendered_boards']),
      'rendered_boards': _listCount(response['rendered_boards']),
      'style_boards': _listCount(response['style_boards']),
      'data.outfits': _listCount(data['outfits']),
      'outfits': _listCount(response['outfits']),
      'cards': _listCount(response['cards']),
      'visual_directions': _listCount(response['visual_directions']),
      'data.visual_directions': _listCount(data['visual_directions']),
      'style_directions': _listCount(response['style_directions']),
      'data.style_directions': _listCount(data['style_directions']),
    };
  }

  static int listCount(Object? value) => _listCount(value);

  static ({String path, List<Map<String, dynamic>> boards}) selectAlias(
    Map<String, dynamic> response,
  ) {
    final data = _asMap(response['data']);
    final candidates = <({String path, Object? value})>[
      (path: 'data.rendered_boards', value: data['rendered_boards']),
      (path: 'rendered_boards', value: response['rendered_boards']),
      (path: 'style_boards', value: response['style_boards']),
      (path: 'data.style_boards', value: data['style_boards']),
      (path: 'cards', value: response['cards']),
      (path: 'data.cards', value: data['cards']),
      (path: 'data.outfits', value: data['outfits']),
      (path: 'outfits', value: response['outfits']),
    ];
    for (final candidate in candidates) {
      final boards = _mapList(candidate.value);
      if (boards.isNotEmpty) return (path: candidate.path, boards: boards);
    }
    return (path: '', boards: const []);
  }

  static String maskedIdentifiers(Object? value) {
    if (value is! List) return 'none';
    final masked = <String>[];
    for (final entry in value) {
      if (entry is! Map) continue;
      final id =
          entry['board_id'] ??
          entry['boardId'] ??
          entry['item_id'] ??
          entry['id'];
      if (id != null && id.toString().trim().isNotEmpty) {
        masked.add(maskIdentifier(id));
      }
    }
    return masked.isEmpty ? 'missing' : masked.join(',');
  }

  static String maskIdentifier(Object? value) {
    final input = value?.toString() ?? '';
    if (input.trim().isEmpty) return 'missing';
    var hash = 2166136261;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return 'id-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  static int invalidStyleThisDirectionCount(
    List<Map<String, dynamic>> directions,
  ) {
    return directions.where((direction) {
      final boardId = _text(direction['board_id'] ?? direction['boardId']);
      final revision = direction['revision'];
      final source = _text(
        direction['source_policy'] ?? direction['sourcePolicy'],
      );
      final interaction = _text(
        direction['interaction_mode'] ?? direction['interactionMode'],
      );
      final items = direction['board_items'] ?? direction['boardItems'];
      return boardId.isEmpty ||
          boardId.startsWith('outfit_card_') ||
          revision is! num ||
          revision < 1 ||
          source != 'wardrobe' ||
          interaction != 'style_this' ||
          items is! List ||
          items.isEmpty;
    }).length;
  }

  static void logResponse({
    required String correlationId,
    required Map<String, dynamic> response,
    required String selectedAlias,
    required int selectedRawCount,
    required int parserInputCount,
    required int parserAcceptedCount,
    required int policyRejectedCount,
    required int invalidContractCount,
    required int dedupDroppedCount,
    required int finalRenderedCount,
    required int staleResponseDiscardedCount,
    String promptCategory = 'unknown',
    String boardIds = 'none',
  }) {
    final aliases = responseAliasCounts(response);
    final policy = _asMap(response['data']);
    final sources = [response, policy];
    String value(String key) {
      for (final source in sources) {
        final candidate = source[key];
        if (candidate != null && candidate.toString().trim().isNotEmpty) {
          return _safe(candidate);
        }
      }
      return 'unknown';
    }

    debugPrint(
      'AHVI_STYLE_RESPONSE_COUNTS '
      'correlation_id=${_safe(correlationId)} '
      'prompt_category=${_safe(promptCategory)} '
      'route=${value('route')} mode=${value('mode')} intent=${value('intent')} '
      'action=${value('action')} board_policy=${value('board_policy')} '
      'interaction_mode=${value('interaction_mode')} '
      'source_policy=${value('source_policy')} '
      'alias_data_rendered_boards=${aliases['data.rendered_boards']} '
      'alias_rendered_boards=${aliases['rendered_boards']} '
      'alias_style_boards=${aliases['style_boards']} '
      'alias_data_outfits=${aliases['data.outfits']} '
      'alias_outfits=${aliases['outfits']} alias_cards=${aliases['cards']} '
      'alias_visual_directions=${aliases['visual_directions']} '
      'alias_data_visual_directions=${aliases['data.visual_directions']} '
      'alias_style_directions=${aliases['style_directions']} '
      'alias_data_style_directions=${aliases['data.style_directions']} '
      'selected_alias=${_safe(selectedAlias)} '
      'selected_raw_count=$selectedRawCount parser_input_count=$parserInputCount '
      'parser_accepted_count=$parserAcceptedCount '
      'policy_rejected_count=$policyRejectedCount '
      'invalid_contract_count=$invalidContractCount '
      'dedup_dropped_count=$dedupDroppedCount '
      'final_rendered_count=$finalRenderedCount '
      'stale_response_discarded_count=$staleResponseDiscardedCount '
      'board_ids=$boardIds',
    );
  }

  static void logBoardRender({
    required String correlationId,
    required int parserInputCount,
    required int parserAcceptedCount,
    required int policyRejectedCount,
    required int invalidContractCount,
    required int dedupDroppedCount,
    required int finalRenderedCount,
    required int staleResponseDiscardedCount,
  }) {
    debugPrint(
      'AHVI_STYLE_RESPONSE_COUNTS '
      'correlation_id=${_safe(correlationId)} '
      'phase=board_render parser_input_count=$parserInputCount '
      'parser_accepted_count=$parserAcceptedCount '
      'policy_rejected_count=$policyRejectedCount '
      'invalid_contract_count=$invalidContractCount '
      'dedup_dropped_count=$dedupDroppedCount '
      'final_rendered_count=$finalRenderedCount '
      'stale_response_discarded_count=$staleResponseDiscardedCount',
    );
  }

  static void logStyleThisContract({
    required String correlationId,
    required Map<String, dynamic>? response,
    required List<Map<String, dynamic>> directions,
    required List<List<String>> failures,
    required String anchorItemId,
  }) {
    final first = directions.isEmpty
        ? const <String, dynamic>{}
        : directions.first;
    final anchor = _asMap(response?['anchor_item']);
    final anchorId = anchor['item_id'] ?? anchor['id'] ?? anchor[r'$id'];
    final anchorPresent =
        anchorItemId.trim().isNotEmpty ||
        anchorId?.toString().trim().isNotEmpty == true;
    final responseData = _asMap(response?['data']);
    final locked = response?['anchor_locked'] ?? responseData['anchor_locked'];
    final failed = <String>{for (final fields in failures) ...fields};
    final itemList = first['board_items'] ?? first['boardItems'];
    final imageField = _firstPresentField(first, const [
      'image_url',
      'imageUrl',
      'normalized_url',
      'normalizedUrl',
      'masked_url',
      'maskedUrl',
      'resolved_image_url',
    ]);
    debugPrint(
      'AHVI_STYLE_THIS_CONTRACT '
      'correlation_id=${_safe(correlationId)} '
      'success=${response?['success'] == true} '
      'board_direction_count=${directions.length} '
      'valid_direction_count=${failures.where((fields) => fields.isEmpty).length} '
      'invalid_direction_count=${failures.where((fields) => fields.isNotEmpty).length} '
      'board_id=${maskIdentifier(first['board_id'] ?? first['boardId'])} '
      'revision_valid=${first['revision'] is num && (first['revision'] as num) >= 1} '
      'source_policy=${_safe(first['source_policy'] ?? first['sourcePolicy'])} '
      'interaction_mode=${_safe(first['interaction_mode'] ?? first['interactionMode'])} '
      'anchor_item_id=${maskIdentifier(anchorItemId)} '
      'anchor_present=$anchorPresent '
      'anchor_locked=${_boolOrUnknown(locked)} '
      'can_lock=${_boolOrUnknown(response?['can_lock'])} '
      'can_shuffle=${_boolOrUnknown(response?['can_shuffle'])} '
      'board_items_count=${_listCount(itemList)} '
      'image_field=${imageField.isEmpty ? 'missing' : imageField} '
      'expected_transparent=${_boolOrUnknown(first['expected_transparent'])} '
      'requires_frame=${_boolOrUnknown(first['requires_frame'])} '
      'failed_predicates=${failed.isEmpty ? 'none' : failed.map(_safe).join(',')}',
    );
  }

  static void logStaleResponse({
    required String correlationId,
    required int staleResponseDiscardedCount,
  }) {
    debugPrint(
      'AHVI_STYLE_RESPONSE_COUNTS '
      'correlation_id=${_safe(correlationId)} phase=stale_response '
      'stale_response_discarded_count=$staleResponseDiscardedCount',
    );
  }

  static String _firstPresentField(
    Map<String, dynamic> value,
    List<String> fields,
  ) {
    for (final field in fields) {
      final raw = value[field];
      if (raw != null && raw.toString().trim().isNotEmpty) return field;
    }
    return '';
  }

  static Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static int _listCount(Object? value) => value is List ? value.length : 0;

  static String _text(Object? value) =>
      value?.toString().trim().toLowerCase() ?? '';

  static String _safe(Object? value) =>
      _text(value).replaceAll(RegExp(r'[^a-z0-9_.:/,-]'), '_');

  static String _boolOrUnknown(Object? value) {
    if (value is bool) return value.toString();
    if (value is num) return (value != 0).toString();
    return 'unknown';
  }
}
