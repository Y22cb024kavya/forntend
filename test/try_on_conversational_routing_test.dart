import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/appwrite_service.dart';
import 'package:myapp/services/backend_service.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/base_theme.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';
import 'package:myapp/widgets/try_on_coming_soon.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
      envString:
          'EXPO_PUBLIC_APPWRITE_ENDPOINT=https://appwrite.test\n'
          'EXPO_PUBLIC_APPWRITE_PROJECT_ID=project\n'
          'EXPO_PUBLIC_APPWRITE_DATABASE_ID=database\n'
          'EXPO_PUBLIC_BACKEND_API_URL=https://backend.test/',
      isOptional: true,
    );
  });

  for (final prompt in const [
    'build me an outfit',
    'build an outfit for tomorrow',
    'put together an outfit for dinner',
    'build an outfit around this shirt',
    'What should I wear today?',
    'change the shoes',
    'show brunch inspiration',
  ]) {
    testWidgets('typed "$prompt" uses normal Style chat', (tester) async {
      final backend = _RecordingBackend();
      await _pumpChat(tester, backend, prompt);

      final requests = prompt == 'change the shoes'
          ? backend.textRequests
          : backend.moduleRequests;
      expect(requests, contains(prompt));
      expect(find.byType(TryOnComingSoonDialog), findsNothing);
      expect(find.text('Coming soon'), findsNothing);
    });
  }

  testWidgets('typed Style This stays on the specialized Style path', (
    tester,
  ) async {
    final backend = _RecordingBackend();
    await _pumpChat(tester, backend, 'Style this shirt');

    expect(backend.textRequests, contains('Style this shirt'));
    expect(backend.moduleRequests, isEmpty);
    expect(find.byType(TryOnComingSoonDialog), findsNothing);
  });

  testWidgets('item-referential outfit text preserves conversational context', (
    tester,
  ) async {
    final backend = _RecordingBackend();
    await _pumpChat(
      tester,
      backend,
      'build an outfit around this shirt',
      contextData: const {'anchor_item_id': 'shirt-1'},
    );

    expect(
      backend.moduleRequests,
      contains('build an outfit around this shirt'),
    );
    expect(backend.contexts.single['anchor_item_id'], 'shirt-1');
  });

  testWidgets('tomorrow outfit text preserves occasion context', (
    tester,
  ) async {
    final backend = _RecordingBackend();
    await _pumpChat(
      tester,
      backend,
      'build an outfit for tomorrow',
      contextData: const {'occasion': 'tomorrow'},
    );

    expect(backend.moduleRequests, contains('build an outfit for tomorrow'));
    expect(backend.contexts.single['occasion'], 'tomorrow');
  });
}

Future<void> _pumpChat(
  WidgetTester tester,
  _RecordingBackend backend,
  String prompt, {
  Map<String, dynamic> contextData = const {},
}) async {
  await tester.pumpWidget(
    Provider<BackendService>.value(
      value: backend,
      child: MaterialApp(
        theme: BaseTheme.light.copyWith(
          extensions: [AppThemeTokens.light(_accent)],
        ),
        home: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-chat'),
            onPressed: () => showAhviStylistChatSheet(
              context,
              moduleContext: 'style',
              contextData: contextData,
              initialPrompt: prompt,
            ),
            child: const Text('Open chat'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-chat')));
  await tester.pumpAndSettle();
}

class _RecordingBackend extends BackendService {
  final List<String> moduleRequests = [];
  final List<String> textRequests = [];
  final List<Map<String, dynamic>> contexts = [];

  _RecordingBackend() : super(appwriteService: AppwriteService());

  @override
  Future<Map<String, dynamic>> sendModuleChat({
    required String domain,
    required String message,
    Map<String, dynamic>? context,
    List<Map<String, String>> chatHistory = const [],
    Map<String, dynamic>? userProfile,
    Map<String, dynamic>? styleState,
    String? requestId,
  }) async {
    moduleRequests.add(message);
    contexts.add(Map<String, dynamic>.from(context ?? const {}));
    return _conversationResponse();
  }

  @override
  Future<Map<String, dynamic>> sendChatQuery(
    String query,
    String userId,
    List<Map<String, String>> chatHistory,
    String currentMemory, {
    bool isRetry = false,
    List<Map<String, dynamic>>? fetchedWardrobe,
    String moduleContext = 'chat',
    Map<String, dynamic>? userProfile,
    String? styleAction,
    List<String> excludeStyleSignatures = const [],
    int? requestedBoardCount,
    String? action,
    String? clarification,
    String? sessionId,
    String? previousPrompt,
    String? resolvedPrompt,
    String? currentLookId,
    Map<String, dynamic>? styleContext,
    Map<String, dynamic>? styleState,
    Map<String, dynamic>? lastStyleContext,
    bool showClosestOption = false,
    bool allowClosestOption = false,
    bool closest = false,
    bool useWardrobe = false,
    bool wardrobeFirst = false,
    String? assetPolicy,
    bool allowGenericAssetsInMainBoard = true,
    String? requestId,
  }) async {
    textRequests.add(query);
    return _conversationResponse();
  }

  Map<String, dynamic> _conversationResponse() => {
    'type': 'conversation',
    'route': 'conversation',
    'message': {'role': 'assistant', 'content': 'Style response'},
    'message_text': 'Style response',
    'chips': const [],
  };
}
