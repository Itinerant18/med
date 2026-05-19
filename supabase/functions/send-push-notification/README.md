# send-push-notification

Supabase Edge Function that sends targeted FCM (Firebase Cloud Messaging) push
notifications when key MediFlow events occur.

## Environment variables

Set these with `supabase secrets set`:

| Variable | Description |
|---|---|
| `FCM_SERVICE_ACCOUNT_JSON` | Full Firebase service account JSON string (minified). The service account must have the *Firebase Cloud Messaging Admin* role. |
| `FCM_PROJECT_ID` | Firebase project ID (e.g. `mediflow-12345`) |
| `SUPABASE_URL` | Automatically available in Supabase Edge Functions |
| `SUPABASE_SERVICE_ROLE_KEY` | Automatically available in Supabase Edge Functions |

### Setting secrets

```bash
# Set a single secret
supabase secrets set FCM_PROJECT_ID=mediflow-12345

# Set the service account JSON (pipe from file to avoid escaping issues)
cat firebase-service-account.json | supabase secrets set FCM_SERVICE_ACCOUNT_JSON
```

## Request body

```json
{
  "event": "followup_assigned",
  "recipientIds": ["uuid-1", "uuid-2"],
  "title": "New task assigned",
  "body": "Take John Doe to Dr. Smith",
  "data": { "type": "followup", "taskId": "..." }
}
```

### Events

| Event | Trigger |
|---|---|
| `followup_assigned` | A doctor assigns a follow-up task to an agent |
| `followup_completed` | An agent marks a follow-up task as completed |
| `followup_reviewed` | A doctor reviews a completed follow-up task |
| `outside_visit_recorded` | An agent records an external doctor visit |
| `patient_status_changed` | A patient's status changes |
| `work_log_added` | A new work log entry is added |

## Response

```json
{ "sent": 2, "failed": 0 }
```

Expired tokens (404 from FCM) are automatically cleared from the `doctors`
table so they are not retried.

## Testing locally

```bash
supabase functions serve send-push-notification --env-file .env.local
curl -X POST http://localhost:54321/functions/v1/send-push-notification \
  -H "Content-Type: application/json" \
  -d '{
    "event": "followup_assigned",
    "recipientIds": ["<doctor-uuid>"],
    "title": "Test",
    "body": "Hello!"
  }'
```
