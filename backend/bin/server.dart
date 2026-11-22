import 'dart:io';
import 'dart:async';
import 'package:ssite_mobile_backend/server.dart';

Future<void> main() async {
  final cfg = configuration();
  final db = database(cfg);
  final service = MobileServer(cfg, db);
  await db.execute('select 1');
  final server = await HttpServer.bind(
    cfg['MOBILE_BIND'] ?? '127.0.0.1',
    int.parse(cfg['PORT'] ?? '8001'),
  );
  stdout.writeln(
    'SSITE Dart backend listening on ${server.address.address}:${server.port}',
  );
  final cleanup = Timer.periodic(const Duration(hours: 1), (_) async {
    try {
      await db.execute(
        "delete from cache where key like 'ssiteapp:%' and expiration<=extract(epoch from now())",
      );
    } catch (_) {
      stderr.writeln(
        'Expired mobile sessions will be cleaned up on the next pass.',
      );
    }
  });
  try {
    await server.forEach(service.handle);
  } finally {
    cleanup.cancel();
    await db.close();
  }
}
