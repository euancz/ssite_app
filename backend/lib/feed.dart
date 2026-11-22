part of 'server.dart';

extension Feed on MobileServer {
  String get currentYear {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final y = now.year - (now.month < 6 ? 1 : 0);
    return '$y-${y + 1}';
  }

  Future<Row> posts(String section, Map<String, String> q, Row u) async {
    final selected = section == 'discover'
        ? ((q['type'] == null || q['type'] == 'all')
              ? ['articles', 'activities', 'achievements']
              : [q['type']!])
        : [section];
    for (final m in selected) {
      module(m);
    }
    final args = <dynamic>[u['id']];
    String bind(dynamic value) {
      args.add(value);
      return '?${args.length}';
    }

    final union = selected
        .map((m) {
          final meta = modules[m]!;
          return """select '$m' as module,p.id,p.title,p.${meta[1]} as description,p.created_at,p.view_count,p.like_count,to_jsonb(p) as fields,u.name as author,u.role as author_role,exists(select 1 from post_likes l where l.post_type='${meta[0]}' and l.post_id=p.id and l.user_id=?1) as liked_by_viewer from $m p left join users u on u.id=p.created_by_user_id where p.approval_status='approved' and p.content_status='active'""";
        })
        .join(' union all ');
    final conditions = ['true'];
    if ((q['q'] ?? '').trim().isNotEmpty)
      conditions.add(
        "concat_ws(' ',title,description,author,fields->>'category',fields->>'awardee',fields->>'location') ilike ${bind('%${q['q']}%')}",
      );
    for (final k in ['category', 'semester', 'academic_year']) {
      if ((q[k] ?? '').isNotEmpty) {
        conditions.add(
          q[k] == 'unassigned'
              ? "nullif(fields->>'$k','') is null"
              : "fields->>'$k'=${bind(q[k])}",
        );
      }
    }
    const year =
        "left(coalesce(fields->>'activity_date',fields->>'achievement_date',fields->>'report_date',created_at::text),4)";
    if ((q['year'] ?? '').isNotEmpty)
      conditions.add('$year=${bind(q['year'])}');
    final days = {'week': 7, 'month': 30, 'year': 365}[q['period']];
    if (days != null) conditions.add("created_at>=now()-interval '$days days'");
    const sorts = {
      'recent': 'created_at desc',
      'event_latest':
          "coalesce(fields->>'activity_date',fields->>'achievement_date') desc nulls last",
      'featured': "fields->>'featured_at' desc nulls last,created_at desc",
      'oldest': 'created_at asc',
      'title': 'title asc',
      'report_soonest': "fields->>'report_date' asc nulls last",
      'report_latest': "fields->>'report_date' desc nulls last",
      'amount_high': "(fields->>'amount')::numeric desc nulls last",
      'amount_low': "(fields->>'amount')::numeric asc nulls last",
      'popular': 'like_count desc,view_count desc',
      'most_liked': 'like_count desc',
      'most_viewed': 'view_count desc',
    };
    final n = (int.tryParse(q['page'] ?? '') ?? 1).clamp(1, 100000),
        size = (int.tryParse(q['per_page'] ?? '') ?? 10).clamp(1, 50);
    final from = ' from ($union) x where ${conditions.join(' and ')}';
    final total =
        (await one(db, 'select count(*) as n$from', args))!['n'] as int;
    final data = await rows(
      db,
      'select *$from order by ${sorts[q['sort']] ?? sorts['recent']},module,id desc limit $size offset ${(n - 1) * size}',
      args,
    );
    final filters = <String, List<String>>{};
    if (n == 1 && q['facets'] != '0') {
      final all = await rows(
        db,
        "select distinct fields->>'category' as category,fields->>'academic_year' as academic_year,fields->>'semester' as semester,$year as year from ($union) x",
        [u['id']],
      );
      for (final k in ['category', 'academic_year', 'semester', 'year']) {
        filters[k] =
            all
                .map((r) => r[k]?.toString() ?? '')
                .where((v) => v.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
      }
    }
    for (final r in data) {
      final f = r.remove('fields') as Map,
          m = r['module'],
          text = (r['description'] ?? '').toString();
      r.addAll({
        for (final k in [
          'category',
          'semester',
          'academic_year',
          'location',
          'awardee',
          'amount',
        ])
          k: f[k],
        'date':
            f['activity_date'] ??
            f['achievement_date'] ??
            f['report_date'] ??
            r['created_at'],
        'content_html': f['content_format'] == 'markdown'
            ? md.markdownToHtml(
                text,
                extensionSet: md.ExtensionSet.gitHubFlavored,
                encodeHtml: true,
              )
            : '<p>${const HtmlEscape().convert(text).replaceAll('\n', '<br>')}</p>',
        'url': cfg['APP_URL'] == null
            ? null
            : '${cfg['APP_URL']}/${m == 'liquidations' ? 'liquidations' : m}/${r['id']}',
        'file_url': f['file_path'] == null ? null : '$api/files/$m/${r['id']}',
        'image_url': f['image'] == null ? null : '$api/media/$m/${r['id']}',
      });
      if (cfg['SCHOOL_ENABLE_LIKES'] == 'false') r['like_count'] = null;
      if (cfg['SCHOOL_ENABLE_VIEW_COUNTS'] == 'false') r['view_count'] = null;
    }
    return {
      'data': data,
      'meta': {
        'current_page': n,
        'last_page': max(1, (total / size).ceil()),
        'total': total,
        'filters': filters,
      },
    };
  }

  Future<void> feed(
    HttpRequest req,
    List<String> parts,
    Row u,
    bool post,
    Row b,
  ) async {
    final res = req.response, k = parts.first, q = req.uri.queryParameters;
    if (!post &&
        parts.length == 1 &&
        (modules.containsKey(k) || k == 'discover')) {
      this.json(res, await posts(k, q, u));
      return;
    }
    if (!post && parts.length == 1 && ['about', 'home'].contains(k)) {
      final roster = await rows(
        db,
        'select academic_year,name,position,photo from officer_terms order by academic_year desc,sort_order,name',
      );
      final history = <String, List<Row>>{};
      for (final r in roster) {
        r['photo_url'] = photo(r.remove('photo'));
        (history[r['academic_year']] ??= []).add(r);
      }
      final data = <String, dynamic>{
        'academic_year': currentYear,
        'officers': history[currentYear] ?? [],
      };
      if (k == 'about') {
        data['history'] = history;
      } else {
        for (final m in ['articles', 'activities', 'achievements']) {
          data[m] = (await posts(m, {
            'per_page': '1',
            'facets': '0',
            'sort': m == 'articles' ? 'recent' : 'event_latest',
          }, u))['data'];
        }
        data['sponsors'] = (await rows(
          db,
          'select name,description,website_url,logo_path from sponsors where is_active order by sort_order,name',
        )).map((r) => {...r, 'logo_url': photo(r['logo_path'])}).toList();
      }
      this.json(res, {'data': data});
      return;
    }
    if (!post &&
        parts.length == 3 &&
        ['files', 'media', 'attachment'].contains(k)) {
      final m = parts[1];
      module(m);
      final p = await one(db, 'select * from $m where id=?1', [
        int.tryParse(parts[2]) ?? -1,
      ]);
      require(
        p != null && (live(p) || k == 'attachment' && editable(u, m, p)),
        404,
        'Attachment unavailable.',
      );
      final isPdf = pdf(m), key = p![isPdf ? 'file_path' : 'image'] as String?;
      require(
        (k == 'attachment' || (k == 'files') == isPdf) &&
            key != null &&
            (key.startsWith("${m == 'liquidations' ? 'liquidation' : m}/") ||
                !isPdf && key.startsWith('post-media/$m/')),
        404,
        'Attachment unavailable.',
      );
      await serveObject(
        req,
        isPdf || key!.startsWith('post-media/') ? 'private' : 'public',
        key!,
      );
      return;
    }
    if (post && parts.length == 4 && k == 'engagement') {
      final m = parts[1], id = int.tryParse(parts[2]) ?? -1, op = parts[3];
      module(m);
      require(['view', 'like'].contains(op), 404, 'Unknown action.');
      final result = await tx((s) async {
        final p = await one(s, 'select * from $m where id=?1 for update', [id]);
        require(p != null && live(p), 404, 'Post unavailable.');
        final args = [modules[m]!.first, id, u['id']];
        bool? liked;
        if (op == 'view' && cfg['SCHOOL_ENABLE_VIEW_COUNTS'] != 'false') {
          final inserted = await rows(
            s,
            'insert into post_views(post_type,post_id,user_id,created_at) values(?1,?2,?3,now()) on conflict do nothing returning id',
            args,
          );
          if (inserted.isNotEmpty)
            await rows(s, 'update $m set view_count=view_count+1 where id=?1', [
              id,
            ]);
        } else if (op == 'like') {
          require(
            cfg['SCHOOL_ENABLE_LIKES'] != 'false',
            403,
            'Likes disabled.',
          );
          liked = (await rows(
            s,
            'delete from post_likes where post_type=?1 and post_id=?2 and user_id=?3 returning id',
            args,
          )).isEmpty;
          if (liked) {
            await rows(
              s,
              'insert into post_likes(post_type,post_id,user_id,created_at) values(?1,?2,?3,now())',
              args,
            );
            if (p!['created_by_user_id'] != u['id'])
              await notify(s, m, p, u, 'liked');
          }
          await rows(
            s,
            'update $m set like_count=greatest(0,like_count+?1) where id=?2',
            [liked ? 1 : -1, id],
          );
        }
        return {
          ...(await one(s, 'select like_count,view_count from $m where id=?1', [
            id,
          ]))!,
          'liked_by_viewer': ?liked,
        };
      });
      this.json(res, result);
      return;
    }
    throw Problem(404, 'Unknown endpoint.');
  }
}
