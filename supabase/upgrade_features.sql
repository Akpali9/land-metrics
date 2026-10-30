-- LAND METRICS feature upgrade. Run in Supabase SQL Editor AFTER schema.sql.
alter table public.profiles add column if not exists avatar_url text;
alter table public.lands add column if not exists documents text[] not null default '{}';
alter table public.profiles add column if not exists is_blocked boolean not null default false;
alter table public.requests add column if not exists attachments text[] not null default '{}';
alter table public.payments add column if not exists bank_name_snapshot text;
alter table public.payments add column if not exists account_name_snapshot text;
alter table public.payments add column if not exists account_number_snapshot text;
alter table public.messages add column if not exists attachment_path text;
alter table public.messages add column if not exists attachment_name text;
alter table public.notifications add column if not exists user_id uuid references auth.users(id) on delete cascade;

create table if not exists public.password_reset_requests (
 id bigint generated always as identity primary key,
 user_id uuid references auth.users(id) on delete set null default auth.uid(),
 email text not null,
 phone text,
 status text not null default 'open' check(status in ('open','contacted','closed')),
 created_at timestamptz not null default now()
);
alter table public.password_reset_requests enable row level security;
grant select, insert, update on public.password_reset_requests to anon, authenticated;
grant usage, select on sequence public.password_reset_requests_id_seq to anon, authenticated;
drop policy if exists reset_insert_self on public.password_reset_requests;
create policy reset_insert_self on public.password_reset_requests for insert to anon, authenticated with check (user_id is null or user_id=auth.uid());
drop policy if exists reset_admin_read on public.password_reset_requests;
create policy reset_admin_read on public.password_reset_requests for select to authenticated using (is_admin());
drop policy if exists reset_admin_update on public.password_reset_requests;
create policy reset_admin_update on public.password_reset_requests for update to authenticated using (is_admin()) with check (is_admin());

-- Profiles: users may edit their own contact/profile fields, never role or block state.
drop policy if exists profile_update_self on public.profiles;
create policy profile_update_self on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());
drop policy if exists profile_admin_update on public.profiles;
create policy profile_admin_update on public.profiles for update to authenticated using (is_admin()) with check (is_admin());
create or replace function protect_profile_privileges() returns trigger language plpgsql security definer as $$
begin
 if auth.uid() is not null and not is_admin() then
   new.role := old.role;
   new.is_blocked := old.is_blocked;
 end if;
 return new;
end $$;
drop trigger if exists protect_profile_privileges_trigger on public.profiles;
create trigger protect_profile_privileges_trigger before update on public.profiles for each row execute function protect_profile_privileges();

-- Only admins may change the payment destination; snapshots preserve the destination shown to the payer.
drop policy if exists settings_admin_update on public.settings;
create policy settings_admin_update on public.settings for update to authenticated using (is_admin()) with check (is_admin());
drop policy if exists settings_admin_insert on public.settings;
create policy settings_admin_insert on public.settings for insert to authenticated with check (is_admin());

-- Notifications may be global (user_id NULL) or targeted to one account.
drop policy if exists n1 on public.notifications;\ndrop policy if exists notifications_visible on public.notifications;
create policy notifications_visible on public.notifications for select to authenticated using (user_id is null or user_id=auth.uid() or is_admin());
drop policy if exists notifications_admin_insert on public.notifications;
create policy notifications_admin_insert on public.notifications for insert to authenticated with check (is_admin());

-- Private bucket for title documents, survey plans, construction drawings and chat attachments.
insert into storage.buckets(id,name,public) values('land-documents','land-documents',false) on conflict (id) do nothing;
drop policy if exists land_docs_insert on storage.objects;
create policy land_docs_insert on storage.objects for insert to authenticated with check (bucket_id='land-documents' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists land_docs_read on storage.objects;
create policy land_docs_read on storage.objects for select to authenticated using (
 bucket_id='land-documents' and (
   (storage.foldername(name))[1]=auth.uid()::text
   or is_admin()
   or exists(select 1 from public.messages m where m.attachment_path=storage.objects.name and m.thread_user=auth.uid())
 )
);
drop policy if exists land_docs_delete on storage.objects;
create policy land_docs_delete on storage.objects for delete to authenticated using (bucket_id='land-documents' and ((storage.foldername(name))[1]=auth.uid()::text or is_admin()));

-- Blocked accounts are rejected by the app gate. Enforce server-side access as well.
create or replace function reject_blocked_user() returns trigger language plpgsql security definer as $$
begin
 if exists(select 1 from profiles where id=auth.uid() and is_blocked=true) and not is_admin() then
   raise exception 'This account is blocked. Contact support.';
 end if;
 return new;
end $$;
drop trigger if exists blocked_lands_insert on public.lands;
create trigger blocked_lands_insert before insert on public.lands for each row execute function reject_blocked_user();
drop trigger if exists blocked_payments_insert on public.payments;
create trigger blocked_payments_insert before insert on public.payments for each row execute function reject_blocked_user();
drop trigger if exists blocked_requests_insert on public.requests;
create trigger blocked_requests_insert before insert on public.requests for each row execute function reject_blocked_user();
drop trigger if exists blocked_messages_insert on public.messages;
create trigger blocked_messages_insert before insert on public.messages for each row execute function reject_blocked_user();

-- Admin can inspect documents through signed URLs; keep bucket private.

-- Realtime in-app notifications.
do $$ begin alter publication supabase_realtime add table public.notifications; exception when duplicate_object then null; end $$;

-- Admins can delete public announcements (global notifications only).
drop policy if exists notifications_admin_delete on public.notifications;
create policy notifications_admin_delete on public.notifications
for delete to authenticated using (is_admin() and user_id is null);
