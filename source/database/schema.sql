-- travel_club_private_foundation

create schema if not exists club_private;
revoke all on schema club_private from public, anon;
grant usage on schema club_private to authenticated;

create table public.club_members (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check (char_length(display_name) between 1 and 80),
 active boolean not null default true,
 joined_at timestamptz not null default now()
);
alter table public.club_members enable row level security;

create function club_private.is_member() returns boolean
language sql stable security definer set search_path = ''
as $$ select auth.uid() is not null and exists(select 1 from public.club_members where user_id=auth.uid() and active); $$;
revoke all on function club_private.is_member() from public, anon;
grant execute on function club_private.is_member() to authenticated;

create table public.trips(
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null default auth.uid() references public.club_members(user_id),
 title text not null check(char_length(title) between 1 and 140),
 place text not null default '' check(char_length(place)<=120),
 body text not null check(char_length(body) between 1 and 30000),
 created_at timestamptz not null default now()
);
create index trips_author_id_idx on public.trips(author_id);
create index trips_created_at_idx on public.trips(created_at desc);
alter table public.trips enable row level security;

create table public.trip_photos(
 id uuid primary key default gen_random_uuid(),
 trip_id uuid not null references public.trips(id) on delete cascade,
 uploader_id uuid not null default auth.uid() references public.club_members(user_id),
 object_path text unique not null,
 position integer not null check(position between 0 and 11),
 created_at timestamptz not null default now(),
 unique(trip_id,position)
);
create index trip_photos_uploader_id_idx on public.trip_photos(uploader_id);
alter table public.trip_photos enable row level security;

create table public.trip_comments(
 id uuid primary key default gen_random_uuid(),
 trip_id uuid not null references public.trips(id) on delete cascade,
 author_id uuid not null default auth.uid() references public.club_members(user_id),
 body text not null check(char_length(body) between 1 and 4000),
 created_at timestamptz not null default now()
);
create index trip_comments_trip_created_idx on public.trip_comments(trip_id,created_at);
create index trip_comments_author_id_idx on public.trip_comments(author_id);
alter table public.trip_comments enable row level security;

create table club_private.invitations(
 id uuid primary key default gen_random_uuid(),
 token_hash text not null unique,
 email text not null,
 created_by uuid references public.club_members(user_id),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '7 days',
 used_at timestamptz,
 used_by uuid references auth.users(id),
 revoked boolean not null default false
);
alter table club_private.invitations enable row level security;
create index invitations_creator_idx on club_private.invitations(created_by);
create index invitations_used_by_idx on club_private.invitations(used_by);
revoke all on club_private.invitations from public,anon,authenticated;

grant select on public.club_members to authenticated;
grant select,insert,delete on public.trips,public.trip_photos,public.trip_comments to authenticated;
grant update(title,place,body) on public.trips to authenticated;
grant update(body) on public.trip_comments to authenticated;
revoke all on public.club_members,public.trips,public.trip_photos,public.trip_comments from anon;

