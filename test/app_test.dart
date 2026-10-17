import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scandaid/main.dart';
import 'package:scandaid/screens/scan_editor.dart';
import 'package:scandaid/services/scan_repository.dart';
import 'package:scandaid/widgets/scan_photo.dart';
import 'support.dart';

void main() {
  desktopTest(
    'overview, history, settings and local storage load on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ScanRepository(storage: MemoryStorage());
      await tester.pumpWidget(ScandAidApp(repository: repo));
      await tester.pumpAndSettle();
      expect(find.text('A clearer picture\nof your progress.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Your photo journal'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Made to stay private'), findsOneWidget);
      expect(
        find.text('Send photos to this server for analysis'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  desktopTest('editor validates name and supports marking and undoing points', (
    tester,
  ) async {
    final repo = ScanRepository(storage: MemoryStorage());
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ScanEditor(photo: testPhoto(), repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Measure outline'));
    await tester.tap(find.text('Measure outline'));
    await tester.pumpAndSettle();
    expect(
      find.text('Give this wound a name to group follow-ups.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), 'Left knee');
    await tester.ensureVisible(find.byType(ScanPhoto));
    await tester.pumpAndSettle();
    final gesture = find
        .descendant(
          of: find.byType(ScanPhoto),
          matching: find.byType(GestureDetector),
        )
        .first;
    final rect = tester.getRect(gesture);
    await tester.tapAt(
      rect.topLeft + Offset(rect.width * .25, rect.height * .25),
    );
    await tester.pump();
    await tester.tapAt(
      rect.topLeft + Offset(rect.width * .75, rect.height * .25),
    );
    await tester.pump();
    await tester.tapAt(
      rect.topLeft + Offset(rect.width * .75, rect.height * .75),
    );
    await tester.pump();
    expect(
      tester.widget<ScanPhoto>(find.byType(ScanPhoto)).points,
      hasLength(3),
    );
    await tester.tap(find.text('Undo point'));
    await tester.pump();
    expect(
      tester.widget<ScanPhoto>(find.byType(ScanPhoto)).points,
      hasLength(2),
    );
    expect(tester.takeException(), isNull);
  });
  desktopTest('overview visual review at desktop size', (tester) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (const bool.fromEnvironment('VISUAL_QA')) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(
            File(
              'C:/Windows/Fonts/segoeui.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          );
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
    }
    await tester.pumpWidget(
      ScandAidApp(repository: ScanRepository(storage: MemoryStorage())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Generated on demand for visual QA; no platform-dependent golden in version control.
    if (const bool.fromEnvironment('VISUAL_QA')) {
      await expectLater(
        find.byType(ScandAidApp),
        matchesGoldenFile('../.tools/qa/overview.png'),
      );
    }
  });
  desktopTest('a reviewed manual scan can be measured and saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = ScanRepository(storage: MemoryStorage());
    await tester.pumpWidget(ScandAidApp(repository: repo));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push<void>(
          MaterialPageRoute(
            builder: (_) => ScanEditor(photo: testPhoto(), repository: repo),
          ),
        );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Left knee');
    final gesture = find
        .descendant(
          of: find.byType(ScanPhoto),
          matching: find.byType(GestureDetector),
        )
        .first;
    final rect = tester.getRect(gesture);
    for (final point in rectangle) {
      await tester.tapAt(
        rect.topLeft + Offset(rect.width * point.dx, rect.height * point.dy),
      );
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Measure outline'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Measure outline'));
      // Exercise the real worker isolate while waiting for its state update.
      for (var attempt = 0; attempt < 100; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.text('2000 px²').evaluate().isNotEmpty) break;
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('2000 px²'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save reviewed entry'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ScanEditor),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Save reviewed entry'));
    await tester.pumpAndSettle();
    expect(repo.scans.single.woundName, 'Left knee');
    expect(repo.scans.single.areaPixels, 2000);
    expect(repo.scans.single.areaCm2, isNull);
    expect(repo.scans.single.classification.abstained, isTrue);
    expect(find.byType(ScanEditor), findsNothing);
    expect(find.text('A clearer picture\nof your progress.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void desktopTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(
    description,
    body,
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
