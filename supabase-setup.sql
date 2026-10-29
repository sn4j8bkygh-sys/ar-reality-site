-- Supabase SQL Editor: запусти этот SQL после создания проекта.
-- ВНИМАНИЕ: публичная загрузка разрешена только в bucket visitor-photos,
-- чтение остаётся закрытым. Для публичного сайта добавь CAPTCHA/лимиты/защиту от злоупотреблений.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('visitor-photos', 'visitor-photos', false, 10485760, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = 10485760, allowed_mime_types = array['image/jpeg'];

create table if not exists public.site_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.site_admins enable row level security;
revoke all on public.site_admins from anon, authenticated;
grant select on public.site_admins to authenticated;
drop policy if exists "admins can read their own admin row" on public.site_admins;
create policy "admins can read their own admin row" on public.site_admins
for select to authenticated using (auth.uid() = user_id);

-- Разрешить анонимную загрузку новых JPEG, но не чтение, изменение и удаление.
drop policy if exists "visitors may upload photo with consent" on storage.objects;
create policy "visitors may upload photo with consent" on storage.objects
for insert to anon, authenticated
with check (bucket_id = 'visitor-photos' and lower(name) like '%.jpg');

-- Только пользователи, внесённые в site_admins, могут перечислять и читать фото.
drop policy if exists "admins can list visitor photos" on storage.objects;
create policy "admins can list visitor photos" on storage.objects
for select to authenticated
using (bucket_id = 'visitor-photos' and exists (
  select 1 from public.site_admins a where a.user_id = auth.uid()
));
