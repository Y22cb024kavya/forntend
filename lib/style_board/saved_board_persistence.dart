import 'dart:convert';

const savedBoardAcceptedFields = <String>{
  'userId',
  'occasion',
  'outfitDescription',
  'emoji',
  'imageUrl',
  'itemIds',
};

const _savedBoardEnvelopeSchema = 'ahvi_saved_board_v1';

Map<String, dynamic> canonicalSavedBoard({
  required Map<String, dynamic> direction,
  required String title,
  required String occasion,
  required String outfitDescription,
  required List<String> itemIds,
  required List<Map<String, dynamic>> items,
}) {
  return <String, dynamic>{
    ...direction,
    'title': title,
    'occasion': occasion,
    'outfitDescription': outfitDescription,
    'itemIds': itemIds,
    'items': items,
    'board_items': items,
  };
}

Map<String, dynamic> savedBoardLegacyPayload({
  required String userId,
  required String occasion,
  required String imageUrl,
  required String emoji,
  required List<String> itemIds,
  required Map<String, dynamic> board,
}) {
  return <String, dynamic>{
    'userId': userId,
    'occasion': occasion,
    'outfitDescription': jsonEncode({
      'schema': _savedBoardEnvelopeSchema,
      'board': board,
    }),
    'emoji': emoji,
    'imageUrl': imageUrl,
    'itemIds': itemIds,
  };
}

Map<String, dynamic> expandSavedBoardData(Map<String, dynamic> data) {
  Map<String, dynamic>? decodeMap(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is! String || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? canonical;
  final descriptionEnvelope = decodeMap(data['outfitDescription']);
  if (descriptionEnvelope?['schema'] == _savedBoardEnvelopeSchema) {
    canonical = decodeMap(descriptionEnvelope?['board']);
  }
  canonical ??= decodeMap(data['board_payload']);
  canonical ??= decodeMap(data['boardPayload']);
  if (canonical == null) return data;

  return <String, dynamic>{...data, ...canonical};
}
