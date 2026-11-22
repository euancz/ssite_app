import 'package:flutter/material.dart';
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
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() => client.dispose());

  testWidgets('Shows Microsoft sign-in when no session is saved', (
    tester,
  ) async {
    await tester.pumpWidget(SSITEApp(client: client));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to SSITE'), findsOneWidget);
    expect(find.text('Continue with Microsoft'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpAndSettle();
  });
}
