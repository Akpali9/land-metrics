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

-- Admins can delete public announcements (global notifications only).
drop policy if exists notifications_admin_delete on public.notifications;
create policy notifications_admin_delete on public.notifications
for delete to authenticated using (is_admin() and user_id is null);
