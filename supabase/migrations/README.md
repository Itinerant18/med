# Supabase Migrations

This folder contains the database migration history for MediFlow.

## How to use

- Do not edit old migrations after they have been applied.
- Add new changes as a new timestamped `.sql` file.
- Keep migration names descriptive and focused on one change set.
- Apply schema changes here first, then deploy through Supabase.

## Current migration history

- `20260413153000_add_patient_extended_fields.sql`
  - Adds extended patient fields and related data model updates.
- `20260413160000_rbac_policies.sql`
  - Introduces role helper logic and baseline RLS policies.
- `20260418_approval.sql`
  - Adds approval workflow support for staff accounts.
- `20260418_dr_visits.sql`
  - Creates and secures the `dr_visits` table.
- `20260418_followup_tasks.sql`
  - Creates and secures the `followup_tasks` table.
- `20260418_three_tier_roles.sql`
  - Expands roles to `head_doctor`, `doctor`, and `assistant`.
- `20260421_agent_outside_visits.sql`
  - Adds agent outside-visit tracking and access rules.
- `20260421_followup_assistant_insert_policy.sql`
  - Allows approved assistants to create assigned follow-ups.
- `20260421_followup_external_doctor_fields.sql`
  - Adds external doctor metadata to follow-up tasks.
- `20260421_followup_title_priority.sql`
  - Adds title and priority fields to follow-up tasks.
- `20260421_realtime_publication.sql`
  - Publishes tables for Supabase Realtime.
- `20260421_stale_patient_reminder.sql`
  - Adds reminder tracking and scheduled reminder support.
- `20260425_followup_target_doctor_and_review.sql`
  - Updates follow-up review flow and assistant performance view logic.
- `20260430_add_investigation_meet_fields.sql`
  - Adds meeting and investigation fields used in patient workflows.
- `20260501101500_user_preferences.sql`
  - Adds user preference storage.
- `20260502_agent_visits_optional_patient.sql`
  - Makes agent visit patient linkage optional.
- `20260502153000_patient_documents_public_url.sql`
  - Adds document URL/public URL support for patient documents.

## Notes for collaborators

- `public.get_my_role()` is the main role helper used across RLS policies.
- `patients`, `visits`, `dr_visits`, and `followup_tasks` are the most sensitive RLS-protected tables.
- Realtime subscriptions and scheduled jobs depend on the Supabase project settings matching the SQL in these migrations.

