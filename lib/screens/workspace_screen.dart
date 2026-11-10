import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Uses the CMS's responsive workspace, including its role-checked sidebar,
/// forms, drafts, review queue and management screens.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.uri});
  final Uri uri;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _failed = true);
            }
          },
          onNavigationRequest: (request) async {
            final target = Uri.tryParse(request.url);
            if (target == null) return NavigationDecision.prevent;
            if (target.hasAuthority && target.origin == widget.uri.origin) {
              return NavigationDecision.navigate;
            }
            if (['https', 'http', 'mailto', 'tel'].contains(target.scheme)) {
              await launchUrl(target, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    _open();
  }

  Future<void> _open() async {
    // A previous app account must never lend its browser session to this one.
    try {
      await WebViewCookieManager().clearCookies();
      if (mounted) await _controller.loadRequest(widget.uri);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    WebViewCookieManager().clearCookies();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Back to app'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Previous workspace page',
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (await _controller.canGoBack()) await _controller.goBack();
                },
              ),
              IconButton(
                tooltip: 'Reload workspace',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() => _failed = false);
                  _controller.reload();
                },
              ),
            ],
          ),
        ),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          if (_failed)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Could not load the workspace. Check your connection. If the link expired, close this screen and reopen Workspace.',
              ),
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    ),
  );
}
