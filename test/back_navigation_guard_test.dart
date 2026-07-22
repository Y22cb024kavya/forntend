import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/navigation/ahvi_back_navigation.dart';

void main() {
  testWidgets('one Android back invokes the shell handler exactly once', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(
      _app(onBack: () => backCount++, child: const Text('Wardrobe')),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(backCount, 1);
  });

  testWidgets('two rapid Android backs do not re-enter the shell handler', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(
      _app(onBack: () => backCount++, child: const Text('Wardrobe')),
    );

    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();

    expect(backCount, 1);
    await tester.pump();
  });

  testWidgets('idle nested Home scope does not re-enter Navigator pop', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(
      _app(
        onBack: () => backCount++,
        child: AhviTransientBackScope(
          hasTransientUi: false,
          onDismissTransientUi: () {},
          child: const Text('Home'),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(backCount, 1);
  });

  testWidgets('idle Home requests system exit when shell has no history', (
    tester,
  ) async {
    var exitCount = 0;
    await tester.pumpWidget(
      _appWithHandler(
        onBack: () => false,
        onExitRequested: () => exitCount++,
        child: const Text('Home'),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(exitCount, 1);
  });

  testWidgets('Home transient UI closes without switching the shell tab', (
    tester,
  ) async {
    var backCount = 0;
    var dismissCount = 0;
    await tester.pumpWidget(
      _app(
        onBack: () => backCount++,
        child: AhviTransientBackScope(
          hasTransientUi: true,
          onDismissTransientUi: () => dismissCount++,
          child: const Text('Home overlay'),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(dismissCount, 1);
    expect(backCount, 0);
  });

  testWidgets('back with keyboard focus dismisses focus without navigation', (
    tester,
  ) async {
    var backCount = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      _app(
        onBack: () => backCount++,
        child: TextField(focusNode: focusNode, autofocus: true),
      ),
    );
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(backCount, 0);
  });

  testWidgets('keyboard back does not also dismiss Home transient UI', (
    tester,
  ) async {
    var backCount = 0;
    var dismissCount = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      _app(
        onBack: () => backCount++,
        child: AhviTransientBackScope(
          hasTransientUi: true,
          onDismissTransientUi: () => dismissCount++,
          child: TextField(focusNode: focusNode, autofocus: true),
        ),
      ),
    );
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(dismissCount, 0);
    expect(backCount, 0);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(dismissCount, 1);
  });

  testWidgets('back with an item modal open closes only the modal', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(
      _app(
        onBack: () => backCount++,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(
                content: Text('Item details'),
              ),
            ),
            child: const Text('Open item'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open item'));
    await tester.pumpAndSettle();
    expect(find.text('Item details'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Item details'), findsNothing);
    expect(backCount, 0);
  });

  testWidgets('back after modal close returns from Wardrobe once', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(
      _app(
        onBack: () => backCount++,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(
                content: Text('Item details'),
              ),
            ),
            child: const Text('Open item'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open item'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(backCount, 1);
  });

  testWidgets('pending back completion is safe after scope disposal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(onBack: () {}, child: const Text('Wardrobe')),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _app({required VoidCallback onBack, required Widget child}) {
  return _appWithHandler(
    onBack: () {
      onBack();
      return true;
    },
    child: child,
  );
}

Widget _appWithHandler({
  required bool Function() onBack,
  required Widget child,
  VoidCallback? onExitRequested,
}) {
  return MaterialApp(
    home: AhviShellBackScope(
      onBack: onBack,
      onExitRequested: onExitRequested,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}
