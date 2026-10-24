import 'dart:async';
import 'dart:convert';

import 'package:eterlotto/l10n/generated/app_localizations.dart';
import 'package:eterlotto/services/ad_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response statusResponse({bool unlocked = false}) => http.Response(
  jsonEncode({
    'videos_required': 7,
    'videos_completed': 1,
    'passes_available': 0,
    'feature_unlocks': unlocked
        ? {
            'statistics': DateTime.now()
                .add(const Duration(minutes: 30))
                .toIso8601String(),
          }
        : {},
  }),
  200,
);

Future<BuildContext> mountHost(WidgetTester tester) async {
  late BuildContext host;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          host = context;
          return const Scaffold(body: Text('Inicio'));
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return host;
}

Future<void> openGate(
  BuildContext context,
  MockClient client,
  VoidCallback granted,
) => http.runWithClient(
  () => AdService.instance.showRewardedFeatureGate(
    context: context,
    isPremium: false,
    featureTitle: 'Estadísticas',
    featureActionDescription: 'Consulta estadísticas.',
    featureKey: 'statistics',
    onRewardGranted: granted,
  ),
  () => client,
);

Future<void> cleanup(
  WidgetTester tester,
  Completer<http.Response> server,
) async {
  if (!server.isCompleted) server.complete(statusResponse());
  await tester.pumpAndSettle();
  if (find.text('Cancelar').evaluate().isNotEmpty) {
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  }
  await AdService.instance.clearRewardUser();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'unit-test-token',
    });
    await AdService.instance.clearRewardUser();
  });

  testWidgets(
    'prompt opens while the server is still pending; cancel never starts a video',
    (tester) async {
      final server = Completer<http.Response>();
      final requests = <http.Request>[];
      final client = MockClient((request) {
        requests.add(request);
        return server.future;
      });
      try {
        await http.runWithClient(
          () => AdService.instance.setRewardUser('83'),
          () => client,
        );
        final context = await mountHost(tester);
        final gate = openGate(
          context,
          client,
          () => fail('No reward verified'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(server.isCompleted, isFalse);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Ver Video'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        await gate;
        expect(requests, isNotEmpty);
        expect(
          requests.every(
            (request) =>
                request.method == 'GET' &&
                request.url.path == '/rewards/status',
          ),
          isTrue,
        );
      } finally {
        await cleanup(tester, server);
      }
    },
  );

  testWidgets(
    'a server-confirmed unlock dismisses the prompt and opens the function once',
    (tester) async {
      final server = Completer<http.Response>();
      final client = MockClient((_) => server.future);
      var grants = 0;
      try {
        await http.runWithClient(
          () => AdService.instance.setRewardUser('83'),
          () => client,
        );
        final context = await mountHost(tester);
        final gate = openGate(context, client, () => grants++);
        await tester.pump();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(grants, 0);
        server.complete(statusResponse(unlocked: true));
        await tester.pumpAndSettle();
        expect(AdService.instance.isFeatureUnlocked('statistics'), isTrue);
        expect(find.byType(AlertDialog), findsNothing);
        expect(grants, 1);
        await gate;
      } finally {
        await cleanup(tester, server);
      }
    },
  );

  testWidgets(
    'a cached valid unlock opens immediately despite a slow refresh',
    (tester) async {
      final server = Completer<http.Response>();
      var slow = false;
      final client = MockClient(
        (_) =>
            slow ? server.future : Future.value(statusResponse(unlocked: true)),
      );
      var grants = 0;
      try {
        await http.runWithClient(() async {
          await AdService.instance.setRewardUser('83');
          await AdService.instance.refreshBackendRewardStatus(force: true);
        }, () => client);
        slow = true;
        final refresh = http.runWithClient(
          () => AdService.instance.refreshBackendRewardStatus(force: true),
          () => client,
        );
        final context = await mountHost(tester);
        await openGate(context, client, () => grants++);
        await tester.pump();
        expect(server.isCompleted, isFalse);
        expect(grants, 1);
        expect(find.byType(AlertDialog), findsNothing);
        server.complete(statusResponse(unlocked: true));
        await tester.pumpAndSettle();
        await refresh;
      } finally {
        await cleanup(tester, server);
      }
    },
  );

  testWidgets(
    'changing account closes the prompt and discards the old response',
    (tester) async {
      final server = Completer<http.Response>();
      final client = MockClient((_) => server.future);
      var grants = 0;
      try {
        await http.runWithClient(
          () => AdService.instance.setRewardUser('83'),
          () => client,
        );
        final context = await mountHost(tester);
        final gate = openGate(context, client, () => grants++);
        await tester.pump();
        expect(find.byType(AlertDialog), findsOneWidget);
        await AdService.instance.clearRewardUser();
        server.complete(statusResponse(unlocked: true));
        await tester.pumpAndSettle();
        await gate;
        expect(grants, 0);
        expect(find.byType(AlertDialog), findsNothing);
        expect(AdService.instance.backendRewardStatus, isNull);
      } finally {
        await cleanup(tester, server);
      }
    },
  );
}
