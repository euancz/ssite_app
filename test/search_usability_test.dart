import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssiteapp/screens/main_screen.dart';
import 'package:ssiteapp/services/cms_api.dart';

void main() {
  testWidgets(
    'pagination keeps submitted search and clearing restores all results',
    (tester) async {
      final requests = <Uri>[];
      final api = CmsApi(
        client: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': requests.length,
                  'title': 'Result ${requests.length}',
                  'module': 'documents',
                },
              ],
              'meta': {
                'current_page': int.parse(
                  request.url.queryParameters['page'] ?? '1',
                ),
                'last_page': 2,
                'total': 2,
              },
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CmsPage(kind: 'documents', api: api, onSelect: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'budget');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      final submitted = requests.last;
      await tester.enterText(find.byType(TextField), 'unsubmitted');
      await tester.ensureVisible(find.text('Load more'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(
        requests.last.queryParameters['q'],
        submitted.queryParameters['q'],
      );
      expect(requests.last.queryParameters['q'], 'budget');
      expect(requests.last.queryParameters['page'], '2');
      await tester.ensureVisible(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['q'] ?? '', isEmpty);
      expect(find.byTooltip('Clear search'), findsNothing);
      expect(find.text('Clear search and filters'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
