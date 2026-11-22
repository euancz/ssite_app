create function ssite_mobile.write_row(t text,v jsonb,k int default null) returns jsonb language plpgsql set search_path='' as $$
declare cols text; sels text; result jsonb;
begin
 perform ssite_mobile.check_ok(t=any(ssite_mobile.modules()||array['officer_terms','sponsors']),'Unknown table.');
 select string_agg(format('%I',c),',' order by c),string_agg(format('x.%I',c),',' order by c) into cols,sels from jsonb_object_keys(v) c;
 if k is null then execute format('insert into public.%1$I as p (%2$s,created_at,updated_at) select %3$s,now(),now() from jsonb_populate_record(null::public.%1$I,$1) x returning to_jsonb(p)',t,cols,sels) into result using v;
 else execute format('update public.%1$I as p set (%2$s,updated_at)=(select %3$s,now() from jsonb_populate_record(null::public.%1$I,$1) x) where p.id=$2 returning to_jsonb(p)',t,cols,sels) into result using v,k;end if;
 return result;end $$;
create function ssite_mobile.notice(u public.users,m text,p jsonb,typ text,reason text default null) returns void language sql set search_path='' as $$
 insert into public.notifications(id,type,notifiable_type,notifiable_id,data,created_at,updated_at)
 select gen_random_uuid(),E'App\\Notifications\\'||case typ when 'approved' then 'PostApproved' when 'rejected' then 'PostRejected' when 'submitted' then 'PostSubmittedForReview' when 'published' then 'PostPublished' when 'liked' then 'PostLiked' end,E'App\\Models\\User',t.id,
 jsonb_build_object('post_type',ssite_mobile.kind(m),'post_id',(p->>'id')::int,'title',p->>'title','actor_id',u.id,'actor_name',u.name,'message',case typ when 'approved' then 'Your request was approved.' when 'rejected' then 'Your post was rejected.' when 'submitted' then 'A post is awaiting review.' when 'published' then 'A new post was published.' else u.name||' liked your post.' end,
 'type',typ,'reason',reason,'url',coalesce((select rtrim(website_url,'/') from ssite_mobile.settings),'')||'/'||m||'/'||(p->>'id'))::text,now(),now()
 from public.users t where case typ when 'submitted' then ssite_mobile.president(t) when 'published' then t.id<>u.id and t.id is distinct from (p->>'created_by_user_id')::int else t.id=(p->>'created_by_user_id')::int end
$$;
create function ssite_mobile.snap(m text,r jsonb) returns jsonb language sql immutable as $$
 select jsonb_object_agg(k,r->k) from unnest(ssite_mobile.post_fields(m)) k $$;
create function ssite_mobile.content_write(u public.users,m text,p text[],b jsonb) returns jsonb language plpgsql set search_path='' as $$
declare cfg ssite_mobile.settings%rowtype; op text:=p[array_length(p,1)]; ptype text:=ssite_mobile.kind(m); ispdf boolean:=m in ('documents','liquidations');draft boolean:=coalesce(b->>'as_draft','false')='true';
 filekey text:=case when ispdf then 'file_path' else 'image' end; folder text:=case m when 'documents' then m when 'liquidations' then 'liquidation' else 'post-media/'||m end;
 k text; val text; params jsonb:='{}'; old jsonb; saved jsonb; f jsonb; d public.content_drafts%rowtype; decision text; reason text; ids integer[]; n int;
