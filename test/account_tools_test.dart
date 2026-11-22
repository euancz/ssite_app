import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssiteapp/screens/account_tools.dart';
import 'package:ssiteapp/services/cms_api.dart';

void main() {
  testWidgets(
    'workspace opens a native form and sends the change to the app service',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final api = CmsApi(
        baseUrl: 'https://app.example/api/mobile/v1',
        client: MockClient((req) async {
          expect(req.url.host, 'app.example');
          expect(req.headers['Authorization'], 'Bearer test');
          final rpc = jsonDecode(req.body);
          if (req.url.path.endsWith('ssite_app_write')) {
            writes.add(Map.from(rpc['body']));
            return http.Response(jsonEncode({'back': 'workspace'}), 200);
          }
          final data = switch (rpc['route']) {
            'tools/workspace' => {
              'role': 'officer',
              'president': true,
              'modules': <String>[],
              'stats': [],
            },
            'tools/sponsors' => {'rows': []},
            _ => {'record': {}},
          };
          return http.Response(jsonEncode(data), 200);
        }),
      )..accessToken = 'test';
      await tester.pumpWidget(
        MaterialApp(
          home: AccountTools(
            api: api,
            path: 'workspace',
            onUnauthorized: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sponsors'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add entry'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Partner');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(writes.single['name'], 'Partner');
      expect(find.text('Workspace'), findsOneWidget);
    },
  );
}
