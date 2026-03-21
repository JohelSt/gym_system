create table if not exists public.campanas (
  id bigint generated always as identity primary key,
  titulo text not null,
  descripcion text not null,
  imagen_url text,
  fecha_inicio date not null,
  fecha_fin date not null,
  activa boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint campanas_fecha_valida check (fecha_fin >= fecha_inicio)
);

create index if not exists idx_campanas_vigencia
  on public.campanas (activa, fecha_inicio, fecha_fin);

create or replace function public.set_updated_at_campanas()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_set_updated_at_campanas on public.campanas;

create trigger trg_set_updated_at_campanas
before update on public.campanas
for each row
execute function public.set_updated_at_campanas();

alter table public.campanas enable row level security;

drop policy if exists "admins_manage_campanas" on public.campanas;
create policy "admins_manage_campanas"
on public.campanas
for all
to authenticated
using (
  exists (
    select 1
    from public.perfiles p
    where p.id = auth.uid()
      and p.rol_id in (1, 2, 3)
      and p.estado = true
  )
)
with check (
  exists (
    select 1
    from public.perfiles p
    where p.id = auth.uid()
      and p.rol_id in (1, 2, 3)
      and p.estado = true
  )
);

drop policy if exists "authenticated_read_active_campanas" on public.campanas;
create policy "authenticated_read_active_campanas"
on public.campanas
for select
to authenticated
using (
  activa = true
  and fecha_inicio <= current_date
  and fecha_fin >= current_date
);

create table if not exists public.device_push_tokens (
  id bigint generated always as identity primary key,
  usuario_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  plataforma text not null,
  activo boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create index if not exists idx_device_push_tokens_usuario
  on public.device_push_tokens (usuario_id, activo);

create or replace function public.set_updated_at_device_push_tokens()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_set_updated_at_device_push_tokens on public.device_push_tokens;

create trigger trg_set_updated_at_device_push_tokens
before update on public.device_push_tokens
for each row
execute function public.set_updated_at_device_push_tokens();

alter table public.device_push_tokens enable row level security;

drop policy if exists "users_manage_own_push_tokens" on public.device_push_tokens;
create policy "users_manage_own_push_tokens"
on public.device_push_tokens
for all
to authenticated
using (usuario_id = auth.uid())
with check (usuario_id = auth.uid());

drop policy if exists "admins_read_push_tokens" on public.device_push_tokens;
create policy "admins_read_push_tokens"
on public.device_push_tokens
for select
to authenticated
using (
  exists (
    select 1
    from public.perfiles p
    where p.id = auth.uid()
      and p.rol_id in (1, 2, 3)
      and p.estado = true
  )
);
