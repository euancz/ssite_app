create function ssite_mobile.post_fields(m text) returns text[] language sql immutable as $$
 select array['title']||case m when 'articles' then array['content','category','content_format']
 when 'activities' then array['description','category','content_format','activity_date','location']
 when 'achievements' then array['description','content_format','category','achievement_date','awardee']
 when 'documents' then array['description','category','academic_year','semester']
 when 'liquidations' then array['description','amount','report_date','semester'] else array[]::text[] end $$;
create function ssite_mobile.feed(u public.users,m text,q jsonb) returns jsonb language sql stable set search_path='' as $$
 with opts as(select greatest(1,least(100000,coalesce((q->>'page')::integer,1))) page,
 greatest(1,least(50,coalesce((q->>'per_page')::integer,10))) size),
 visible as(select p.module,p.record r,coalesce(a.name,'Former member') author,a.role author_role,
 coalesce(p.record->>'activity_date',p.record->>'achievement_date',p.record->>'report_date',p.record->>'created_at') event_date
 from ssite_mobile.posts p left join public.users a on a.id=(p.record->>'created_by_user_id')::int
 where ssite_mobile.live(p.record) and (p.module=m or m='discover' and p.module in ('articles','activities','achievements') and coalesce(nullif(q->>'type',''),'all') in ('all',p.module))),
 filtered as(select * from visible where
 (coalesce(q->>'q','')='' or concat_ws(' ',r->>'title',r->>'content',r->>'description',author,r->>'category',r->>'location',r->>'awardee') ilike '%'||(q->>'q')||'%')
 and (coalesce(q->>'category','')='' or r->>'category'=q->>'category')
 and (coalesce(q->>'semester','')='' or r->>'semester'=q->>'semester')
 and (coalesce(q->>'academic_year','')='' or coalesce(nullif(r->>'academic_year',''),'unassigned')=q->>'academic_year')
 and (coalesce(q->>'year','')='' or left(event_date,4)=q->>'year')
 and (r->>'created_at')::timestamp >= case q->>'period' when 'week' then now()-interval '7 days' when 'month' then now()-interval '1 month' when 'year' then now()-interval '1 year' else '-infinity'::timestamptz end),
 sorted as(select *,row_number() over(order by
 case when q->>'sort'='title' then r->>'title' end asc,
 case when q->>'sort'='amount_high' then (r->>'amount')::numeric end desc nulls last,
 case when q->>'sort'='amount_low' then (r->>'amount')::numeric end asc nulls last,
 case when q->>'sort'='report_soonest' then event_date end asc nulls last,
 case when q->>'sort' in ('event_latest','report_latest') then event_date end desc nulls last,
 case when q->>'sort'='oldest' then r->>'created_at' end asc,
 case when q->>'sort' in ('popular','most_liked') then (r->>'like_count')::int end desc,
 case when q->>'sort'='most_viewed' then (r->>'view_count')::int end desc,
 r->>'created_at' desc,module,(r->>'id')::int desc) seq from filtered),
 slice as(select * from sorted order by seq limit (select size from opts) offset(select (page-1)*size from opts)),
 totals as(select count(*) n from filtered)
 select jsonb_build_object('data',coalesce((select jsonb_agg((r-'created_by_user_id'-'reviewed_by_user_id'-'rejection_reason'-'reviewed_at')||
 jsonb_build_object('module',module,'author',author,'author_role',author_role,'date',event_date,'description',coalesce(r->>'content',r->>'description',''),
 'view_count',case when cfg.views then r->'view_count' end,'like_count',case when cfg.likes then r->'like_count' end,
 'liked_by_viewer',exists(select from public.post_likes l where l.post_type=ssite_mobile.kind(module) and l.post_id=(r->>'id')::int and l.user_id=u.id),
 'url',nullif(rtrim(cfg.website_url,'/'),'')||'/'||module||'/'||(r->>'id')) order by seq) from slice cross join ssite_mobile.settings cfg),'[]'::jsonb),
 'meta',jsonb_build_object('current_page',page,'last_page',greatest(1,ceil(n::numeric/size)),'total',n,'filters',
 case when q->>'facets'='0' then '{}'::jsonb else jsonb_build_object(
 'category',(select coalesce(jsonb_agg(distinct r->>'category' order by r->>'category') filter(where nullif(r->>'category','') is not null),'[]') from visible),
 'year',(select coalesce(jsonb_agg(distinct left(event_date,4) order by left(event_date,4) desc),'[]') from visible),
 'semester',(select coalesce(jsonb_agg(distinct r->>'semester') filter(where r->>'semester' is not null),'[]') from visible),
 'academic_year',(select coalesce(jsonb_agg(distinct r->>'academic_year') filter(where r->>'academic_year' is not null),'[]') from visible)) end)) from opts,totals
