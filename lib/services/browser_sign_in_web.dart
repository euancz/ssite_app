import 'package:web/web.dart' as web;

String? takeBrowserSignInCode() {
  final uri = Uri.base;
  final code = Uri.splitQueryString(uri.fragment)['ssite_code'];
  if (code != null) {
    web.window.history.replaceState(null, '', uri.removeFragment().toString());
  }
  return code;
}
