import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:eterlotto/widgets/premium_crown_badge.dart';
import 'package:eterlotto/widgets/premium_header_background.dart';
import 'package:eterlotto/providers/subscription_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PremiumCrownBadge Tests', () {
    testWidgets('Non-premium user renders only child with no crown', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumCrownBadge(
              isPremium: false,
              child: Text('TestAvatar'),
            ),
          ),
        ),
      );

      expect(find.text('TestAvatar'), findsOneWidget);
      expect(find.byType(FaIcon), findsNothing);
    });

    testWidgets('Premium user renders child and crown icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumCrownBadge(
              isPremium: true,
              child: Text('TestAvatar'),
            ),
          ),
        ),
      );

      expect(find.text('TestAvatar'), findsOneWidget);
      expect(find.byType(FaIcon), findsOneWidget);
    });
  });

  group('PremiumCrownIcon Tests', () {
    testWidgets('Non-premium user renders SizedBox.shrink() with no FaIcon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumCrownIcon(isPremium: false),
          ),
        ),
      );

      expect(find.byType(FaIcon), findsNothing);
    });

    testWidgets('Premium user renders animated crown FaIcon and sparkle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumCrownIcon(isPremium: true, size: 20),
          ),
        ),
      );

      expect(find.byType(FaIcon), findsOneWidget);
      // Avanzar al intervalo del destello (80% - 95% de 7s => aprox 6.0s)
      await tester.pump(const Duration(milliseconds: 6000));
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });
  });

  group('PremiumHeaderBackground Tests', () {
    testWidgets('Renders CustomPaint with golden waves without error', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: PremiumHeaderBackground(height: 200),
            ),
          ),
        ),
      );

      expect(find.byType(PremiumHeaderBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Avanzar animación para verificar estabilidad del ciclo de 7s
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('SubscriptionProvider isPremium getter test', () {
    test('isPremium mirrors isSubscribed initially as false', () {
      final provider = SubscriptionProvider();
      expect(provider.isPremium, equals(false));
      expect(provider.isSubscribed, equals(false));
      provider.dispose();
    });
  });
}
