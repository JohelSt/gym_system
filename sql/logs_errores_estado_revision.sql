alter table public.logs_errores
add column if not exists estado_revision integer not null default 1;

alter table public.logs_errores
drop constraint if exists logs_errores_estado_revision_check;

alter table public.logs_errores
add constraint logs_errores_estado_revision_check
check (estado_revision in (1, 2, 3, 4));

comment on column public.logs_errores.estado_revision is
'1 = Descubierto, 2 = En proceso, 3 = Reparado, 4 = Error en Revision';

alter table public.logs_errores enable row level security;

drop policy if exists "admins_can_update_logs_errores_estado" on public.logs_errores;
create policy "admins_can_update_logs_errores_estado"
on public.logs_errores
for update
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
