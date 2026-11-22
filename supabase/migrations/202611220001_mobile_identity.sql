-- PostgREST exposes the public RPCs. The implementation schema and its tables
-- are private. The Laravel source tables retain their existing access policies.
create extension if not exists http with schema extensions;
create schema if not exists ssite_mobile;
revoke all on schema ssite_mobile from public, anon, authenticated;
alter default privileges in schema ssite_mobile revoke execute on functions from public;

create table ssite_mobile.settings (
  singleton boolean primary key default true check(singleton),
  tenant uuid not null, school_domain text not null,
  private_bucket text not null, public_bucket text not null,
  website_url text, auto_approve boolean not null default true,
  reset_on_edit boolean not null default true, likes boolean not null default true,
  views boolean not null default true
);
create table ssite_mobile.accounts (
  auth_id uuid primary key references auth.users(id) on delete cascade,
  microsoft_id text not null unique, email text not null, display_name text not null
);
create table ssite_mobile.uploads (
  path text primary key, bucket text not null, auth_id uuid not null references auth.users(id) on delete cascade,
  purpose text not null, digest text not null, size integer not null, mime text not null,
  original_name text not null, created_at timestamptz not null default now()
);
create index on ssite_mobile.uploads(auth_id,created_at);

create function ssite_mobile.check_ok(ok boolean, msg text) returns void language plpgsql as $$
begin if ok is not true then raise exception using errcode='P0001',message=msg; end if; end $$;

create function ssite_mobile.azure_identity() returns jsonb language sql stable security definer set search_path='' as $$
 select i.identity_data from auth.identities i join auth.users u on u.id=i.user_id
 join ssite_mobile.settings s on s.singleton
 where u.id=auth.uid() and i.provider='azure' and u.raw_app_meta_data->>'provider'='azure'
 and i.identity_data->>'email_verified'='true' and u.email_confirmed_at is not null
 and lower(i.identity_data->>'email')=lower(u.email)
 and lower(split_part(u.email,'@',2))=lower(s.school_domain)
 and lower(i.identity_data#>>'{custom_claims,tid}')=s.tenant::text limit 1
$$;
create function public.ssite_app_link(provider_token text) returns void language plpgsql security definer set search_path='' as $$
declare identity jsonb:=ssite_mobile.azure_identity(); r extensions.http_response; profile jsonb; mail text; mid text; account public.users%rowtype;
begin
 perform ssite_mobile.check_ok(identity is not null,'Sign in with your school Microsoft account.');
 if exists(select from ssite_mobile.accounts where auth_id=auth.uid()) then return; end if;
 perform ssite_mobile.check_ok(length(provider_token) between 16 and 16000 and provider_token !~ '[[:space:][:cntrl:]]','Please sign in with Microsoft again.');
 select * into r from extensions.http(('GET','https://graph.microsoft.com/v1.0/me?$select=id,mail,userPrincipalName,displayName',array[extensions.http_header('Authorization','Bearer '||provider_token)],null,null)::extensions.http_request);
 perform ssite_mobile.check_ok(r.status=200,'Microsoft identity could not be verified. Sign in again.');
 profile:=r.content::jsonb; mid:=profile->>'id';
 mail:=lower(coalesce(nullif(profile->>'mail',''),profile->>'userPrincipalName'));
 perform ssite_mobile.check_ok(mid ~* '^[0-9a-f-]{36}$' and mail=lower(identity->>'email'),'Microsoft account mismatch.');
 select * into account from public.users where microsoft_id=mid or lower(email)=mail order by (microsoft_id=mid) desc nulls last limit 1 for update;
 perform ssite_mobile.check_ok(not exists(select from public.users where lower(email)=mail and microsoft_id is not null and microsoft_id<>mid),'School email is linked to another account.');
 if account.id is not null and account.microsoft_id is null and account.profile_completed_at is not null then
   update public.users set microsoft_id=mid where id=account.id and microsoft_id is null;
 end if;
 insert into ssite_mobile.accounts values(auth.uid(),mid,mail,left(coalesce(profile->>'displayName','Member'),255));
end $$;
revoke all on function public.ssite_app_link(text) from public,anon;
grant execute on function public.ssite_app_link(text) to authenticated;

create function ssite_mobile.actor() returns public.users language sql stable security definer set search_path='' as $$
 select u from public.users u join ssite_mobile.accounts a on a.microsoft_id=u.microsoft_id
 where a.auth_id=auth.uid() and ssite_mobile.azure_identity() is not null and u.profile_completed_at is not null
$$;
create function ssite_mobile.modules() returns text[] language sql immutable as $$
 select array['articles','activities','achievements','documents','liquidations']::text[] $$;
create function ssite_mobile.kind(m text) returns text language sql immutable as $$
 select (array['article','activity','achievement','document','liquidation'])[array_position(ssite_mobile.modules(),m)] $$;
create function ssite_mobile.allowed(u public.users,m text) returns boolean language sql immutable as $$
 select coalesce(u.role='officer' and m=any(case lower(trim(u.officer_position))
 when 'president' then ssite_mobile.modules() when 'secretary' then array['documents']
 when 'auditor' then array['liquidations'] when 'social media manager' then array['articles','achievements','activities'] else array[]::text[] end),false) $$;
create function ssite_mobile.president(u public.users) returns boolean language sql immutable as $$
 select coalesce(u.role='officer' and lower(trim(u.officer_position))='president',false) $$;
create function ssite_mobile.year_ok(y text) returns boolean language sql immutable as $$
 select case when y ~ '^[0-9]{4}-[0-9]{4}$' then right(y,4)::int=left(y,4)::int+1 else false end $$;
create function ssite_mobile.post(m text,k integer,locked boolean default false) returns jsonb language plpgsql as $$
declare r jsonb; begin perform ssite_mobile.check_ok(m=any(ssite_mobile.modules()),'Unknown module.');
 execute format('select to_jsonb(p) from public.%I p where id=$1%s',m,case when locked then ' for update' else '' end) into r using k;return r;end $$;
create function ssite_mobile.live(p jsonb) returns boolean language sql immutable as $$
 select p->>'approval_status'='approved' and p->>'content_status'='active' $$;
create function ssite_mobile.editable(u public.users,m text,p jsonb) returns boolean language sql immutable as $$
 select ssite_mobile.allowed(u,m) and (ssite_mobile.president(u) or (p->>'created_by_user_id')::int=u.id) $$;

create view ssite_mobile.posts as
select 'articles'::text module,to_jsonb(p) record from public.articles p union all
select 'activities',to_jsonb(p) from public.activities p union all
select 'achievements',to_jsonb(p) from public.achievements p union all
select 'documents',to_jsonb(p) from public.documents p union all
select 'liquidations',to_jsonb(p) from public.liquidations p;