$$;
create function ssite_mobile.tool_read(u public.users,p text[],q jsonb) returns jsonb language plpgsql stable set search_path='' as $$
declare k text:=p[1]; m text:=p[2]; id int; entry jsonb; outdata jsonb:='{}'; cfg ssite_mobile.settings%rowtype; roster boolean:=k='roster'; allowed_roles text[];
begin
 select * into strict cfg from ssite_mobile.settings;
 if k='profile' then return jsonb_build_object('name',u.name,'email',u.email,'role',u.role,'photo',u.profile_picture);end if;
 if k='notifications' then return jsonb_build_object('rows',(select coalesce(jsonb_agg(jsonb_build_object('id',n.id,'data',n.data::jsonb-'url','read_at',n.read_at) order by n.created_at desc),'[]') from public.notifications n where n.notifiable_id=u.id and n.notifiable_type=E'App\\Models\\User'));end if;
 if k='post' then entry:=ssite_mobile.post(m,p[3]::int);perform ssite_mobile.check_ok(entry is not null and (ssite_mobile.live(entry) or ssite_mobile.editable(u,m,entry)),'Post unavailable.');
 return jsonb_build_object('record',entry,'editable',ssite_mobile.editable(u,m,entry));end if;
 if k='users' then perform ssite_mobile.check_ok(u.role in ('adviser','admin'),'Role management unavailable.');
 allowed_roles:=case when u.role='admin' then array['student','officer','adviser'] else array['student','officer'] end;
 if m is null then return jsonb_build_object('rows',(select coalesce(jsonb_agg(to_jsonb(x) order by x.name,x.id),'[]') from (select t.id,t.name,t.email,t.role from public.users t where t.id<>u.id and t.role=any(allowed_roles) and concat_ws(' ',t.name,t.email,t.role) ilike '%'||coalesce(q->>'q','')||'%') x));end if;
 select jsonb_build_object('id',t.id,'name',t.name,'email',t.email,'role',t.role,'officer_position',t.officer_position) into entry from public.users t where t.id=m::int and t.id<>u.id and t.role=any(allowed_roles);
 perform ssite_mobile.check_ok(entry is not null,'User unavailable.');return jsonb_build_object('record',entry,'actor_role',u.role);end if;
 if k in ('roster','sponsors') then perform ssite_mobile.check_ok(ssite_mobile.president(u),'President required.');
 if m is null then execute format('select jsonb_build_object(''rows'',coalesce(jsonb_agg(to_jsonb(x) order by %s sort_order,name),''[]'')) from public.%I x',case when roster then 'academic_year desc,' else '' end,case when roster then 'officer_terms' else 'sponsors' end) into outdata;
 else if m<>'new' then execute format('select to_jsonb(x) from public.%I x where id=$1',case when roster then 'officer_terms' else 'sponsors' end) into entry using m::int;perform ssite_mobile.check_ok(entry is not null,'Entry unavailable.');end if;
 outdata:=jsonb_build_object('record',coalesce(entry,'{}'));if roster then outdata:=outdata||jsonb_build_object('users',(select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'email',t.email) order by name),'[]') from public.users t where role in ('student','officer')));end if;end if;return outdata;end if;
 if k='workspace' then perform ssite_mobile.check_ok(u.role in ('admin','adviser') or exists(select from unnest(ssite_mobile.modules()) v where ssite_mobile.allowed(u,v)),'No workspace access.');
 return jsonb_build_object('role',u.role,'president',ssite_mobile.president(u),'modules',(select coalesce(jsonb_agg(v),'[]') from unnest(ssite_mobile.modules()) v where ssite_mobile.allowed(u,v)),
 'stats',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from (select module,record->>'approval_status' approval,record->>'content_status' status,count(*) n from ssite_mobile.posts where u.role in ('adviser','admin') or ssite_mobile.allowed(u,module) and (ssite_mobile.president(u) or (record->>'created_by_user_id')::int=u.id) group by 1,2,3)x),
 'members',case when u.role in ('adviser','admin') then (select jsonb_object_agg(role,n) from(select role,count(*) n from public.users group by role)t) end,
 'leaders',case when u.role in ('adviser','admin') then (select coalesce(jsonb_agg(jsonb_build_object('name',t.name,'role',t.role)),'[]') from public.users t where ssite_mobile.president(t) or u.role='admin' and t.role='adviser') end);end if;
 if k in ('history','reviews') then perform ssite_mobile.check_ok(exists(select from unnest(ssite_mobile.modules()) v where ssite_mobile.allowed(u,v)) and (k<>'reviews' or ssite_mobile.president(u)),'No review access.');
 return jsonb_build_object('modules',(select jsonb_agg(v) from unnest(ssite_mobile.modules()) v where ssite_mobile.allowed(u,v)),
 'records',(select coalesce(jsonb_agg(jsonb_build_object('module',module,'title',record->>'title','id',record->'id','created_at',record->'created_at','status',record->>'approval_status') order by record->>'updated_at' desc),'[]') from ssite_mobile.posts where ssite_mobile.editable(u,module,record)),
 'events',(select coalesce(jsonb_agg(jsonb_build_object('module',p.module,'title',e.post_title,'decision',e.decision,'reviewer',e.reviewer_name,'reason',e.reason,'created_at',e.created_at) order by e.id desc),'[]') from public.content_review_events e join ssite_mobile.posts p on e.post_type=ssite_mobile.kind(p.module) and e.post_id=(p.record->>'id')::int where ssite_mobile.editable(u,p.module,p.record)));end if;
 perform ssite_mobile.check_ok(k='content' and ssite_mobile.allowed(u,m),'No access to this module.');
 if p[3] is null then return jsonb_build_object('president',ssite_mobile.president(u),
 'drafts',(select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'title',d.payload->>'title') order by updated_at desc),'[]') from public.content_drafts d where module=m and created_by_user_id=u.id),
 'rows',(select coalesce(jsonb_agg(jsonb_build_object('id',record->'id','title',record->>'title','approval_status',record->>'approval_status','content_status',record->>'content_status') order by record->>'updated_at' desc),'[]') from ssite_mobile.posts where module=m and ssite_mobile.editable(u,m,record)));end if;
 if p[3]='new' then return '{"record":{}}';end if;
 if p[3]='draft' then select to_jsonb(d) into entry from public.content_drafts d where d.id=p[4]::uuid and d.module=m and d.created_by_user_id=u.id;
 perform ssite_mobile.check_ok(entry is not null,'Draft unavailable.');return jsonb_build_object('draft',entry,'record',entry->'payload');end if;
 id:=p[3]::int;entry:=ssite_mobile.post(m,id);perform ssite_mobile.check_ok(entry is not null and ssite_mobile.editable(u,m,entry),'Post unavailable.');
 return jsonb_build_object('record',entry,'president',ssite_mobile.president(u),'versions',(select coalesce(jsonb_agg(jsonb_build_object('kind',v.kind,'editor_name',v.editor_name,'snapshot',v.snapshot) order by v.id desc),'[]') from public.content_versions v where v.post_type=ssite_mobile.kind(m) and v.post_id=p[3]::int));end $$;

