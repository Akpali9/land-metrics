-- LAND METRICS update 2: notifications, profile pictures, property details, construction documents.
-- Run once in Supabase > SQL Editor (after schema.sql / update.sql).

alter table profiles add column if not exists avatar_url text;
alter table profiles add column if not exists notif_seen_at timestamptz default now();
alter table lands add column if not exists details jsonb default '{}';
alter table requests add column if not exists documents jsonb default '[]';
alter table notifications add column if not exists user_id uuid references profiles on delete cascade;
alter table notifications add column if not exists title text;

-- admin sign-up by code is removed
drop function if exists claim_admin(text);

-- users may edit their own profile, but never their role
create policy p2 on profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create or replace function protect_role() returns trigger language plpgsql as $$
begin if current_user='authenticated' and new.role is distinct from old.role then new.role:=old.role; end if; return new; end $$;
drop trigger if exists keep_role on profiles;
create trigger keep_role before update on profiles for each row execute function protect_role();

-- notifications: personal ones + broadcasts to sellers
drop policy if exists n1 on notifications;
create policy n1 on notifications for select to authenticated using(
  is_admin() or user_id=auth.uid() or (user_id is null and exists(select 1 from lands where seller_id=auth.uid())));
alter publication supabase_realtime add table notifications;

create or replace function notify_user(uid uuid,t text,b text) returns void language sql security definer set search_path=public as $$
  insert into notifications(user_id,title,body) values(uid,t,b) $$;
revoke execute on function notify_user(uuid,text,text) from public,anon,authenticated;

create or replace function trg_land() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status is distinct from old.status and new.status in('approved','live','rejected') then
    perform notify_user(new.seller_id,'Listing update', case new.status
      when 'approved' then '"'||new.title||'" was confirmed. Pay the subscription to make it live.'
      when 'live' then '"'||new.title||'" is now live for buyers.'
      else '"'||new.title||'" was not approved. Contact support for details.' end);
  end if; return new; end $$;
drop trigger if exists land_notify on lands;
create trigger land_notify after update on lands for each row execute function trg_land();

create or replace function trg_pay() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status is distinct from old.status then
    perform notify_user(new.user_id,'Payment '||new.status, case when new.status='verified'
      then 'Your payment of ₦'||to_char(new.amount,'FM999,999,999,990')||' was verified.'
      else 'Your payment was rejected. Please contact support.' end);
  end if; return new; end $$;
drop trigger if exists pay_notify on payments;
create trigger pay_notify after update on payments for each row execute function trg_pay();

create or replace function trg_sale() returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform notify_user(new.seller_id,'Your land sold','You receive ₦'||to_char(new.seller_net,'FM999,999,999,990')||' after the 10% fee.');
  perform notify_user(new.buyer_id,'Purchase confirmed','Your purchase is confirmed. Our team will contact you about the documents.');
  return new; end $$;
drop trigger if exists sale_notify on sales;
create trigger sale_notify after insert on sales for each row execute function trg_sale();

create or replace function trg_req() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='done' and old.status is distinct from 'done' then
    perform notify_user(new.user_id,'Request completed','Your '||new.kind||' request has been completed.');
  end if; return new; end $$;
drop trigger if exists req_notify on requests;
create trigger req_notify after update on requests for each row execute function trg_req();

-- private bucket for construction documents (IDs, titles, plans)
insert into storage.buckets(id,name,public) values('request-docs','request-docs',false) on conflict do nothing;
create policy rd1 on storage.objects for insert to authenticated with check(bucket_id='request-docs' and (storage.foldername(name))[1]=auth.uid()::text);
create policy rd2 on storage.objects for select to authenticated using(bucket_id='request-docs' and ((storage.foldername(name))[1]=auth.uid()::text or is_admin()));
