import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'workspace_screen.dart';
import 'package:pdfrx/pdfrx.dart';

import '../app_theme.dart';
import '../services/cms_api.dart';
import '../widgets/cms_hero.dart';
import '../widgets/cms_navigation.dart';

part 'content/cms_page.dart';
part 'content/post_cards.dart';
part 'content/about_content.dart';
part 'content/document_content.dart';
part 'content/sponsor_card.dart';
part 'content/content_widgets.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.onSignOut, this.api});
  final VoidCallback onSignOut;
  final CmsApi? api;
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  bool _canAccessWorkspace = false;
  bool _openingWorkspace = false;
  late final _api = widget.api ?? CmsApi.instance;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    try {
      final user = await _api.currentUser();
      if (mounted) {
        setState(
          () => _canAccessWorkspace = user['can_access_workspace'] == true,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _canAccessWorkspace = false);
    }
  }

  Future<void> _openAccount(String destination) async {
    try {
      final uri = await _api.openAccountSession(destination);
      if (!mounted) return;
      if (!kIsWeb &&
          [
            TargetPlatform.android,
            TargetPlatform.iOS,
            TargetPlatform.macOS,
          ].contains(defaultTargetPlatform)) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => WorkspaceScreen(uri: uri)),
        );
      } else if (!await launchUrl(uri, webOnlyWindowName: '_self')) {
        throw StateError('Could not open page');
      }
      await _loadAccount();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open page. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openWorkspace() async {
    if (_openingWorkspace) return;
    setState(() => _openingWorkspace = true);
    try {
      final uri = await _api.openWorkspaceSession();
      if (!mounted) return;
      if (!kIsWeb &&
          [
            TargetPlatform.android,
            TargetPlatform.iOS,
            TargetPlatform.macOS,
          ].contains(defaultTargetPlatform)) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => WorkspaceScreen(uri: uri)),
        );
      } else {
        if (!await launchUrl(uri, webOnlyWindowName: '_self')) {
          throw StateError('Could not open workspace');
        }
      }
    } catch (_) {
      await _loadAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Workspace could not be opened. Check your connection and account access, then try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingWorkspace = false);
    }
  }

  final _keys = List.generate(5, (_) => GlobalKey<_CmsPageState>());
  void _select(int index) => setState(() => _tab = index);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 768;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/images/ssite_logo_cropped.png',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      constraints.maxWidth < 240
                          ? 'SSITE'
                          : 'STUDENT SOCIETY IN INFORMATION\nTECHNOLOGY EDUCATION',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: constraints.maxWidth < 240 ? 18 : 13,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const Text(
                      'Mabalacat City College',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_api.supportsWebsite)
            IconButton(
              tooltip: 'Search all content',
              icon: const Icon(Icons.search),
              onPressed: () => _openAccount('search'),
            ),
          if (_api.supportsWebsite)
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => _openAccount('notifications'),
            ),
          if (_canAccessWorkspace)
            IconButton(
              tooltip: 'Workspace',
              onPressed: _openingWorkspace ? null : _openWorkspace,
              icon: _openingWorkspace
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.dashboard_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Account options',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (['profile', 'notifications', 'search'].contains(value)) {
                _openAccount(value);
              } else if (value == 'workspace') {
                _openWorkspace();
              } else if (value == 'refresh') {
                _keys[_tab].currentState?.reload();
                _loadAccount();
              } else {
                widget.onSignOut();
              }
            },
            itemBuilder: (_) => [
              if (_api.supportsWebsite)
                const PopupMenuItem(
                  value: 'profile',
                  child: Text('Edit profile'),
                ),
              if (_api.supportsWebsite)
                const PopupMenuItem(
                  value: 'notifications',
                  child: Text('Notifications'),
                ),
              if (_api.supportsWebsite)
                const PopupMenuItem(
                  value: 'search',
                  child: Text('Search all content'),
                ),
              if (_canAccessWorkspace)
                const PopupMenuItem(
                  value: 'workspace',
                  child: Text('Workspace'),
                ),
              const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
        bottom: compact
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: CmsNavigation(
                    selectedIndex: _tab,
                    onSelect: _select,
                    compact: false,
                  ),
                ),
              ),
      ),
      body: CustomPaint(
        painter: const _GridPainter(),
        child: SafeArea(
          top: false,
          child: IndexedStack(
            index: _tab,
            children: [
              CmsPage(
                key: _keys[0],
                kind: 'home',
                onSelect: _select,
                api: widget.api,
              ),
              CmsPage(
                key: _keys[1],
                kind: 'discover',
                onSelect: _select,
                api: widget.api,
              ),
              CmsPage(
                key: _keys[2],
                kind: 'liquidations',
                onSelect: _select,
                api: widget.api,
              ),
              CmsPage(
                key: _keys[3],
                kind: 'documents',
                onSelect: _select,
                api: widget.api,
              ),
              CmsPage(
                key: _keys[4],
                kind: 'about',
                onSelect: _select,
                api: widget.api,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: compact
          ? CmsNavigation(selectedIndex: _tab, onSelect: _select)
          : null,
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()..color = const Color(0x0617324D);
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), pen);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pen);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
