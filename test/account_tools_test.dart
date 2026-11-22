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
          final end = req.url.path;
          final data = req.method == 'POST'
              ? () {
                  writes.add(jsonDecode(req.body));
                  return {'back': 'workspace'};
                }()
              : end.endsWith('/workspace')
              ? {
                  'title': 'Workspace',
                  'items': [
                    {'title': 'Manage sponsors', 'path': 'sponsors'},
                  ],
                }
              : {
                  'title': 'Sponsors',
                  'items': [
                    {
                      'title': 'Save',
                      'submit': 'sponsors/new',
                      'fields': [
                        {'key': 'name', 'value': '', 'type': 'text'},
                      ],
                    },
                  ],
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
      await tester.tap(find.text('Manage sponsors'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Partner');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(writes.single, {'name': 'Partner'});
      expect(find.text('Workspace'), findsOneWidget);
    },
  );
}
