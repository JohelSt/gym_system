create table if not exists public.logs_errores_comentarios (
  id bigint generated always as identity primary key,
  error_id bigint not null references public.logs_errores(id) on delete cascade,
  usuario_id uuid references auth.users(id),
  comentario text not null,
  created_at timestamp with time zone not null default now()
);

create index if not exists idx_logs_errores_comentarios_error
  on public.logs_errores_comentarios (error_id, created_at desc);

alter table public.logs_errores_comentarios enable row level security;

drop policy if exists "admins_manage_error_comments" on public.logs_errores_comentarios;
create policy "admins_manage_error_comments"
on public.logs_errores_comentarios
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
