import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_localizations.dart';
import 'package:myapp/home.dart';
import 'package:myapp/home_card_summary_provider.dart';
import 'package:myapp/models/calendar_actions.dart';
import 'package:myapp/profile.dart' as profile;
import 'package:myapp/services/appwrite_service.dart';
import 'package:myapp/services/backend_service.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/base_theme.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accent = AccentPalette(
  primary: Color(0xFFFF8EC7),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('Prepare CTA is visible and clearly exposed as a button', (
    tester,
  ) async {
    await _pumpHome(tester, _HomePrepareBackend(), _RecordingObserver());

    final cta = find.byKey(const ValueKey('home-prepare-cta'));
    expect(cta, findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.startsWith('Prepare and plan') == true,
      ),
      findsOneWidget,
    );
    await _drainBackground(tester);
  });

  testWidgets(
    'one Prepare tap opens planner Tomorrow Prep without style or garment anchors',
    (tester) async {
      final backend = _HomePrepareBackend();
      final observer = _RecordingObserver();
      SharedPreferences.setMockInitialValues({
        'ahvi_chat_history_style': jsonEncode([
          {
            'id': 'stale-style-session',
            'title': 'Stale Style board',
            'createdAt': '2026-08-01T12:00:00.000',
            'messages': [
              {
                'text': 'Stale Style board from a previous conversation',
                'textKey': null,
                'isUser': false,
                'moduleCards': [],
              },
            ],
          },
        ]),
      });
      await _pumpHome(tester, backend, observer);

      final pushesBefore = observer.pushes;
      await tester.tap(find.byKey(const ValueKey('home-prepare-cta')));
      await _waitForChat(tester);

      expect(observer.pushes, pushesBefore + 1);
      final dynamic chat = tester.widget(_chatFinder);
      expect(chat.moduleContext, 'planner');
      expect(chat.isFullScreen, isFalse);
      expect(chat.initialPrompt, 'Prep for tomorrow');
      expect(chat.contextData['source'], 'home_prep_plan_card');
      expect(chat.contextData['surface'], 'home_prepare');
      expect(chat.contextData['calendar_action'], 'calendar_prep_tomorrow');
      expect(chat.contextData['requested_action'], 'calendar_prep_tomorrow');
      expect(chat.contextData['requested_plan_type'], 'tomorrow_prep');
      expect(
        chat.contextData['target_date'],
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
      expect(chat.contextData['calendar_action'], isNot('calendar_plan_day'));
      expect(chat.contextData.containsKey('style_this'), isFalse);
      expect(chat.contextData.containsKey('build_outfit'), isFalse);
      expect(chat.contextData.containsKey('anchor'), isFalse);
      expect(chat.contextData.containsKey('anchor_item_id'), isFalse);
      expect(
        calendarPhraseAction(chat.initialPrompt),
        CalendarQuickAction.prepTomorrow,
      );
      expect(find.text('Build Outfit is coming soon.'), findsNothing);
      expect(find.text('AI Stylist'), findsNothing);
      expect(find.text('Style'), findsNothing);
      expect(find.text('Stale Style board'), findsNothing);
      expect(
        find.text('Stale Style board from a previous conversation'),
        findsNothing,
      );
      await _drainBackground(tester);
    },
  );

  testWidgets('rapid Prepare taps do not duplicate planner sheets', (
    tester,
  ) async {
    final observer = _RecordingObserver();
    await _pumpHome(tester, _HomePrepareBackend(), observer);
    final cta = find.byKey(const ValueKey('home-prepare-cta'));
    final pushesBefore = observer.pushes;

    await tester.tap(cta);
    await tester.tap(cta, warnIfMissed: false);
    await _waitForChat(tester);

    expect(observer.pushes, pushesBefore + 1);
    expect(_chatFinder, findsOneWidget);
    await _drainBackground(tester);
  });

  testWidgets(
    'opening Prepare sends one Tomorrow Prep request but creates no plan automatically',
    (tester) async {
      final backend = _HomePrepareBackend();
      await _pumpHome(tester, backend, _RecordingObserver());
      await tester.tap(find.byKey(const ValueKey('home-prepare-cta')));
      await _waitForChat(tester);
      await _waitForModuleRequest(tester, backend);

      expect(backend.moduleRequests, hasLength(1));
      expect(backend.moduleRequests.single.domain, 'calendar');
      expect(backend.moduleRequests.single.message, 'Prep for tomorrow');
      expect(
        backend.moduleRequests.single.context['calendar_action'],
        'calendar_prep_tomorrow',
      );
      expect(
        backend.moduleRequests.single.context['requested_action'],
        'calendar_prep_tomorrow',
      );
      expect(
        backend.moduleRequests.single.context['requested_plan_type'],
        'tomorrow_prep',
      );
      expect(backend.moduleRequests.single.context['surface'], 'home_prepare');
      expect(backend.moduleRequests.single.context['target_date'], isNotNull);
      expect(
        backend.moduleRequests.single.context['calendar_action'],
        isNot('calendar_plan_day'),
      );
      expect(
        backend.moduleRequests.single.context.containsKey('style_this'),
        isFalse,
      );
      expect(
        backend.moduleRequests.single.context.containsKey('build_outfit'),
        isFalse,
      );
      expect(
        backend.moduleRequests.single.context.containsKey('anchor'),
        isFalse,
      );
      expect(backend.planCreates, 0);
      await _drainBackground(tester);
    },
  );

  testWidgets('Back returns from Prepare to a usable Home', (tester) async {
    final observer = _RecordingObserver();
    await _pumpHome(tester, _HomePrepareBackend(), observer);
    await tester.tap(find.byKey(const ValueKey('home-prepare-cta')));
    await _waitForChat(tester);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 100));
    if (_chatFinder.evaluate().isNotEmpty) {
      await tester.binding.handlePopRoute();
    }
    await tester.pump(const Duration(milliseconds: 700));

    expect(_chatFinder, findsNothing);
    expect(find.byKey(const ValueKey('home-prepare-cta')), findsOneWidget);
    expect(observer.pops, 1);
    expect(tester.takeException(), isNull);
    await _drainBackground(tester);
  });

  testWidgets('closing Prepare while loading is lifecycle safe', (
    tester,
  ) async {
    final backend = _HomePrepareBackend(
      responseDelay: const Duration(seconds: 1),
    );
    final observer = _RecordingObserver();
    await _pumpHome(tester, backend, observer);
    await tester.tap(find.byKey(const ValueKey('home-prepare-cta')));
    await _waitForChat(tester);
    await tester.pump(const Duration(milliseconds: 700));

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 100));
    if (_chatFinder.evaluate().isNotEmpty) {
      await tester.binding.handlePopRoute();
    }
    await tester.pump(const Duration(seconds: 2));

    expect(_chatFinder, findsNothing);
    expect(observer.pops, 1);
    expect(tester.takeException(), isNull);
    await _drainBackground(tester);
  });
}