begin select * into strict cfg from ssite_mobile.settings;
 perform ssite_mobile.check_ok(ssite_mobile.allowed(u,m),'Module access denied.');
 if op='save' and array_length(p,1)=4 then
 if nullif(b->>'id','') is not null then old:=ssite_mobile.post(m,(b->>'id')::int,true);
 perform ssite_mobile.check_ok(old is not null and ssite_mobile.editable(u,m,old) and not draft,'Post unavailable.');perform ssite_mobile.check_ok(old->>'updated_at'=b->>'updated','Post changed. Reopen it.');end if;
 if b->>'draft_id' is not null then select * into d from public.content_drafts t where t.id=(b->>'draft_id')::uuid and t.created_by_user_id=u.id and t.module=m for update;
 perform ssite_mobile.check_ok(d.id is not null and d.lock_version=(b->>'version')::int and old is null,'Draft changed. Reopen it.');end if;
 foreach k in array ssite_mobile.post_fields(m) loop
 val:=nullif(trim(b->>k),'');if k='content_format' then val:=coalesce(val,'plain');perform ssite_mobile.check_ok(val in ('plain','markdown'),'Unknown format.');end if;
 perform ssite_mobile.check_ok(draft or val is not null or (k<>'title' and (ispdf or k not in ('content','description'))),'Complete the title and body.');
 perform ssite_mobile.check_ok(val is null or length(val)<=case when k in ('content','description') then 20000 when k='category' then 100 else 200 end,'Field is too long.');
 if val is not null then
 if k in ('content','description') then perform ssite_mobile.check_ok(cardinality(regexp_split_to_array(val,'\s+'))<=300,'Maximum 300 words.');
 elsif k='academic_year' then perform ssite_mobile.check_ok(ssite_mobile.year_ok(val),'Invalid academic year.');
 elsif k='amount' then perform ssite_mobile.check_ok(val ~ '^[0-9]{1,10}(\.[0-9]{1,2})?$','Invalid amount.');
 elsif k='semester' then perform ssite_mobile.check_ok(val in ('1','2'),'Invalid semester.');
 elsif right(k,5)='_date' then perform ssite_mobile.check_ok(val ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' and val::date::text=val,'Invalid date.');end if;end if;
 params:=params||jsonb_build_object(k,val);end loop;
 f:=ssite_mobile.claim_file('tools/content/'||m||'/save'||case when draft then '/draft' else '' end,b->>'upload_path');
 if draft then
 if f is not null or d.payload->'attachment' is not null then params:=params||jsonb_build_object('attachment',coalesce(f,d.payload->'attachment'));end if;
 if d.id is null then insert into public.content_drafts(id,module,created_by_user_id,payload,lock_version,created_at,updated_at) values(gen_random_uuid(),m,u.id,params,1,now(),now());
 else update public.content_drafts set payload=params,lock_version=lock_version+1,updated_at=now() where id=d.id;
 if f is not null then perform ssite_mobile.retire(d.payload#>>'{attachment,path}','drafts/'||u.id,true);end if;end if;
 else
 perform ssite_mobile.check_ok(f is not null or old->>filekey is not null,'Select an attachment.');
 if f is not null then params:=params||jsonb_build_object(filekey,f->>'path');if ispdf then params:=params||jsonb_build_object('original_name',f->>'original_name','file_size',f->'size');end if;end if;
 if old is null then params:=params||jsonb_build_object('created_by_user_id',u.id,'approval_status',case when ssite_mobile.president(u) and cfg.auto_approve then 'approved' else 'pending' end,'content_status','active');
 if params->>'approval_status'='approved' then params:=params||jsonb_build_object('reviewed_by_user_id',u.id,'reviewed_at',now());end if;
 elsif not ssite_mobile.president(u) and (old->>'approval_status'='rejected' or cfg.reset_on_edit and old->>'approval_status'='approved') then params:=params||'{"approval_status":"pending","reviewed_by_user_id":null,"reviewed_at":null,"rejection_reason":null}';end if;
 saved:=ssite_mobile.write_row(m,params,(old->>'id')::int);
 if old is not null and not exists(select from public.content_versions v where v.post_type=ptype and v.post_id=(old->>'id')::int) then
 insert into public.content_versions(post_type,post_id,editor_user_id,editor_name,kind,snapshot,created_at) values(ptype,(old->>'id')::int,u.id,u.name,'baseline',ssite_mobile.snap(m,old),now());end if;
 if old is null or ssite_mobile.snap(m,old) is distinct from ssite_mobile.snap(m,saved) then insert into public.content_versions(post_type,post_id,editor_user_id,editor_name,kind,snapshot,created_at) values(ptype,(saved->>'id')::int,u.id,u.name,case when old is null then 'created' else 'edited' end,ssite_mobile.snap(m,saved),now());end if;
 if old is null or params->>'approval_status'='pending' then perform ssite_mobile.notice(u,m,saved,case when saved->>'approval_status'='approved' then 'published' else 'submitted' end);end if;
 if d.id is not null then delete from public.content_drafts where id=d.id;perform ssite_mobile.retire(d.payload#>>'{attachment,path}','drafts/'||u.id,true);end if;
 if f is not null and old->>filekey is not null then perform ssite_mobile.retire(old->>filekey,folder,true);if not ispdf then perform ssite_mobile.retire(old->>filekey,m,false);end if;end if;
 end if;
 elsif op='bulk' and array_length(p,1)=4 then
 perform ssite_mobile.check_ok(ssite_mobile.president(u),'President required.');ids:=string_to_array(b->>'post_ids',',')::integer[];perform ssite_mobile.check_ok(cardinality(ids) between 1 and 100,'Select 1 to 100 posts.');
 execute format('update public.%I set content_status=''archived'',updated_at=now() where id=any($1)',m) using ids;get diagnostics n=row_count;perform ssite_mobile.check_ok(n=cardinality(ids),'Selection changed.');
 elsif p[4]='draft' and op='delete' and array_length(p,1)=6 then
 delete from public.content_drafts t where t.id=p[5]::uuid and t.module=m and t.created_by_user_id=u.id returning * into d;perform ssite_mobile.check_ok(d.id is not null,'Draft unavailable.');perform ssite_mobile.retire(d.payload#>>'{attachment,path}','drafts/'||u.id,true);
 else perform ssite_mobile.check_ok(array_length(p,1)=5,'Unknown action.');old:=ssite_mobile.post(m,p[4]::int,true);perform ssite_mobile.check_ok(old is not null and ssite_mobile.editable(u,m,old),'Post unavailable.');
 perform ssite_mobile.check_ok(b->>'updated'=old->>'updated_at','Post changed. Reopen it.');
 if op in ('restore','archive') then perform ssite_mobile.write_row(m,jsonb_build_object('content_status',case op when 'restore' then 'active' else 'archived' end),p[4]::int);
 else perform ssite_mobile.check_ok(ssite_mobile.president(u),'President required.');
 if op='delete' then perform ssite_mobile.check_ok(old->>'content_status'='archived','Archive this post first.');
 delete from public.post_likes where post_type=ptype and post_id=p[4]::int;delete from public.post_views where post_type=ptype and post_id=p[4]::int;
 execute format('delete from public.%I where id=$1',m) using p[4]::int;
 perform ssite_mobile.retire(old->>filekey,folder,true);if not ispdf then perform ssite_mobile.retire(old->>filekey,m,false);end if;
 else perform ssite_mobile.check_ok(op in ('approve','reject') and old->>'approval_status'='pending','Only pending posts can be reviewed.');
 decision:=case op when 'approve' then 'approved' else 'rejected' end;reason:=case op when 'reject' then nullif(trim(b->>'reason'),'') end;
 perform ssite_mobile.check_ok(op<>'reject' or length(reason) between 1 and 255,'Provide a rejection reason.');
 perform ssite_mobile.write_row(m,jsonb_build_object('approval_status',decision,'reviewed_by_user_id',u.id,'reviewed_at',now(),'rejection_reason',reason),p[4]::int);
 insert into public.content_review_events(post_type,post_id,reviewer_user_id,reviewer_name,post_title,decision,reason,created_at) values(ptype,p[4]::int,u.id,u.name,old->>'title',decision,reason,now());
 perform ssite_mobile.notice(u,m,old,decision,reason);if op='approve' and old->>'content_status'='active' then perform ssite_mobile.notice(u,m,old,'published');end if;end if;end if;end if;
 return jsonb_build_object('back','content/'||m);end $$;

