import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssiteapp/screens/account_tools.dart';
import 'package:ssiteapp/services/cms_api.dart';

void main() {
  testWidgets(
    'notification actions stay with their record and deletion can be canceled',
    (tester) async {
      final writes = <String>[];
      final api = CmsApi(
        client: MockClient((req) async {
          final rpc = jsonDecode(req.body);
          if (req.url.path.endsWith('ssite_app_write')) {
            writes.add(rpc['route']);
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode({
              'rows': [
                {
                  'id': 'alert1',
                  'read_at': writes.isEmpty ? null : 'read',
                  'data': {'message': 'New document', 'title': 'Minutes'},
                },
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AccountTools(
            api: api,
            path: 'notifications',
            onUnauthorized: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete notification'), findsNothing);
      await tester.tap(find.byTooltip('Notification actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete notification'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(find.byTooltip('Notification actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark read'));
      await tester.pumpAndSettle();
      expect(writes, ['tools/notifications/alert1/read']);
      expect(find.text('Mark all as read'), findsNothing);
    },
  );

  testWidgets(
    'narrow workspace keeps filters and bulk actions behind controls',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final api = CmsApi(
        client: MockClient((req) async {
          final rpc = jsonDecode(req.body);
          final data = rpc['route'] == 'tools/workspace'
              ? {
                  'modules': ['articles'],
                  'stats': [
                    {
                      'module': 'articles',
                      'n': 2,
                      'approval': 'pending',
                      'status': 'active',
                    },
                  ],
                  'president': true,
                  'members': {'student': 4},
                  'leaders': [
                    {'name': 'Ari', 'role': 'President'},
                  ],
                }
              : {
                  'rows': [
                    {
                      'id': 1,
                      'title': 'Student stories',
                      'approval_status': 'pending',
                      'content_status': 'active',
                    },
                  ],
                  'drafts': [],
                  'president': true,
                };
          return http.Response(jsonEncode(data), 200);
        }),
      );
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
      expect(find.text('2 pending'), findsOneWidget);
      expect(find.text('Ari'), findsNothing);
      await tester.tap(find.text('Articles'));
      await tester.pumpAndSettle();
      expect(find.text('Student stories'), findsOneWidget);
      expect(find.text('Archive selected posts'), findsNothing);
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('rejected').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.text('Student stories'), findsNothing);
      expect(find.text('Create post'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
