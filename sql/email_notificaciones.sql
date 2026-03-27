create table if not exists public.email_notificaciones (
  id bigint generated always as identity primary key,
  cliente_id uuid not null references public.perfiles(id) on delete cascade,
  correo_destino text not null,
  tipo text not null default 'PAGO_VENCIDO',
  asunto text not null,
  contenido_resumen text,
  proveedor text not null default 'brevo',
  estado_envio text not null default 'pendiente',
  respuesta_proveedor jsonb,
  error_mensaje text,
  enviado_por uuid references auth.users(id),
  created_at timestamp with time zone not null default now()
);

create index if not exists idx_email_notificaciones_cliente
  on public.email_notificaciones (cliente_id, created_at desc);

create index if not exists idx_email_notificaciones_estado
  on public.email_notificaciones (estado_envio, created_at desc);

alter table public.email_notificaciones enable row level security;

drop policy if exists "admins_can_select_email_notificaciones" on public.email_notificaciones;
create policy "admins_can_select_email_notificaciones"
on public.email_notificaciones
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

drop policy if exists "service_role_manage_email_notificaciones" on public.email_notificaciones;
create policy "service_role_manage_email_notificaciones"
on public.email_notificaciones
for all
to service_role
using (true)
with check (true);
