import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const brevoApiKey = Deno.env.get("BREVO_API_KEY") ?? "";
const brevoSenderEmail = Deno.env.get("BREVO_SENDER_EMAIL") ?? "";
const brevoSenderName = Deno.env.get("BREVO_SENDER_NAME") ?? "Gym System";

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function buildHtml(
  nombre: string,
  estadoMembresia: string,
  fechaProximoCobro: string,
) {
  return `
    <div style="font-family: Arial, sans-serif; background:#0d0d0d; color:#f3f3f3; padding:24px;">
      <div style="max-width:640px; margin:0 auto; background:#171717; border:1px solid #2a2a2a; border-radius:16px; overflow:hidden;">
        <div style="padding:24px; background:linear-gradient(135deg, #39ff14 0%, #0d0d0d 100%); color:#000;">
          <h1 style="margin:0; font-size:24px;">Recordatorio de pago vencido</h1>
        </div>
        <div style="padding:24px;">
          <p>Hola ${nombre},</p>
          <p>Te escribimos para informarte que tu membresia presenta un pago vencido.</p>
          <p><strong>Estado actual:</strong> ${estadoMembresia}</p>
          <p><strong>Fecha de cobro registrada:</strong> ${fechaProximoCobro}</p>
          <p>Por favor acercate al gimnasio o ponte en contacto con administracion para regularizar tu membresia.</p>
          <p style="margin-top:24px;">Gym System</p>
        </div>
      </div>
    </div>
  `;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Metodo no permitido." });
  }

  if (
    !supabaseUrl ||
    !supabaseAnonKey ||
    !serviceRoleKey ||
    !brevoApiKey ||
    !brevoSenderEmail
  ) {
    return jsonResponse(500, {
      error: "La funcion no esta configurada correctamente.",
    });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse(401, { error: "No autenticado." });
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const serviceClient = createClient(supabaseUrl, serviceRoleKey);

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return jsonResponse(401, { error: "No autenticado." });
  }

  const { data: callerProfile, error: callerError } = await serviceClient
    .from("perfiles")
    .select("rol_id, estado")
    .eq("id", user.id)
    .maybeSingle();

  if (
    callerError ||
    !callerProfile ||
    callerProfile.estado !== true ||
    ![1, 2, 3].includes(Number(callerProfile.rol_id))
  ) {
    return jsonResponse(403, { error: "No tienes permisos para esta accion." });
  }

  let clienteId = "";
  try {
    const body = await req.json();
    clienteId = String(body?.clienteId ?? "").trim();
  } catch (_) {
    return jsonResponse(400, { error: "Solicitud invalida." });
  }

  if (!clienteId) {
    return jsonResponse(400, { error: "Debes indicar el cliente." });
  }

  const { data: cliente, error: clienteError } = await serviceClient
    .from("perfiles")
    .select("id, nombre_completo, fecha_proximo_cobro, estado_membresia")
    .eq("id", clienteId)
    .maybeSingle();

  if (clienteError || !cliente) {
    return jsonResponse(404, { error: "Cliente no encontrado." });
  }

  const { data: authUserData, error: authUserError } =
    await serviceClient.auth.admin.getUserById(clienteId);

  const email = authUserData?.user?.email?.trim();
  if (authUserError || !email) {
    await serviceClient.from("email_notificaciones").insert({
      cliente_id: clienteId,
      correo_destino: "",
      asunto: "Recordatorio de pago vencido",
      contenido_resumen: "No se encontro un correo asociado al cliente.",
      estado_envio: "fallido",
      error_mensaje: "No se encontro un correo asociado al cliente.",
      enviado_por: user.id,
      proveedor: "brevo",
      tipo: "PAGO_VENCIDO",
    });

    return jsonResponse(400, {
      error: "El cliente no tiene un correo electronico disponible.",
    });
  }

  const nombre = String(cliente.nombre_completo ?? "Cliente").trim() || "Cliente";
  const estadoMembresia = String(
    cliente.estado_membresia ?? "Pago pendiente",
  ).trim();
  const fechaProximoCobro = String(
    cliente.fecha_proximo_cobro ?? "Sin fecha definida",
  ).trim();

  const subject = "Recordatorio de pago vencido";
  const htmlContent = buildHtml(nombre, estadoMembresia, fechaProximoCobro);

  const brevoResponse = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "accept": "application/json",
      "api-key": brevoApiKey,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      sender: {
        email: brevoSenderEmail,
        name: brevoSenderName,
      },
      to: [{ email, name: nombre }],
      subject,
      htmlContent,
    }),
  });

  const responseText = await brevoResponse.text();
  let providerResponse: unknown = responseText;
  try {
    providerResponse = JSON.parse(responseText);
  } catch (_) {
    // keep raw text
  }

  if (!brevoResponse.ok) {
    await serviceClient.from("email_notificaciones").insert({
      cliente_id: clienteId,
      correo_destino: email,
      asunto: subject,
      contenido_resumen: "Recordatorio de pago vencido enviado por Brevo.",
      estado_envio: "fallido",
      respuesta_proveedor: providerResponse,
      error_mensaje: "Brevo rechazo el envio del correo.",
      enviado_por: user.id,
      proveedor: "brevo",
      tipo: "PAGO_VENCIDO",
    });

    return jsonResponse(502, {
      error: "No se pudo enviar el correo con Brevo.",
      details: providerResponse,
    });
  }

  await serviceClient.from("email_notificaciones").insert({
    cliente_id: clienteId,
    correo_destino: email,
    asunto: subject,
    contenido_resumen: "Recordatorio de pago vencido enviado por Brevo.",
    estado_envio: "enviado",
    respuesta_proveedor: providerResponse,
    enviado_por: user.id,
    proveedor: "brevo",
    tipo: "PAGO_VENCIDO",
  });

  return jsonResponse(200, {
    ok: true,
    message: "Correo enviado correctamente.",
    email,
  });
});
