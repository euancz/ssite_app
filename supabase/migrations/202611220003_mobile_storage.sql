create table ssite_mobile.retired_files(bucket text not null,path text not null,actor uuid not null,primary key(bucket,path));
create function ssite_mobile.prepare_file(u public.users,destination text,b jsonb) returns jsonb language plpgsql set search_path='' as $$
declare cfg ssite_mobile.settings%rowtype; f jsonb:=b->'attachment'; raw bytea; parts text[]:=string_to_array(destination,'/');
 folder text; bucket text; filename text; mime text; ext text; m text; is_pdf boolean:=false; key text; purpose text:=destination;
begin
 select * into strict cfg from ssite_mobile.settings;
 perform ssite_mobile.check_ok(exists(select from ssite_mobile.accounts where auth_id=auth.uid()) and ssite_mobile.azure_identity() is not null,'School sign-in required.');
 if destination='profile/complete' or destination='tools/profile/photo' then
 perform ssite_mobile.check_ok((u.id is null)=(destination='profile/complete'),'Invalid profile action.');folder:='profile-pictures';bucket:=cfg.public_bucket;
 elsif parts[1]='tools' and parts[2] in ('roster','sponsors') and array_length(parts,1)=3 then
 perform ssite_mobile.check_ok(ssite_mobile.president(u),'President required.');folder:=case parts[2] when 'roster' then 'officer-photos' else 'sponsor-logos' end;bucket:=cfg.public_bucket;
 elsif parts[1:2]=array['tools','content'] and parts[4]='save' and array_length(parts,1)=4 then
 m:=parts[3];perform ssite_mobile.check_ok(ssite_mobile.allowed(u,m),'No access to module.');bucket:=cfg.private_bucket;is_pdf:=m in ('documents','liquidations');
 if b->>'as_draft'='true' then purpose:=purpose||'/draft';folder:='drafts/'||u.id;
 else folder:=case when is_pdf then case m when 'liquidations' then 'liquidation' else m end else 'post-media/'||m end;end if;
 else raise exception 'Unknown upload.';end if;
 perform ssite_mobile.check_ok(length(f->>'data') between 4 and 14000000,'Attachment too large.');raw:=decode(f->>'data','base64');
 perform ssite_mobile.check_ok(length(raw) between 6 and case when is_pdf then 10485760 else 2097152 end,'Invalid file size.');
 filename:=left(regexp_replace(regexp_replace(coalesce(f->>'name','upload'),'^.*[/\\]',''),'[[:cntrl:]"]','','g'),255);
 if is_pdf then perform ssite_mobile.check_ok(substring(raw for 5)=decode('255044462d','hex') and lower(filename) like '%.pdf','Choose a PDF.');ext:='pdf';mime:='application/pdf';
 elsif substring(raw for 8)=decode('89504e470d0a1a0a','hex') then ext:='png';mime:='image/png';
 elsif substring(raw for 3)=decode('ffd8ff','hex') then ext:='jpg';mime:='image/jpeg';
 else raise exception 'Choose a JPEG or PNG image.';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 perform ssite_mobile.check_ok((select count(*)<30 from ssite_mobile.uploads where auth_id=auth.uid() and created_at>now()-interval '1 hour'),'Too many unfinished uploads. Try again later.');
 key:=folder||'/'||encode(extensions.gen_random_bytes(20),'hex')||'.'||ext;
 insert into ssite_mobile.uploads(path,bucket,auth_id,purpose,digest,size,mime,original_name) values(key,bucket,auth.uid(),purpose,md5(raw),length(raw),mime,filename);
 return jsonb_build_object('path',key,'bucket',bucket,'mime',mime);end $$;

