import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ssiteapp/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const appLinksChannel = MethodChannel('com.llfbandit.app_links/events');

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appLinksChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appLinksChannel, null);
  });

  testWidgets('Shows Microsoft sign-in when no session is saved', (tester) async {
    await tester.pumpWidget(const SSITEApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to SSITE'), findsOneWidget);
    expect(find.text('Continue with Microsoft'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