create function public.ssite_app_read(route text, params jsonb default '{}') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u public.users:=ssite_mobile.actor(); cfg ssite_mobile.settings%rowtype; y int; ay text; leaders jsonb;
begin
 perform ssite_mobile.check_ok(ssite_mobile.azure_identity() is not null,'School Microsoft sign-in required.');
 select * into strict cfg from ssite_mobile.settings;
 if route='auth/me' then return jsonb_build_object('user',jsonb_build_object('name',u.name,'email',u.email,'role',u.role,'position',u.officer_position,'avatar',u.profile_picture,
 'linked',exists(select from ssite_mobile.accounts where auth_id=auth.uid()),'profile_complete',u.id is not null,
 'can_access_workspace',u.role in ('admin','adviser') or exists(select from unnest(ssite_mobile.modules()) v where ssite_mobile.allowed(u,v))));end if;
 perform ssite_mobile.check_ok(u.id is not null,'Complete your profile.');
 if route=any(ssite_mobile.modules()) or route='discover' then return ssite_mobile.feed(u,route,params);end if;
 if route in ('home','about') then y:=extract(year from current_date)::int-case when extract(month from current_date)<6 then 1 else 0 end;ay:=y||'-'||(y+1);
 select coalesce(jsonb_agg(jsonb_build_object('name',name,'position',position,'photo',photo) order by sort_order,name),'[]') into leaders from public.officer_terms where academic_year=ay;
 if route='about' then return jsonb_build_object('data',jsonb_build_object('academic_year',ay,'officers',leaders,'history',(select coalesce(jsonb_object_agg(academic_year,officers),'{}') from(select academic_year,jsonb_agg(jsonb_build_object('name',name,'position',position,'photo',photo) order by sort_order,name) officers from public.officer_terms group by academic_year)x)));end if;
 return jsonb_build_object('data',jsonb_build_object('officers',leaders,'sponsors',(select coalesce(jsonb_agg(jsonb_build_object('name',name,'description',description,'website_url',website_url,'logo',logo_path) order by sort_order,name),'[]') from public.sponsors where is_active),
 'articles',ssite_mobile.feed(u,'articles','{"per_page":1,"facets":"0"}')->'data','activities',ssite_mobile.feed(u,'activities','{"per_page":1,"facets":"0","sort":"event_latest"}')->'data','achievements',ssite_mobile.feed(u,'achievements','{"per_page":1,"facets":"0","sort":"event_latest"}')->'data'));end if;
 perform ssite_mobile.check_ok(route like 'tools/%','Unknown page.');return ssite_mobile.tool_read(u,string_to_array(substr(route,7),'/'),params);
end $$;
revoke all on function public.ssite_app_read(text,jsonb) from public,anon;
grant execute on function public.ssite_app_read(text,jsonb) to authenticated;

