-- Run once in Supabase > SQL Editor
create table profiles(id uuid primary key references auth.users on delete cascade,full_name text,phone text,role text not null default 'user' check(role in('user','admin')),created_at timestamptz default now());
create table settings(key text primary key,value text);
insert into settings values('bank_name','YOUR BANK'),('account_name','LAND OGA'),('account_number','0000000000'),('subscription_fee','15000'),('admin_code','CHANGE-ME-NOW');
create table lands(id bigint generated always as identity primary key,seller_id uuid not null default auth.uid() references profiles,kind text default 'land' check(kind in('land','property')),title text not null,location text,size_sqm numeric,price numeric not null check(price>0),description text,images text[] default '{}',status text default 'pending' check(status in('pending','approved','live','sold','rejected')),created_at timestamptz default now());
create table payments(id bigint generated always as identity primary key,user_id uuid not null default auth.uid() references profiles,land_id bigint references lands,type text check(type in('subscription','purchase')),amount numeric,proof_url text,status text default 'pending' check(status in('pending','verified','rejected')),created_at timestamptz default now());
create table sales(id bigint generated always as identity primary key,land_id bigint references lands,seller_id uuid,buyer_id uuid,price numeric,buyer_fee numeric,seller_fee numeric,seller_net numeric,created_at timestamptz default now());
create table requests(id bigint generated always as identity primary key,user_id uuid not null default auth.uid() references profiles,kind text check(kind in('verification','construction')),details text,budget numeric,status text default 'pending',created_at timestamptz default now());
create table ads(id bigint generated always as identity primary key,title text,body text,image_url text,created_at timestamptz default now());
create table notifications(id bigint generated always as identity primary key,body text,created_at timestamptz default now());
create table messages(id bigint generated always as identity primary key,thread_user uuid not null,sender_id uuid default auth.uid(),body text not null,created_at timestamptz default now());

create function is_admin() returns boolean language sql security definer stable as $$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;
create function handle_new_user() returns trigger language plpgsql security definer as $$ begin insert into profiles(id,full_name,phone) values(new.id,new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'phone'); return new; end $$;
create trigger on_signup after insert on auth.users for each row execute function handle_new_user();
create function claim_admin(code text) returns boolean language plpgsql security definer as $$ begin if code=(select value from settings where key='admin_code') then update profiles set role='admin' where id=auth.uid(); return true; end if; return false; end $$;

-- amounts are always set by the server, never trusted from the app
create function set_amount() returns trigger language plpgsql security definer as $$ declare l lands; begin
 select * into l from lands where id=new.land_id;
 if new.type='subscription' then if l.seller_id<>auth.uid() or l.status<>'approved' then raise exception 'not allowed'; end if; new.amount=(select value::numeric from settings where key='subscription_fee');
 else if l.status<>'live' or l.seller_id=auth.uid() then raise exception 'not available'; end if; new.amount=l.price*1.1; end if;
 new.user_id=auth.uid(); new.status='pending'; return new; end $$;
create trigger pay_amount before insert on payments for each row execute function set_amount();

create function verify_payment(pid bigint,ok boolean) returns void language plpgsql security definer as $$ declare p payments; l lands; begin
 if not is_admin() then raise exception 'admin only'; end if;
 select * into p from payments where id=pid and status='pending'; if not found then return; end if;
 update payments set status=case when ok then 'verified' else 'rejected' end where id=pid;
 if not ok then return; end if;
 select * into l from lands where id=p.land_id;
 if p.type='subscription' then update lands set status='live' where id=l.id;
 else update lands set status='sold' where id=l.id;
  insert into sales(land_id,seller_id,buyer_id,price,buyer_fee,seller_fee,seller_net) values(l.id,l.seller_id,p.user_id,l.price,l.price*.1,l.price*.1,l.price*.9); end if; end $$;

alter table profiles enable row level security;alter table settings enable row level security;alter table lands enable row level security;alter table payments enable row level security;alter table sales enable row level security;alter table requests enable row level security;alter table ads enable row level security;alter table notifications enable row level security;alter table messages enable row level security;
create policy p1 on profiles for select to authenticated using(id=auth.uid() or is_admin());
create policy s1 on settings for select to authenticated using(key<>'admin_code');
create policy l1 on lands for select to authenticated using(status in('live','sold') or seller_id=auth.uid() or is_admin());
create policy l2 on lands for insert to authenticated with check(seller_id=auth.uid() and status='pending');
create policy l3 on lands for update to authenticated using(is_admin());
create policy y1 on payments for select to authenticated using(user_id=auth.uid() or is_admin());
create policy y2 on payments for insert to authenticated with check(user_id=auth.uid());
create policy a1 on sales for select to authenticated using(seller_id=auth.uid() or buyer_id=auth.uid() or is_admin());
create policy r1 on requests for select to authenticated using(user_id=auth.uid() or is_admin());
create policy r2 on requests for insert to authenticated with check(user_id=auth.uid());
create policy r3 on requests for update to authenticated using(is_admin());
create policy d1 on ads for select to authenticated using(true);
create policy d2 on ads for insert to authenticated with check(is_admin());
create policy n1 on notifications for select to authenticated using(true);
create policy n2 on notifications for insert to authenticated with check(is_admin());
create policy m1 on messages for select to authenticated using(thread_user=auth.uid() or is_admin());
create policy m2 on messages for insert to authenticated with check(sender_id=auth.uid() and (thread_user=auth.uid() or is_admin()));
alter publication supabase_realtime add table messages;

insert into storage.buckets(id,name,public) values('land-images','land-images',true) on conflict do nothing;
create policy o1 on storage.objects for select using(bucket_id='land-images');
create policy o2 on storage.objects for insert to authenticated with check(bucket_id='land-images');
-- LAND METRICS: admin account + ad management. Safe to run after schema.sql.
create extension if not exists pgcrypto with schema extensions;

-- Default admin: admin@landmetrics.com / admin000   (CHANGE THE PASSWORD after first login)
do $$
declare uid uuid := gen_random_uuid();
begin
  if not exists (select 1 from auth.users where email = 'admin@landmetrics.com') then
    insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change,email_change_token_new)
    values('00000000-0000-0000-0000-000000000000',uid,'authenticated','authenticated','admin@landmetrics.com',extensions.crypt('admin000',extensions.gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{"full_name":"LAND METRICS Admin"}',now(),now(),'','','','');
    insert into auth.identities(id,user_id,provider_id,provider,identity_data,last_sign_in_at,created_at,updated_at)
    values(gen_random_uuid(),uid,uid::text,'email',jsonb_build_object('sub',uid::text,'email','admin@landmetrics.com','email_verified',true),now(),now(),now());
  end if;
  insert into profiles(id,full_name,role) select id,'LAND METRICS Admin','admin' from auth.users where email='admin@landmetrics.com'
  on conflict (id) do update set role='admin';
end $$;

-- the self-register admin code is now random (read it in the settings table if you need it)
update settings set value = substr(md5(random()::text),1,10) where key='admin_code' and value='CHANGE-ME-NOW';

-- admins can delete ads
create policy d3 on ads for delete to authenticated using(is_admin());
