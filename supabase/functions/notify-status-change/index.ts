import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type StatusChangePayload = {
  patientId?: string;
  patientName?: string;
  oldStatus?: string | null;
  newStatus?: string | null;
  updaterId?: string | null;
  ownerId?: string | null;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const payload = (await request.json()) as StatusChangePayload;
    const patientId = payload.patientId?.trim();
    const patientName = payload.patientName?.trim() || "Patient";
    const oldStatus = payload.oldStatus?.trim() || "unknown";
    const newStatus = payload.newStatus?.trim();
    const updaterId = payload.updaterId?.trim();
    const ownerId = payload.ownerId?.trim();

    if (!patientId || !newStatus || !updaterId) {
      return json({ error: "Missing required fields" }, 400);
    }

    const { data: updater, error: updaterError } = await admin
        .from("doctors")
        .select("id, full_name, role")
        .eq("id", updaterId)
        .maybeSingle();

    if (updaterError) {
      return json({ error: updaterError.message }, 500);
    }
    if (!updater) {
      return json({ error: "Updater not found" }, 404);
    }

    const updaterName = updater.full_name?.toString() || "Staff";
    const updaterRole = updater.role?.toString() || "";

    const targets = new Map<string, { token: string; full_name: string }>();

    if (updaterRole === "assistant") {
      const { data: doctors, error: doctorsError } = await admin
          .from("doctors")
          .select("id, fcm_token, full_name")
          .in("role", ["head_doctor", "doctor"])
          .eq("approval_status", "approved");

      if (doctorsError) {
        return json({ error: doctorsError.message }, 500);
      }

      for (const doctor of doctors ?? []) {
        const token = doctor.fcm_token?.toString();
        const id = doctor.id?.toString();
        if (!id || !token) continue;
        targets.set(id, {
          token,
          full_name: doctor.full_name?.toString() || "Doctor",
        });
      }
    } else if (ownerId && ownerId != updaterId) {
      const { data: owner, error: ownerError } = await admin
          .from("doctors")
          .select("id, fcm_token, full_name")
          .eq("id", ownerId)
          .maybeSingle();

      if (ownerError) {
        return json({ error: ownerError.message }, 500);
      }

      const token = owner?.fcm_token?.toString();
      const id = owner?.id?.toString();
      if (id && token) {
        targets.set(id, {
          token,
          full_name: owner.full_name?.toString() || "Staff",
        });
      }
    }

    if (targets.size === 0) {
      return json({ sent: 0, skipped: true });
    }

    const sendResults = await Promise.allSettled(
      [...targets.values()].map((target) =>
        fetch(`${supabaseUrl}/functions/v1/send-fcm-notification`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${serviceRoleKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            token: target.token,
            title: `Status: ${patientName}`,
            body: `${oldStatus} → ${newStatus} (by ${updaterName})`,
            data: {
              type: "status_change",
              patientId,
            },
          }),
        })
      ),
    );

    const sent = sendResults.filter((result) => result.status === "fulfilled")
        .length;

    return json({ sent });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return json({ error: message }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}
