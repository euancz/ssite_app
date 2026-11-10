import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssiteapp/app_theme.dart';
import 'package:ssiteapp/screens/main_screen.dart';
import 'package:ssiteapp/widgets/cms_navigation.dart';
import 'package:ssiteapp/services/cms_api.dart';

CmsApi testApi({bool workspace = false}) => CmsApi(
  client: MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/auth/me')) {
      return http.Response(
        jsonEncode({
          'user': {'name': 'CMS User', 'can_access_workspace': workspace},
        }),
        200,
      );
    }
    if (path.endsWith('/home')) {
      return http.Response(
        jsonEncode({
          'data': {
            'articles': [],
            'activities': [],
            'achievements': [],
            'officers': [],
          },
        }),
        200,
      );
    }
    if (path.endsWith('/about')) {
      return http.Response(
        jsonEncode({
          'data': {'academic_year': '2026-2027', 'officers': [], 'history': {}},
        }),
        200,
      );
    }
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final module = path.split('/').last;
    return http.Response(
      jsonEncode({
        'data': [
          {
            'id': page,
            'title': '$module CMS post $page',
            'description': 'A published post read from the CMS.',
            'module': module,
            'author': 'CMS Author',
            if (module == 'documents')
              'file_url': 'http://localhost/api/mobile/v1/files/documents/1',
          },
        ],
        'meta': {'current_page': page, 'last_page': 2, 'total': 2},
      }),
      200,
    );
  }),
);

void main() {
  for (final allowed in [false, true]) {
    testWidgets('workspace entry follows server permission: $allowed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MainScreen(
            onSignOut: () {},
            api: testApi(workspace: allowed),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Workspace'),
        allowed ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.byTooltip('Account options'));
      await tester.pumpAndSettle();
      expect(find.text('Workspace'), allowed ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('resizing preserves selected tab and all destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MainScreen(onSignOut: () {}, api: testApi()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    expect(find.text('documents CMS post 1'), findsOneWidget);
    tester.view.physicalSize = const Size(1000, 900);
    await tester.pumpAndSettle();
    expect(find.text('documents CMS post 1'), findsOneWidget);
    expect(find.text('Transparency'), findsOneWidget);
    tester.view.physicalSize = const Size(320, 900);
    await tester.pumpAndSettle();
    expect(find.text('documents CMS post 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('native CMS navigation fits width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MainScreen(onSignOut: () {}, api: testApi()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Transparency'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('About us'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      expect(find.text('articles CMS post 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in ['Transparency', 'Documents', 'About us', 'Home']) {
        await tester.tap(find.descendant(
          of: find.byType(CmsNavigation), matching: find.text(label),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('feed switches modules and loads the next CMS page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: CmsPage(kind: 'discover', onSelect: (_) {}, api: testApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Activities'));
    await tester.pumpAndSettle();
    expect(find.text('activities CMS post 1'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('activities CMS post 2'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('activities CMS post 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('documents provide a native PDF action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: CmsPage(kind: 'documents', onSelect: (_) {}, api: testApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('documents CMS post 1'), findsOneWidget);
    await tester.ensureVisible(find.text('View PDF'));
    expect(find.text('View PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all five CMS hero assets decode at their native ratio', (
    tester,
  ) async {
    for (final name in [
      'home',
      'discover',
      'documents',
      'transparency',
      'about',
    ]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 320,
              child: SvgPicture.asset('assets/heroes/hero-$name.svg'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
