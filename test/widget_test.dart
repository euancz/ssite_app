import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ssiteapp/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient(
      'https://app.example',
      'public-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
  });
  tearDown(() => client.dispose());

  testWidgets('landing sign-in requests interactive Microsoft authentication', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger = tester.binding.defaultBinaryMessenger;
    Uri? opened;
    messenger.setMockMethodCallHandler(channel, (call) async {
      opened = Uri.parse(call.arguments['url'] as String);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(SSITEApp(client: client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Microsoft'));
    await tester.pumpAndSettle();
    expect(opened?.queryParameters['provider'], 'azure');
    expect(opened?.queryParameters['prompt'], 'login');
    expect(opened?.queryParameters['redirect_to'], 'ssiteapp://auth/callback');
  });

  testWidgets('Shows Microsoft sign-in when no session is saved', (
    tester,
  ) async {
    await tester.pumpWidget(SSITEApp(client: client));
    await tester.pumpAndSettle();

    expect(find.text('Campus life.\nCloser to you.'), findsOneWidget);
    expect(find.text('Sign in with Microsoft'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpAndSettle();
  });
}