create function ssite_mobile.claim_file(destination text,key text) returns jsonb language plpgsql set search_path='' as $$
declare t ssite_mobile.uploads%rowtype; meta jsonb;
begin if key is null then return null;end if;
 select * into t from ssite_mobile.uploads where auth_id=auth.uid() and path=key and purpose=destination and created_at>now()-interval '1 hour' for update;
 perform ssite_mobile.check_ok(t.path is not null,'Upload expired. Select the file again.');
 select metadata into meta from storage.objects where bucket_id=t.bucket and name=t.path and owner_id=auth.uid()::text;
 perform ssite_mobile.check_ok(trim(both '"' from meta->>'eTag')=t.digest and (meta->>'size')::int=t.size and meta->>'mimetype'=t.mime,'Uploaded file does not match the selected attachment.');
 delete from ssite_mobile.uploads where path=t.path;
 return jsonb_build_object('path',t.path,'type',case when t.mime='application/pdf' then 'pdf' else 'image' end,'original_name',t.original_name,'size',t.size);end $$;

create function ssite_mobile.may_read_file(bucket text,key text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select from ssite_mobile.settings s cross join lateral ssite_mobile.actor() u where u.id is not null and (
 (bucket=s.private_bucket and (exists(select from ssite_mobile.posts p where (p.record->>'file_path'=key or p.record->>'image'=key) and (ssite_mobile.live(p.record) or ssite_mobile.editable(u,p.module,p.record)))
 or exists(select from public.content_drafts d where d.created_by_user_id=u.id and ssite_mobile.allowed(u,d.module) and d.payload#>>'{attachment,path}'=key)))
 or exists(select from ssite_mobile.retired_files t where t.actor=auth.uid() and t.bucket=$1 and t.path=$2)))
 or exists(select from ssite_mobile.uploads t where t.auth_id=auth.uid() and t.bucket=$1 and t.path=$2)
$$;
-- Positional arguments keep the caller's bucket distinct from the ticket's bucket.
create function ssite_mobile.may_upload(text,text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select from ssite_mobile.uploads t where t.bucket=$1 and t.path=$2 and t.auth_id=auth.uid() and t.created_at>now()-interval '1 hour') $$;
create function ssite_mobile.file_used(key text) returns boolean language sql stable set search_path='' as $$
 select exists(select from public.users where profile_picture=key) or exists(select from public.officer_terms where photo=key) or exists(select from public.sponsors where logo_path=key) or exists(select from ssite_mobile.posts where record->>'image'=key or record->>'file_path'=key) or exists(select from public.content_drafts where payload#>>'{attachment,path}'=key)
$$;
create function ssite_mobile.may_delete(text,text) returns boolean language sql stable security definer set search_path='' as $$
 select (exists(select from ssite_mobile.retired_files t where t.actor=auth.uid() and t.bucket=$1 and t.path=$2) or exists(select from ssite_mobile.uploads t where t.auth_id=auth.uid() and t.bucket=$1 and t.path=$2)) and not ssite_mobile.file_used($2) $$;
create function ssite_mobile.retire(key text,folder text,private_file boolean) returns void language plpgsql set search_path='' as $$
begin if key like folder||'/%' and not ssite_mobile.file_used(key) then
 insert into ssite_mobile.retired_files select case when private_file then private_bucket else public_bucket end,key,auth.uid() from ssite_mobile.settings on conflict do nothing;
 end if;end $$;
revoke all on all functions in schema ssite_mobile from public,anon,authenticated;
grant usage on schema ssite_mobile to authenticated;
grant execute on function ssite_mobile.may_read_file(text,text),ssite_mobile.may_upload(text,text),ssite_mobile.may_delete(text,text) to authenticated;
create policy ssite_app_files_read on storage.objects for select to authenticated using(ssite_mobile.may_read_file(bucket_id,name));
create policy ssite_app_files_create on storage.objects for insert to authenticated with check(ssite_mobile.may_upload(bucket_id,name));
create policy ssite_app_files_delete on storage.objects for delete to authenticated using(ssite_mobile.may_delete(bucket_id,name));