create policy members_read on public.club_members for select to authenticated using((select club_private.is_member()));
create policy trips_read on public.trips for select to authenticated using((select club_private.is_member()));
create policy trips_create on public.trips for insert to authenticated with check((select club_private.is_member()) and author_id=(select auth.uid()));
create policy trips_update on public.trips for update to authenticated using((select club_private.is_member()) and author_id=(select auth.uid())) with check((select club_private.is_member()) and author_id=(select auth.uid()));
create policy trips_delete on public.trips for delete to authenticated using((select club_private.is_member()) and author_id=(select auth.uid()));
create policy photos_read on public.trip_photos for select to authenticated using((select club_private.is_member()));
create policy photos_create on public.trip_photos for insert to authenticated with check(
 (select club_private.is_member()) and uploader_id=(select auth.uid())
 and object_path like (select auth.uid())::text || '/' || trip_id::text || '/%'
 and exists(select 1 from public.trips t where t.id=trip_id and t.author_id=(select auth.uid()))
);
create policy photos_delete on public.trip_photos for delete to authenticated using((select club_private.is_member()) and uploader_id=(select auth.uid()));
create policy comments_read on public.trip_comments for select to authenticated using((select club_private.is_member()));
create policy comments_create on public.trip_comments for insert to authenticated with check((select club_private.is_member()) and author_id=(select auth.uid()) and exists(select 1 from public.trips where id=trip_id));
create policy comments_update on public.trip_comments for update to authenticated using((select club_private.is_member()) and author_id=(select auth.uid())) with check((select club_private.is_member()) and author_id=(select auth.uid()));
create policy comments_delete on public.trip_comments for delete to authenticated using((select club_private.is_member()) and author_id=(select auth.uid()));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('travel-photos','travel-photos',false,10485760,array['image/jpeg','image/png','image/webp']);
create policy club_photo_read on storage.objects for select to authenticated using(bucket_id='travel-photos' and (select club_private.is_member()));
create policy club_photo_insert on storage.objects for insert to authenticated with check(
 bucket_id='travel-photos' and (select club_private.is_member())
 and (storage.foldername(name))[1]=(select auth.uid())::text
 and exists(select 1 from public.trips t where t.id::text=(storage.foldername(name))[2] and t.author_id=(select auth.uid()))
);
create policy club_photo_delete on storage.objects for delete to authenticated using(
 bucket_id='travel-photos' and (select club_private.is_member()) and (storage.foldername(name))[1]=(select auth.uid())::text
);


-- invite_only_registration

create function club_private.create_invitation(recipient_email text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare token text; invitation_id uuid; target text:=lower(trim(recipient_email)); expiry timestamptz:=now()+interval '7 days';
begin
 if auth.uid() is null or not club_private.is_member() then raise exception 'Membership required'; end if;
 if target is null or char_length(target)>254 or target !~ '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$' then raise exception 'Invalid email'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 if (select count(*) from club_private.invitations where created_by=auth.uid() and created_at>now()-interval '1 hour')>=20 then raise exception 'Too many invitations'; end if;
 token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
 insert into club_private.invitations(token_hash,email,created_by,expires_at)
 values(encode(sha256(convert_to(token,'UTF8')),'hex'),target,auth.uid(),expiry) returning id into invitation_id;
 return jsonb_build_object('id',invitation_id,'token',token,'email',target,'expires_at',expiry);
end; $$;
revoke all on function club_private.create_invitation(text) from public,anon;
grant execute on function club_private.create_invitation(text) to authenticated;
create function public.create_club_invitation(recipient_email text) returns jsonb language sql security invoker set search_path='' as $$ select club_private.create_invitation(recipient_email); $$;
revoke all on function public.create_club_invitation(text) from public,anon;
grant execute on function public.create_club_invitation(text) to authenticated;

create function club_private.register_invited_member() returns trigger language plpgsql security definer set search_path='' as $$
declare inv club_private.invitations%rowtype; token text:=new.raw_user_meta_data->>'invitation_token'; chosen_name text;
begin
 if token is null or char_length(token)<>64 or new.email is null then raise exception 'A valid invitation is required'; end if;
 select * into inv from club_private.invitations where token_hash=encode(sha256(convert_to(token,'UTF8')),'hex') for update;
 if not found or inv.used_at is not null or inv.revoked or inv.expires_at<=now() or inv.email<>lower(new.email) then raise exception 'Invitation is invalid or expired'; end if;
 if inv.created_by is not null and not exists(select 1 from public.club_members where user_id=inv.created_by and active) then raise exception 'Inviter is no longer active'; end if;
 chosen_name:=trim(coalesce(new.raw_user_meta_data->>'display_name',''));
 if char_length(chosen_name) not between 1 and 80 then raise exception 'Display name is required'; end if;
 insert into public.club_members(user_id,display_name) values(new.id,chosen_name);
 update club_private.invitations set used_at=now(),used_by=new.id where id=inv.id;
 update auth.users set raw_user_meta_data=raw_user_meta_data-'invitation_token' where id=new.id;
 return new;
end; $$;
revoke all on function club_private.register_invited_member() from public,anon,authenticated;
create trigger club_invitation_required after insert on auth.users for each row execute function club_private.register_invited_member();

