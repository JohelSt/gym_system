create table if not exists public.citas_medicion (
  id bigint generated always as identity primary key,
  fecha date not null,
  hora_inicio time without time zone not null,
  hora_fin time without time zone not null,
  persona_asignada_id uuid not null references public.perfiles(id),
  creado_por uuid references auth.users(id),
  notas text,
  estado text not null default 'Programada',
  created_at timestamp with time zone not null default now(),
  constraint citas_medicion_hora_valida check (hora_fin > hora_inicio),
  constraint citas_medicion_estado_check check (
    estado in ('Programada', 'Completada', 'Cancelada')
  )
);

create index if not exists idx_citas_medicion_fecha
on public.citas_medicion (fecha, hora_inicio);

create or replace function public.validar_traslape_citas_medicion()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1
    from public.citas_medicion c
    where c.persona_asignada_id = new.persona_asignada_id
      and c.fecha = new.fecha
      and c.id <> coalesce(new.id, -1)
      and c.hora_inicio < new.hora_fin
      and c.hora_fin > new.hora_inicio
  ) then
    raise exception 'Ya existe una cita traslapada para esta persona'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validar_traslape_citas_medicion on public.citas_medicion;
create trigger trg_validar_traslape_citas_medicion
before insert or update on public.citas_medicion
for each row
execute function public.validar_traslape_citas_medicion();

alter table public.citas_medicion enable row level security;

drop policy if exists "admins_manage_citas_medicion" on public.citas_medicion;
create policy "admins_manage_citas_medicion"
on public.citas_medicion
for all
to authenticated
using (
  exists (
    select 1
    from public.perfiles p
    where p.id = auth.uid()
      and p.rol_id in (1, 2)
      and p.estado = true
  )
)
with check (
  exists (
    select 1
    from public.perfiles p
    where p.id = auth.uid()
      and p.rol_id in (1, 2)
      and p.estado = true
  )
);
