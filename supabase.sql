-- Pega todo esto en Supabase → SQL Editor → Run

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  title text not null default '',
  body text not null default '',
  updated_at timestamptz not null default now()
);
create table public.instrumentals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  note_id uuid not null references public.notes on delete cascade,
  name text not null,
  path text not null,
  created_at timestamptz not null default now()
);
create table public.songs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  title text not null check (char_length(title) <= 60),
  artist text not null check (char_length(artist) <= 40),
  lyrics text not null check (char_length(lyrics) <= 20000),
  cover_path text not null,
  audio_path text not null,
  published boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.likes (
  song_id uuid not null references public.songs on delete cascade,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  primary key (song_id, user_id)
);

alter table public.notes enable row level security;
alter table public.instrumentals enable row level security;
alter table public.songs enable row level security;
alter table public.likes enable row level security;

create policy "notas: solo el dueño" on public.notes for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "instrumentales: solo el dueño" on public.instrumentals for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "canciones: ver propias o publicadas" on public.songs for select to authenticated
  using (published or auth.uid() = user_id);
create policy "canciones: crear propias" on public.songs for insert to authenticated
  with check (auth.uid() = user_id);
create policy "canciones: editar propias" on public.songs for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "canciones: borrar propias" on public.songs for delete to authenticated
  using (auth.uid() = user_id);

create policy "likes: ver" on public.likes for select to authenticated using (true);
create policy "likes: dar like propio" on public.likes for insert to authenticated
  with check (auth.uid() = user_id and exists (select 1 from public.songs s where s.id = song_id and s.published));
create policy "likes: quitar like propio" on public.likes for delete to authenticated
  using (auth.uid() = user_id);

-- Almacenamiento privado (50 MB por archivo)
insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', false, 52428800) on conflict (id) do nothing;

create policy "media: subir a mi carpeta" on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media: borrar de mi carpeta" on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media: ver lo mío o lo publicado" on storage.objects for select to authenticated
  using (bucket_id = 'media' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (select 1 from public.songs s where s.published and (s.cover_path = name or s.audio_path = name))
  ));
