-- LAND METRICS update 4: terms acceptance, push tokens, account deletion (run once)
alter table profiles add column if not exists terms_version text;
alter table profiles add column if not exists terms_accepted_at timestamptz;

create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,full_name,phone,terms_version,terms_accepted_at)
  values(new.id,new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'phone',new.raw_user_meta_data->>'terms_version',nullif(new.raw_user_meta_data->>'terms_accepted_at','')::timestamptz)
  on conflict (id) do nothing;
  return new;
end $$;

-- push notification device tokens
create table if not exists device_tokens(token text primary key, user_id uuid not null references profiles on delete cascade, platform text, updated_at timestamptz default now());
alter table device_tokens enable row level security;
create policy t1 on device_tokens for select to authenticated using(user_id=auth.uid());
create policy t2 on device_tokens for delete to authenticated using(user_id=auth.uid());
create or replace function register_device(t text,p text) returns void language sql security definer set search_path=public as $$
  insert into device_tokens(token,user_id,platform) values(t,auth.uid(),p)
  on conflict (token) do update set user_id=auth.uid(), platform=p, updated_at=now() $$;

-- users can remove their own uploaded files
create policy o3 on storage.objects for delete to authenticated using(bucket_id in('land-images','request-docs') and (storage.foldername(name))[1]=auth.uid()::text);

-- in-app account deletion: removes personal data, keeps anonymised financial records
create or replace function delete_my_account() returns void language plpgsql security definer set search_path=public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  if exists(select 1 from profiles where id=uid and role='admin') then raise exception 'admin accounts cannot be deleted here'; end if;
  delete from messages where thread_user=uid;
  delete from notifications where user_id=uid;
  delete from requests where user_id=uid;
  delete from device_tokens where user_id=uid;
  update lands set status='rejected' where seller_id=uid and status in('pending','approved','live');
  update profiles set full_name='Deleted user', phone=null, avatar_url=null where id=uid;
  delete from auth.identities where user_id=uid;
  delete from auth.sessions where user_id=uid;
  update auth.users set email='deleted-'||uid::text||'@deleted.invalid', phone=null, encrypted_password='', banned_until='infinity', raw_user_meta_data='{}'::jsonb where id=uid;
end $$;
revoke execute on function delete_my_account() from public, anon;
grant execute on function delete_my_account() to authenticated;
revoke execute on function register_device(text,text) from public, anon;
grant execute on function register_device(text,text) to authenticated;
