import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/theme/accent_palette.dart';
import 'package:myapp/theme/base_theme.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_unified_outfit_grid.dart';

const _accent = AccentPalette(
  primary: Color(0xFF6B91FF),
  secondary: Color(0xFF8D7DFF),
  tertiary: Color(0xFF04D7C8),
);

void main() {
  testWidgets('same five-item fixture always has identical grid geometry', (
    tester,
  ) async {
    final geometries = <List<Rect>>[];
    for (final surface in ['normal-style', 'style-this', 'daily-wear']) {
      await _pumpGrid(tester, width: 390, items: _items(5, source: surface));
      geometries.add([
        for (var i = 0; i < 5; i++)
          tester.getRect(find.byKey(ValueKey('item-$i'))),
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(geometries[1], geometries[0]);
    expect(geometries[2], geometries[0]);
  });

  testWidgets('3-6 items remain responsive at supported phone widths', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 384.0, 390.0, 430.0]) {
      for (final count in [3, 4, 5, 6]) {
        await _pumpGrid(tester, width: width, items: _items(count));
        final gridRect = tester.getRect(find.byType(AhviUnifiedOutfitGrid));
        expect(gridRect.height, greaterThan(100));
        expect(gridRect.height, lessThan(500));
        for (var i = 0; i < count; i++) {
          final itemRect = tester.getRect(find.byKey(ValueKey('item-$i')));
          expect(gridRect.inflate(0.1).contains(itemRect.topLeft), isTrue);
          expect(gridRect.inflate(0.1).contains(itemRect.bottomRight), isTrue);
          expect(itemRect.shortestSide, greaterThan(50));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('anchor remains visible and locked', (tester) async {
    await _pumpGrid(
      tester,
      width: 390,
      items: [
        ..._items(1).map(
          (item) => AhviUnifiedOutfitGridItem(
            id: item.id,
            name: item.name,
            category: item.category,
            resolvedImageUrl: item.resolvedImageUrl,
            isAnchor: true,
            isLocked: true,
          ),
        ),
        ..._items(4).skip(1),
      ],
      onToggleLock: (_) {},
    );
    expect(find.byKey(const ValueKey('item-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('lock-item-0')), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
  });

  testWidgets('delayed and broken images retain individual slots', (
    tester,
  ) async {
    final delayed = Completer<ImageInfo>();
    final provider = _ControlledImageProvider(delayed.future);
    await _pumpGrid(
      tester,
      width: 390,
      items: _items(3),
      imageProvider: provider,
    );
    final before = tester.getRect(find.byKey(const ValueKey('item-0')));
    expect(before.size, isNot(Size.zero));
    expect(
      find.byKey(const ValueKey('unified-grid-image-loading')),
      findsNWidgets(3),
    );

    delayed.complete(ImageInfo(image: await _testImage()));
    await tester.pump();
    expect(tester.getRect(find.byKey(const ValueKey('item-0'))), before);
  });
}

List<AhviUnifiedOutfitGridItem> _items(
  int count, {
  String source = 'fixture',
}) => [
  for (var i = 0; i < count; i++)
    AhviUnifiedOutfitGridItem(
      id: 'item-$i',
      name: 'Item $i',
      category: i == 0 ? 'top' : 'accessory',
      resolvedImageUrl: 'https://example.test/$source-$i.png',
    ),
];

Future<void> _pumpGrid(
  WidgetTester tester, {
  required double width,
  required List<AhviUnifiedOutfitGridItem> items,
  ValueChanged<String>? onToggleLock,
  ImageProvider? imageProvider,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: BaseTheme.light.copyWith(
        extensions: [AppThemeTokens.light(_accent)],
      ),
      home: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AhviUnifiedOutfitGrid(
                items: items,
                onToggleLock: onToggleLock,
                imageProviderBuilder: imageProvider == null
                    ? null
                    : (_) => imageProvider,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

class _ControlledImageProvider extends ImageProvider<_ControlledImageProvider> {
  final Future<ImageInfo> image;
  const _ControlledImageProvider(this.image);
  @override
  Future<_ControlledImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) async => this;
  @override
  ImageStreamCompleter loadImage(
    _ControlledImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(image);
}

Future<ui.Image> _testImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = Colors.white,
  );
  return recorder.endRecording().toImage(1, 1);
}
