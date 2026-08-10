import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String _section(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'missing $start');
  final endIndex = source.indexOf(end, startIndex);
  expect(endIndex, isNonNegative, reason: 'missing $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  final stylist = _read('lib/widgets/ahvi_stylist_chat.dart');
  final chat = _read('lib/chat.dart');
  final backend = _read('lib/services/backend_service.dart');

  test('legacy ChatScreen keeps only closest-option on /api/text', () {
    final selector = _section(
      chat,
      'final bool styleViaText =',
      'final Map<String, dynamic> response;',
    );

    expect(selector, contains('isStyleModule && isClosestAction'));
    expect(selector, isNot(contains('isClarificationAnswer')));
  });

  test('legacy ChatScreen clarification uses canonical history and context', () {
    final canonicalBranch = _section(
      chat,
      '} else if (isStyleModule) {',
      '} else {',
    );

    expect(canonicalBranch, contains('backend.sendModuleChat('));
    expect(canonicalBranch, contains('context: styleContext.isEmpty ? null : styleContext'));
    expect(canonicalBranch, contains('chatHistory: List<Map<String, String>>.from(_chatHistory)'));
  });

  test('Style sheet retains only explicit legacy action families', () {
    final selector = _section(
      stylist,
      'final keepLegacyStyleText =',
      'final useCanonicalStyleModuleChat =',
    );

    expect(selector, contains('isClosestStyleAction'));
    expect(selector, contains('isWardrobeAction'));
    expect(selector, contains('isBoardActionPhrase'));
    expect(selector, contains('_isSpecializedStyleRequest(trimmed)'));
    expect(selector, isNot(contains('isClarificationAnswer')));
  });

  test('canonical Style requests send history and structured context', () {
    final canonicalBranch = _section(
      stylist,
      'domain: styleModuleContext,',
      ': styleModules.contains(widget.moduleContext)',
    );

    expect(canonicalBranch, contains('chatHistory: List<Map<String, String>>.from(_chatHistory)'));
    expect(canonicalBranch, contains('context: canonicalStyleContext'));
    expect(canonicalBranch, contains('requestId: requestId'));
  });

  test('backend clients keep endpoint contracts distinct', () {
    final textClient = _section(
      backend,
      'Future<Map<String, dynamic>> sendChatQuery(',
      'Future<Map<String, dynamic>> sendModuleChatQuery(',
    );
    final moduleClient = _section(
      backend,
      'Future<Map<String, dynamic>> sendModuleChat({',
      '/// Fire-and-forget board feedback',
    );

    expect(textClient, contains("Uri.parse('\$baseUrl/api/text')"));
    expect(moduleClient, contains("Uri.parse('\$baseUrl/api/module-chat')"));
    expect(moduleClient, contains("'history': historyForRequest"));
    expect(moduleClient, contains("'context': moduleContext"));
  });
}
