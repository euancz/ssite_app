import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;
import 'package:postgres/postgres.dart';
import 'package:ssite_mobile_backend/server.dart';
import 'package:test/test.dart';

void main() {
  test('officer capabilities match the school positions', () {
    expect(
      allowed({'role': 'student', 'officer_position': 'President'}),
      isEmpty,
    );
    expect(allowed({'role': 'officer', 'officer_position': 'Secretary'}), [
      'documents',
    ]);
    expect(
      president({'role': 'officer', 'officer_position': ' president '}),
      isTrue,
    );
    expect(
      roles({'id': 1, 'role': 'adviser'}, {'id': 2, 'role': 'admin'}),
      isEmpty,
    );
    expect(yearOK('2026-2028'), isFalse);
  });
  test(
    'native API saves, reviews and archives the same canonical document',
    () async {
      final cfg = configuration();
      final storage = await Directory.systemTemp.createTemp(
        'ssite-dart-fixture-',
      );
      final db = await Connection.open(
        Endpoint(
          host: cfg['DB_HOST']!,
          port: int.parse(cfg['DB_PORT'] ?? '5432'),
          database: cfg['DB_DATABASE']!,
          username: cfg['DB_USERNAME'],
          password: cfg['DB_PASSWORD'],
        ),
        settings: ConnectionSettings(
          sslMode: cfg['DB_SSLMODE'] == 'require'
              ? SslMode.require
              : cfg['DB_SSLMODE'] == 'disable'
              ? SslMode.disable
              : SslMode.verifyFull,
        ),
      );
      final service = MobileServer({
        ...cfg,
        'MEDIA_STORAGE': 'local',
        'MOBILE_STORAGE_ROOT': storage.path,
      }, db);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(service.handle);
      addTearDown(() async {
        await server.close(force: true);
        await db.close();
        await storage.delete(recursive: true);
      });
      // Temp-only search path keeps every fixture, session and content write isolated.
      await db.execute('set search_path to pg_temp, pg_catalog');
      for (final ddl in [
        'create temp table cache(key text primary key,value text,expiration bigint)',
        'create temp table users(id int primary key,name text,email text,microsoft_id text,role text,officer_position text,profile_completed_at timestamp default now(),profile_picture text,updated_at timestamp)',
        "insert into users(id,name,email,microsoft_id,role,officer_position) values(1,'Student','s@test','s','student',null),(2,'Secretary','o@test','o','officer','Secretary'),(3,'President','p@test','p','officer','President'),(4,'Adviser','a@test','a','adviser',null)",
        'create temp table documents(id serial primary key,title text,description text,category text,academic_year text,semester text,file_path text,file_size int,original_name text,created_by_user_id int,approval_status text,content_status text,rejection_reason text,reviewed_by_user_id int,reviewed_at timestamp,created_at timestamp,updated_at timestamp,like_count int default 0,view_count int default 0)',
        'create temp table content_drafts(id uuid,module text,payload json,created_by_user_id int,lock_version int,created_at timestamp,updated_at timestamp)',
        'create temp table content_versions(id serial,post_type text,post_id int,editor_user_id int,editor_name text,kind text,snapshot json,created_at timestamp)',
        'create temp table content_review_events(id serial,post_type text,post_id int,reviewer_user_id int,reviewer_name text,post_title text,decision text,reason text,created_at timestamp)',
        'create temp table notifications(id uuid,type text,notifiable_type text,notifiable_id int,data text,read_at timestamp,created_at timestamp,updated_at timestamp)',
        'create temp table post_views(id serial,post_type text,post_id int,user_id int,created_at timestamp,unique(post_type,post_id,user_id))',
        'create temp table post_likes(like post_views including all)',
        'create temp table role_changes(user_id int,changed_by_user_id int,old_role text,new_role text,old_officer_position text,new_officer_position text,created_at timestamp,updated_at timestamp)',
      ]) {
        await db.execute(ddl);
      }
      for (final m in [
        'articles',
        'activities',
        'achievements',
        'liquidations',
      ]) {
        await db.execute(
          'create temp table $m (like documents including defaults, content text, content_format text, image text, location text, awardee text, activity_date date, achievement_date date, report_date date, amount numeric(12,2))',
        );
      }
      await db.execute(
        'create temp table sponsors(id serial primary key,name text,description text,website_url text,is_active boolean,logo_path text,sort_order int,created_at timestamp,updated_at timestamp)',
      );
      await db.execute(
        'create temp table officer_terms(id serial primary key,name text,position text,user_id int,academic_year text,photo text,sort_order int,created_at timestamp,updated_at timestamp)',
      );
      final tokens = {
        for (final actor in ['s', 'o', 'p', 'a'])
          actor: await service.issue('access', {'mid': actor}, 600),
      };
      Future<http.Response> call(
        String path,
        String actor, {
        Row? body,
        int status = 200,
      }) async {
        final uri = Uri.parse(
              'http://127.0.0.1:${server.port}/api/mobile/v1/$path',
            ),
            headers = {
              'Authorization': 'Bearer ${tokens[actor]}',
              'Content-Type': 'application/json',
            };
        final r = body == null
            ? await http.get(uri, headers: headers)
            : await http.post(uri, headers: headers, body: jsonEncode(body));
        expect(r.statusCode, status, reason: '$path: ${r.body}');
        return r;
      }

      await call('documents', 'missing', status: 401);
      await call('tools/workspace', 's', status: 403);
      await call('tools/content/articles/new', 'o', status: 403);
      await call(
        'tools/content/documents/save',
        'o',
        body: {
          'title': 'Draft',
          'as_draft': true,
          'attachment': {
            'name': 'minutes.pdf',
            'data': base64Encode(utf8.encode('%PDF-1.4\n%%EOF')),
          },
        },
      );
      final draft = (await one(db, 'select * from content_drafts'))!;
      await call(
        'tools/content/documents/save',
        'o',
        body: {'draft_id': draft['id'], 'version': '7', 'title': 'Stale'},
        status: 409,
      );
      await call(
        'tools/content/documents/save',
        'o',
        body: {'draft_id': draft['id'], 'version': '1', 'title': 'Minutes'},
      );
      expect(jsonDecode((await call('documents', 's')).body)['data'], isEmpty);
      Future<Row> revision() async => {
        'updated': service.stamp(
          (await one(db, 'select updated_at from documents where id=1'))!,
        ),
      };
      await call(
        'tools/content/documents/1/approve',
        'o',
        body: await revision(),
        status: 403,
      );
      await call(
        'tools/content/documents/1/approve',
        'p',
        body: await revision(),
      );
      expect(
        jsonDecode((await call('documents', 's')).body)['data'][0]['title'],
        'Minutes',
      );
      await call('tools/content/documents?status=approved&q=Minutes', 'o');
      await call('tools/history?module=documents&days=30', 'o');
      await call('tools/reviews?module=documents&status=approved', 'p');
      await call('tools/notifications', 'o');
      await call('tools/users', 'a');
      await call('tools/users/4', 'a', status: 403);
      await call('files/documents/1', 's');
      await call('engagement/documents/1/view', 's', body: {});
      await call('engagement/documents/1/like', 's', body: {});
      expect(
        (await one(db, 'select like_count from documents'))!['like_count'],
        1,
      );
      await call(
        'tools/content/documents/1/archive',
        'o',
        body: await revision(),
      );
      await call('files/documents/1', 's', status: 404);
      await call(
        'tools/users/1',
        'a',
        body: {'role': 'officer', 'position': 'President'},
        status: 409,
      );
      await call(
        'tools/users/1',
        'a',
        body: {'role': 'officer', 'position': 'Auditor'},
      );
      await call('tools/content/liquidations/new', 's');
      final photo = {
        'name': 'cover.png',
        'data': base64Encode(image.encodePng(image.Image(width: 2, height: 2))),
      };
      for (final m in [
        'articles',
        'activities',
        'achievements',
        'liquidations',
      ]) {
        await call(
          'tools/content/$m/save',
          'p',
          body: {
            'title': 'Published $m',
            modules[m]![1]: 'Post text',
            if (!pdf(m)) 'content_format': 'markdown',
            if (m == 'activities') 'activity_date': '2026-11-15',
            if (m == 'achievements') 'achievement_date': '2026-11-01',
            if (m == 'liquidations') ...{
              'amount': '125.50',
              'report_date': '2026-11-22',
            },
            'attachment': pdf(m)
                ? {
                    'name': 'report.pdf',
                    'data': base64Encode(utf8.encode('%PDF-1.4\n%%EOF')),
                  }
                : photo,
          },
        );
        final post =
            (jsonDecode((await call(m, 's')).body)['data'] as List).single;
        expect(post['title'], 'Published $m');
        await call('tools/content/$m/${post['id']}', 'p');
      }
      await call('tools/workspace', 'p');
      await call('tools/workspace', 'a');
      await call(
        'tools/roster/new',
        'p',
        body: {
          'name': 'Ari',
          'position': 'Secretary',
          'sort_order': '0',
          'academic_year': service.currentYear,
        },
      );
      await call(
        'tools/sponsors/new',
        'p',
        body: {
          'name': 'Partner',
          'description': 'Supports students',
          'sort_order': '0',
          'is_active': 'true',
          'attachment': photo,
        },
      );
      expect(
        jsonDecode(
          (await call('home', 's')).body,
        )['data']['sponsors'][0]['name'],
        'Partner',
      );
      expect(
        jsonDecode(
          (await call('about', 's')).body,
        )['data']['officers'][0]['name'],
        'Ari',
      );
      await call('auth/logout', 's', body: {});
      await call('auth/me', 's', status: 401);
    },
    skip: Platform.environment['SSITE_TEST_POSTGRES'] != '1'
        ? 'Set SSITE_TEST_POSTGRES=1 and PostgreSQL connection settings.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
