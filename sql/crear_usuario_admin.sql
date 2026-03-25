create extension if not exists pgcrypto;

create or replace function public.crear_usuario_admin(
  p_email text,
  p_password text,
  p_cedula text,
  p_nombre_completo text,
  p_telefono text default null,
  p_direccion text default null,
  p_rol_id integer default 4,
  p_estado boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_user_id uuid := gen_random_uuid();
  v_email text := lower(trim(p_email));
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesion para crear usuarios';
  end if;

  if not exists (
    select 1
    from public.perfiles p
    where p.id = auth.uid()
      and p.rol_id in (1, 2, 3)
      and p.estado = true
  ) then
    raise exception 'No tienes permisos para crear usuarios';
  end if;

  if v_email is null or v_email = '' then
    raise exception 'El correo es obligatorio';
  end if;

  if p_password is null or length(trim(p_password)) < 6 then
    raise exception 'La contrasena debe tener al menos 6 caracteres';
  end if;

  if exists (
    select 1
    from auth.users u
    where lower(u.email) = v_email
  ) then
    raise exception 'Ya existe un usuario con ese correo';
  end if;

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    extensions.crypt(p_password, extensions.gen_salt('bf')),
    now(),
    jsonb_build_object('provider', 'email', 'providers', array['email']),
    jsonb_build_object('nombre_completo', p_nombre_completo),
    now(),
    now()
  );

  insert into auth.identities (
    id,
    user_id,
    provider_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  )
  values (
    gen_random_uuid(),
    v_user_id,
    v_user_id::text,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', v_email
    ),
    'email',
    now(),
    now(),
    now()
  );

  insert into public.perfiles (
    id,
    cedula,
    nombre_completo,
    rol_id,
    estado,
    telefono,
    direccion
  )
  values (
    v_user_id,
    nullif(trim(p_cedula), ''),
    nullif(trim(p_nombre_completo), ''),
    p_rol_id,
    p_estado,
    nullif(trim(p_telefono), ''),
    nullif(trim(p_direccion), '')
  );

  return v_user_id;
end;
$$;

revoke all on function public.crear_usuario_admin(
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  boolean
) from public;

grant execute on function public.crear_usuario_admin(
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  boolean
) to authenticated;
