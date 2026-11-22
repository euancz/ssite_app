create function public.ssite_app_write(route text, body jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare u public.users:=ssite_mobile.actor(); a ssite_mobile.accounts%rowtype; target public.users%rowtype; cfg ssite_mobile.settings%rowtype; p text[]:=string_to_array(route,'/');
 k text:=p[2]; m text:=p[3]; op text:=p[array_length(p,1)]; f jsonb; old jsonb; v jsonb; back text; t text; id int; post jsonb; typ text; n int; liked boolean;
 position text; new_role text; yr text; oldyr text; roster boolean; prior text; photo_key text; folder text; orderno int; linked public.users%rowtype;
begin
 select * into a from ssite_mobile.accounts where auth_id=auth.uid();
 perform ssite_mobile.check_ok(a.auth_id is not null and ssite_mobile.azure_identity() is not null,'School Microsoft sign-in required.');
 select * into strict cfg from ssite_mobile.settings;
 if p[1]='prepare' then return ssite_mobile.prepare_file(u,substr(route,9),body);end if;
 if route='profile/complete' then
 perform ssite_mobile.check_ok(u.id is null and body->>'accept'='true','Accept the terms to complete your profile.');
 f:=ssite_mobile.claim_file(route,body->>'upload_path');perform ssite_mobile.check_ok(f is not null,'Choose a profile photo.');
 select * into target from public.users where microsoft_id=a.microsoft_id or lower(email)=a.email order by (microsoft_id=a.microsoft_id) desc nulls last limit 1 for update;
 perform ssite_mobile.check_ok(target.id is null or target.profile_completed_at is null and (target.microsoft_id is null or target.microsoft_id=a.microsoft_id),'Account changed. Sign in again.');
 if target.id is null then insert into public.users(name,email,microsoft_id,role,password,profile_picture,profile_completed_at,profile_policies_accepted_at,created_at,updated_at)
 values(a.display_name,a.email,a.microsoft_id,'student',encode(extensions.gen_random_bytes(32),'hex'),f->>'path',now(),now(),now(),now());
 else update public.users set microsoft_id=a.microsoft_id,profile_picture=f->>'path',profile_completed_at=now(),profile_policies_accepted_at=now(),updated_at=now() where users.id=target.id;end if;return '{"ok":true}';end if;
 perform ssite_mobile.check_ok(u.id is not null,'Complete your profile.');
 if p[1:2]=array['tools','users'] then perform ssite_mobile.check_ok(u.role in ('admin','adviser'),'Permission denied.');perform idref.id from public.users idref order by idref.id for update;end if;
 select * into strict u from public.users z where z.microsoft_id=a.microsoft_id and z.profile_completed_at is not null for share;
 if route='files/cleanup' then
 delete from ssite_mobile.retired_files r where actor=auth.uid() and not exists(select from storage.objects o where o.bucket_id=r.bucket and o.name=r.path);
 delete from ssite_mobile.uploads t where t.auth_id=auth.uid() and t.created_at<now()-interval '1 hour' and not exists(select from storage.objects o where o.bucket_id=t.bucket and o.name=t.path);
 return jsonb_build_object('files',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select bucket,path from ssite_mobile.retired_files where actor=auth.uid() union all select bucket,path from ssite_mobile.uploads where auth_id=auth.uid() and created_at<now()-interval '1 hour' limit 50)x));end if;
 if p[1]='engagement' then m:=p[2];id:=p[3]::int;typ:=ssite_mobile.kind(m);post:=ssite_mobile.post(m,id,true);perform ssite_mobile.check_ok(ssite_mobile.live(post),'Post unavailable.');
 if op='view' and cfg.views then insert into public.post_views(post_type,post_id,user_id,created_at) values(typ,id,u.id,now()) on conflict do nothing;get diagnostics n=row_count;
 if n=1 then execute format('update public.%I set view_count=view_count+1 where id=$1',m) using id;end if;
 elsif op='like' then perform ssite_mobile.check_ok(cfg.likes,'Likes disabled.');
 delete from public.post_likes l where l.post_type=typ and l.post_id=p[3]::int and l.user_id=u.id;get diagnostics n=row_count;liked:=n=0;
 if liked then insert into public.post_likes(post_type,post_id,user_id,created_at) values(typ,id,u.id,now());if (post->>'created_by_user_id')::int<>u.id then perform ssite_mobile.notice(u,m,post,'liked');end if;end if;
 execute format('update public.%I set like_count=greatest(0,like_count+$1) where id=$2',m) using case when liked then 1 else -1 end,id;
 else perform ssite_mobile.check_ok(op='view','Unknown action.');end if;
 post:=ssite_mobile.post(m,id);return jsonb_build_object('view_count',post->'view_count','like_count',post->'like_count','liked_by_viewer',liked);end if;
 perform ssite_mobile.check_ok(p[1]='tools','Unknown action.');
 if k='content' then return ssite_mobile.content_write(u,m,p,body);end if;
 if k='profile' then perform ssite_mobile.check_ok(op in ('photo','remove'),'Unknown profile action.');
 if op='photo' then f:=ssite_mobile.claim_file(route,body->>'upload_path');perform ssite_mobile.check_ok(f is not null,'Choose a photo.');end if;
 update public.users set profile_picture=f->>'path',updated_at=now() where users.id=u.id;
 perform ssite_mobile.retire(u.profile_picture,'profile-pictures',false);
 elsif k='notifications' then
 if op='read-all' then update public.notifications set read_at=now(),updated_at=now() where notifiable_type=E'App\\Models\\User' and notifiable_id=u.id and read_at is null;
 elsif op='read' then update public.notifications set read_at=coalesce(read_at,now()),updated_at=now() where notifications.id=p[3]::uuid and notifiable_type=E'App\\Models\\User' and notifiable_id=u.id;
 elsif op='delete' then delete from public.notifications where notifications.id=p[3]::uuid and notifiable_type=E'App\\Models\\User' and notifiable_id=u.id;
 else raise exception 'Unknown action.';end if;
 elsif k='users' then
 select * into target from public.users z where z.id=m::int;
 new_role:=body->>'role';position:=case when new_role='officer' then body->>'position' end;
 perform ssite_mobile.check_ok(target.id<>u.id and
 (u.role='adviser' and target.role in ('student','officer') and new_role in ('student','officer')
 or u.role='admin' and (target.role='adviser' and new_role='student' or target.role in ('student','officer') and new_role='adviser')),'Role change unavailable.');
 perform ssite_mobile.check_ok(new_role<>'officer' or position in ('President','Secretary','Auditor','Social Media Manager'),'Unknown officer position.');
 perform ssite_mobile.check_ok(position is distinct from 'President' or not exists(select from public.users z where z.id<>target.id and ssite_mobile.president(z)),'President already assigned.');
 update public.users set role=new_role,officer_position=position,updated_at=now() where users.id=target.id;
 insert into public.role_changes(user_id,changed_by_user_id,old_role,new_role,old_officer_position,new_officer_position,created_at,updated_at) values(target.id,u.id,target.role,new_role,target.officer_position,position,now(),now());
 elsif k in ('roster','sponsors') then
 perform ssite_mobile.check_ok(ssite_mobile.president(u),'President required.');roster:=k='roster';t:=case when roster then 'officer_terms' else 'sponsors' end;photo_key:=case when roster then 'photo' else 'logo_path' end;folder:=case when roster then 'officer-photos' else 'sponsor-logos' end;
 if roster and op='copy' then yr:=body->>'academic_year';perform ssite_mobile.check_ok(ssite_mobile.year_ok(yr),'Invalid academic year.');oldyr:=(left(yr,4)::int-1)||'-'||left(yr,4);
 lock table public.officer_terms in share row exclusive mode;
 insert into public.officer_terms(academic_year,name,position,user_id,photo,sort_order,created_at,updated_at)
 select yr,x.name,x.position,x.user_id,x.photo,x.sort_order,now(),now() from public.officer_terms x where x.academic_year=oldyr and not exists(select from public.officer_terms y where y.academic_year=yr and (y.user_id=x.user_id or x.user_id is null and y.user_id is null and y.name=x.name and y.position=x.position));
 else id:=nullif(m,'new')::int;if id is not null then execute format('select to_jsonb(z) from public.%I z where z.id=$1 for update',t) into old using id;perform ssite_mobile.check_ok(old is not null,'Entry unavailable.');end if;
 if op='delete' then execute format('delete from public.%I where id=$1',t) using id;
 else orderno:=(body->>'sort_order')::int;perform ssite_mobile.check_ok(orderno between 0 and case when roster then 255 else 65535 end and length(trim(body->>'name')) between 1 and case when roster then 100 else 255 end,'Check name and sort order.');
 v:=jsonb_build_object('name',trim(body->>'name'),'sort_order',orderno);
 if roster then yr:=body->>'academic_year';position:=body->>'position';
 perform ssite_mobile.check_ok(ssite_mobile.year_ok(yr) and position in ('Adviser','Student Adviser','President','Vice President (Internal)','Vice President (External)','Secretary','Treasurer','Auditor','Public Information Officer','Business Manager','Social Media Manager','Social Media Manager (Creative)','Social Media Manager (Documentation)','IT Representative I','IT Representative II'),'Check year and position.');
 v:=v||jsonb_build_object('position',position,'academic_year',yr,'user_id',nullif(body->>'user_id','')::int);
 if v->>'user_id' is not null then select * into linked from public.users z where z.id=(v->>'user_id')::int and z.role in ('student','officer');perform ssite_mobile.check_ok(linked.id is not null,'Unknown member.');if old->>'photo' is null or v->>'user_id' is distinct from old->>'user_id' then v:=v||jsonb_build_object('photo',linked.profile_picture);end if;end if;
 else perform ssite_mobile.check_ok(length(trim(body->>'description')) between 1 and 2000 and (nullif(body->>'website_url','') is null or (body->>'website_url' ~* '^https?://[^/[:space:]]+' and length(body->>'website_url')<=2048)),'Check description and URL.');
 v:=v||jsonb_build_object('description',trim(body->>'description'),'website_url',nullif(trim(body->>'website_url'),''),'is_active',body->>'is_active'='true');
 if body->>'remove_logo'='true' then v:=v||'{"logo_path":null}';end if;end if;
 f:=ssite_mobile.claim_file(route,body->>'upload_path');if f is not null then v:=v||jsonb_build_object(photo_key,f->>'path');end if;perform ssite_mobile.write_row(t,v,id);end if;
 perform ssite_mobile.retire(old->>photo_key,folder,false);end if;
 else raise exception 'Unknown action.';end if;return jsonb_build_object('back',k);end $$;
revoke all on function public.ssite_app_write(text,jsonb) from public,anon;
grant execute on function public.ssite_app_write(text,jsonb) to authenticated;
-- Internal functions run only through the guarded RPCs and the three Storage policies.
revoke all on all tables in schema ssite_mobile from public,anon,authenticated;
revoke execute on all functions in schema ssite_mobile from public,anon,authenticated;
grant execute on function ssite_mobile.may_read_file(text,text),ssite_mobile.may_upload(text,text),ssite_mobile.may_delete(text,text) to authenticated;
notify pgrst,'reload schema';

