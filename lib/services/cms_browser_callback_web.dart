import 'package:web/web.dart' as web;

Uri? cmsBrowserCallback() {
  final callback = Uri.base;
  if (!callback.fragment.startsWith('ssite_code=')) return null;
  web.window.history.replaceState(
    null,
    '',
    callback.removeFragment().toString(),
  );
  return callback;
}
