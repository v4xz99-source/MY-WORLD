-- 1) غيّر الإيميل ده لإيميلك (اللي هتدخل بيه كمالك) قبل ما تشغّل الملف
create or replace function public.is_owner() returns boolean
language sql stable as $$
  select coalesce(auth.jwt()->>'email','') = lower('mov09597@gmail.com')
$$;

create table if not exists profile(
  id int primary key default 1 check (id = 1),
  name text, bio text, frame text default 'ring',
  avatar_url text, banner_url text, banner_type text);
create table if not exists videos(
  id uuid primary key default gen_random_uuid(),
  title text, url text not null, created_at timestamptz default now());
create table if not exists links(
  id uuid primary key default gen_random_uuid(),
  title text not null, url text not null, position int default 0);
create table if not exists likes(
  video_id uuid references videos(id) on delete cascade,
  visitor_id text not null, primary key (video_id, visitor_id));
create table if not exists comments(
  id uuid primary key default gen_random_uuid(),
  video_id uuid references videos(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz default now());

insert into profile(id,name,bio) values (1,'MOHAMED AMR','THIS IS MY WORLD.') on conflict do nothing;

alter table profile  enable row level security;
alter table videos   enable row level security;
alter table links    enable row level security;
alter table likes    enable row level security;
alter table comments enable row level security;

-- الكل يقرأ
create policy "read profile"  on profile  for select using (true);
create policy "read videos"   on videos   for select using (true);
create policy "read links"    on links    for select using (true);
create policy "read likes"    on likes    for select using (true);
create policy "read comments" on comments for select using (true);

-- المالك بس يعدّل
create policy "owner profile" on profile for all using (is_owner()) with check (is_owner());
create policy "owner videos"  on videos  for all using (is_owner()) with check (is_owner());
create policy "owner links"   on links   for all using (is_owner()) with check (is_owner());

-- أي زائر يكتب تعليق، والمالك بس يمسح
create policy "anyone comments" on comments for insert with check (true);
create policy "owner del comments" on comments for delete using (is_owner());

-- اللايك عن طريق دالة (زائر بدون حساب)
create or replace function public.toggle_like(p_video uuid, p_visitor text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if char_length(p_visitor) < 8 or char_length(p_visitor) > 64 then return; end if;
  if exists (select 1 from likes where video_id = p_video and visitor_id = p_visitor) then
    delete from likes where video_id = p_video and visitor_id = p_visitor;
  else
    insert into likes(video_id, visitor_id) values (p_video, p_visitor);
  end if;
end $$;
grant execute on function public.toggle_like(uuid, text) to anon, authenticated;

-- مخزن الصور والفيديوهات
insert into storage.buckets (id, name, public, file_size_limit)
values ('media','media', true, 52428800)
on conflict (id) do update set public = true, file_size_limit = 52428800;

create policy "media read"   on storage.objects for select using (bucket_id = 'media');
create policy "media insert" on storage.objects for insert to authenticated with check (bucket_id = 'media' and public.is_owner());
create policy "media update" on storage.objects for update to authenticated using (bucket_id = 'media' and public.is_owner());
create policy "media delete" on storage.objects for delete to authenticated using (bucket_id = 'media' and public.is_owner());
