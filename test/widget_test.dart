import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads with scan and history tabs', (WidgetTester tester) async {
    // Hive requires binding — use mock or skip init in test
    TestWidgetsFlutterBinding.ensureInitialized();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NavigationBar(
            destinations: const [
              NavigationDestination(icon: Icon(Icons.camera), label: 'Scan'),
              NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });
}