Finder get _chatFinder => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString().contains('AhviStylistChatSheet'),
);

Future<void> _waitForChat(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (_chatFinder.evaluate().isNotEmpty) return;
  }
  fail('Prepare planner chat did not open');
}

Future<void> _waitForModuleRequest(
  WidgetTester tester,
  _HomePrepareBackend backend,
) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (backend.moduleRequests.isNotEmpty) return;
  }
  fail('Prepare planner request did not start');
}

Future<void> _drainBackground(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 9));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpHome(
  WidgetTester tester,
  _HomePrepareBackend backend,
  NavigatorObserver observer,
) async {
  final appwrite = AppwriteService();
  await tester.binding.setSurfaceSize(const Size(1920, 2700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppwriteService>.value(value: appwrite),
        Provider<BackendService>.value(value: backend),
        ChangeNotifierProvider<HomeCardSummaryProvider>(
          create: (_) => HomeCardSummaryProvider(),
        ),
        ChangeNotifierProvider<profile.ProfileController>(
          create: (_) => profile.ProfileController(),
        ),
      ],
      child: MaterialApp(
        theme: BaseTheme.light.copyWith(
          extensions: [AppThemeTokens.light(_accent)],
        ),
        localizationsDelegates: const [_TestLocalizationsDelegate()],
        supportedLocales: const [Locale('en')],
        navigatorObservers: [observer],
        home: const Screen4(loadContextSignals: false),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

class _RecordingObserver extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
    super.didPop(route, previousRoute);
  }
}

class _TestLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _TestLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_TestLocalizationsDelegate old) => false;
}

class _ModuleRequest {
  const _ModuleRequest({
    required this.domain,
    required this.message,
    required this.context,
  });

  final String domain;
  final String message;
  final Map<String, dynamic> context;
}

class _HomePrepareBackend extends BackendService {
  _HomePrepareBackend({this.responseDelay = Duration.zero})
    : super(appwriteService: AppwriteService());

  final Duration responseDelay;
  final List<_ModuleRequest> moduleRequests = [];
  int planCreates = 0;

  @override
  Future<Map<String, dynamic>> getTodayWorkout({bool forceRefresh = false}) =>
      Future.value(const {});

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
    moduleRequests.add(
      _ModuleRequest(
        domain: domain,
        message: message,
        context: Map<String, dynamic>.from(context ?? const {}),
      ),
    );
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }
    return const {
      'type': 'conversation',
      'route': 'planner',
      'message_text': 'Planner is ready for your day.',
    };
  }
}
