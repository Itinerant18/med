import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const twoDaysAgoIso = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)
      .toISOString();

    const { data: stalePatients, error: staleError } = await supabase
      .from("patients")
      .select("id, full_name, created_by_id, service_status")
      .lt("last_updated_at", twoDaysAgoIso)
      .not("service_status", "in", '("Discharged","Referred")')
      .eq("reminder_sent", false);

    if (staleError) {
      return json({ error: staleError.message }, 500);
    }

    if (!stalePatients || stalePatients.length === 0) {
      return json({ sent: 0, skipped: true });
    }

    let sentCount = 0;

    for (const patient of stalePatients) {
      const ownerId = patient.created_by_id?.toString();
      if (!ownerId) continue;

      const { data: doctor, error: doctorError } = await supabase
        .from("doctors")
        .select("id, full_name, fcm_token")
        .eq("id", ownerId)
        .maybeSingle();

      if (doctorError || !doctor?.fcm_token) {
        continue;
      }

      const response = await fetch(
        `${supabaseUrl}/functions/v1/send-fcm-notification`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${serviceRoleKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            token: doctor.fcm_token,
            title: `Update needed: ${patient.full_name ?? "Patient"}`,
            body: "Patient status has not been updated in 2+ days.",
            data: {
              type: "stale_patient",
              patientId: patient.id?.toString() ?? "",
            },
          }),
        },
      );

      if (!response.ok) {
        continue;
      }

      sentCount += 1;

      await supabase.from("patient_reminders").insert({
        patient_id: patient.id,
        doctor_id: ownerId,
        old_status: patient.service_status,
        service_status: patient.service_status,
      });

      await supabase.from("patients").update({
        reminder_sent: true,
        reminder_sent_at: new Date().toISOString(),
      }).eq("id", patient.id);
    }

    return json({ sent: sentCount, total: stalePatients.length });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return json({ error: message }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
