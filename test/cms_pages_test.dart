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
import 'package:ssiteapp/services/member_profile.dart';

CmsApi testApi({bool workspace = false, List<String>? queries}) => CmsApi(
  client: MockClient((request) async {
    final rpc = jsonDecode(request.body) as Map;
    final path = '/${rpc['route']}';
    final params = rpc['params'] as Map;
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
    final discoverType = params['type'];
    if (path.endsWith('/discover') && discoverType == 'all') {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 10,
              'title': 'Newest CMS activity',
              'description': 'An activity from the CMS',
              'created_at': '2026-11-19T12:00:00+08:00',
              'module': 'activities',
            },
            {
              'id': 9,
              'title': 'Older CMS article',
              'description': 'An article from the CMS',
              'created_at': '2026-11-18T12:00:00+08:00',
              'module': 'articles',
            },
          ],
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
    final page = int.tryParse(params['page'] ?? '1') ?? 1;
    final module = discoverType ?? path.split('/').last;
    final query = params['q'];
    if (query != null) queries?.add(query);
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
  testWidgets('search suggests a title and submits it when selected', (
    tester,
  ) async {
    final queries = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CmsPage(
            kind: 'documents',
            onSelect: (_) {},
            api: testApi(queries: queries),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final search = find.byType(TextField);
    final listing = find.text('Official documents');
    final listingPosition = tester.getTopLeft(listing);
    await tester.enterText(search, 'cMs p');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(queries, ['cMs p']);
    final suggestion = find.widgetWithText(ListTile, 'documents CMS post 1');
    expect(suggestion, findsOneWidget);
    expect(tester.getTopLeft(listing), listingPosition);
    await tester.tap(suggestion);
    await tester.pumpAndSettle();
    expect(queries, ['cMs p', 'documents CMS post 1']);
    expect(suggestion, findsNothing);
  });

  testWidgets('full articles render the CMS rich body and provide sharing', (
    tester,
  ) async {
    const post = CmsPost(
      id: 1,
      title: 'Formatted',
      description: 'Plain excerpt',
      contentHtml:
          '<h2>Section heading</h2><p><strong>Bold body</strong></p><ul><li>List entry</li></ul><p><a href="https://example.com">Read source</a></p>',
      url: 'https://cms.example/articles/1',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: CmsPostCard(post: post, full: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Plain excerpt'), findsNothing);
    expect(
      find.textContaining('Section heading', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('Bold body', findRichText: true), findsWidgets);
    expect(find.textContaining('List entry', findRichText: true), findsWidgets);
    expect(
      find.textContaining('Read source', findRichText: true),
      findsWidgets,
    );
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account shows the member identity on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MainScreen(
          onSignOut: () => signedOut = true,
          api: testApi(workspace: true),
          profile: const MemberProfile(
            name: 'Ari Reyes',
            email: 'ari@mcc.edu.ph',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Browse posts'), findsOneWidget);
    expect(find.text('Workspace'), findsNothing);
    expect(find.byTooltip('Workspace'), findsNothing);
    expect(find.text('AR'), findsOneWidget);
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    expect(find.text('Ari Reyes'), findsOneWidget);
    expect(find.text('ari@mcc.edu.ph'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });

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
      expect(find.text('Latest story'), findsOneWidget);
      expect(find.text('Newest CMS activity'), findsOneWidget);
      expect(find.text('Older CMS article'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in ['Transparency', 'Documents', 'About us', 'Home']) {
        await tester.tap(
          find.descendant(
            of: find.byType(CmsNavigation),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('landscape tabs leave the feed room when the keyboard opens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(667, 375);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MainScreen(onSignOut: () {}, api: testApi()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CmsNavigation)).height, 60);
    await tester.tap(find.text('Discover'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    expect(find.byType(CmsNavigation), findsNothing);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
