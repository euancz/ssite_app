import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdfrx/pdfrx.dart';

import '../app_theme.dart';
import '../services/cms_api.dart';
import '../services/member_profile.dart';
import '../widgets/cms_hero.dart';
import '../widgets/cms_navigation.dart';

part 'content/cms_page.dart';
part 'content/post_cards.dart';
part 'content/about_content.dart';
part 'content/document_content.dart';
part 'content/sponsor_card.dart';
part 'content/content_widgets.dart';
part 'content/global_search.dart';
part 'content/community_hero.dart';
part 'member_account.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.onSignOut,
    this.api,
    this.profile,
  });
  final VoidCallback onSignOut;
  final CmsApi? api;
  final MemberProfile? profile;
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _tab = 0;
  late final _api = widget.api ?? CmsApi.instance;
  late final _profile = ValueNotifier<MemberProfile?>(widget.profile);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAccount();
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile != null) _profile.value = widget.profile;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profile.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAccount();
    }
  }

  Future<void> _loadAccount() async {
    if (!_api.supportsWebsite || widget.profile != null) return;
    try {
      final user = await _api.currentUser();
      if (mounted) _profile.value = MemberProfile.fromCms(user);
    } on CmsUnauthorized {
      if (mounted) _endSession();
    } catch (_) {
      // Keep the last known account options during a connection interruption.
    }
  }

  Future<void> _openAccount() async {
    final action = await showModalBottomSheet<_AccountAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => _MemberAccount(profile: _profile),
    );
    if (!mounted) return;
    if (action == _AccountAction.signOut) {
      _endSession();
    } else if (action == _AccountAction.refresh) {
      _keys[_tab].currentState?.reload();
      _loadAccount();
    }
  }

  void _openSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _GlobalSearch(api: _api)));
  }

  void _endSession() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onSignOut();
  }

  final _keys = List.generate(5, (_) => GlobalKey<_CmsPageState>());
  void _select(int index) => setState(() => _tab = index);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 768;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: accent,
        titleSpacing: compact ? 12 : 24,
        title: Row(
          children: [
            Image.asset(
              'assets/images/ssite_logo_cropped.png',
              width: compact ? 42 : 60,
              height: compact ? 42 : 60,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compact || constraints.maxWidth < 240
                          ? 'SSITE'
                          : 'STUDENT SOCIETY IN INFORMATION\nTECHNOLOGY EDUCATION',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 18 : 13,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const Text(
                      'Mabalacat City College',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search all content',
            icon: const Icon(Icons.search_rounded),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: 'Account options',
            onPressed: _openAccount,
            icon: ValueListenableBuilder<MemberProfile?>(
              valueListenable: _profile,
              builder: (_, profile, _) =>
                  _MemberAvatar(profile: profile, size: 36),
            ),
          ),
          const SizedBox(width: 8),
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
