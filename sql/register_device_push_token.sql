create or replace function public.register_device_push_token(
  p_token text,
  p_plataforma text
)
returns public.device_push_tokens
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.device_push_tokens;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado'
      using errcode = '42501';
  end if;

  if p_token is null or btrim(p_token) = '' then
    raise exception 'Token push invalido'
      using errcode = '22023';
  end if;

  insert into public.device_push_tokens (
    usuario_id,
    token,
    plataforma,
    activo
  )
  values (
    v_user_id,
    btrim(p_token),
    coalesce(nullif(btrim(p_plataforma), ''), 'unknown'),
    true
  )
  on conflict (token)
  do update
  set
    usuario_id = excluded.usuario_id,
    plataforma = excluded.plataforma,
    activo = true,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.register_device_push_token(text, text) to authenticated;

create or replace function public.deactivate_device_push_tokens(
  p_usuario_id uuid default auth.uid()
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := coalesce(p_usuario_id, auth.uid());
  v_count bigint;
begin
  if v_user_id is null then
    raise exception 'Usuario no autenticado'
      using errcode = '42501';
  end if;

  update public.device_push_tokens
  set
    activo = false,
    updated_at = now()
  where usuario_id = v_user_id
    and activo = true;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.deactivate_device_push_tokens(uuid) to authenticated;
