# Backend setup

## Where things stand (27 Nov 2026)

The app uses the Supabase project named in your git-ignored `ios/Config.local.xcconfig` (`SUPABASE_HOST`).
As of this date it is up to date:

| Piece | State |
|---|---|
| Database | Migrations 0001 to 0008 applied. The security self-check (`supabase/tests/rls_check.sql`) passes on it. |
| Demo data | 4 demo accounts, vitals and the symptom diary loaded, history moved up to today |
| Server functions | `food-search` and `analyze-food` deployed from this branch (with the daily AI-scan quota) |
| App | `ios/Config.local.xcconfig` points at it (git-ignored) |
| **API keys** | **Missing: you add them (below)** |

Commands below use `$REF`, your project ref. Set it once per Terminal window; it's read from the local config:

```bash
REF=$(sed -n 's/^SUPABASE_HOST *= *\([a-z0-9]*\)\..*/\1/p' ~/Desktop/NutraVision/ios/Config.local.xcconfig); echo $REF
```

## The one thing left: API keys

Without them:
- **Photo scanning fails** (no Anthropic key).
- **Food search and barcodes** fall back to the USDA's shared `DEMO_KEY`, which is limited to about 30
  searches an hour, shared with everyone else on Supabase's servers.

1. **Anthropic** (photo scanning): **console.anthropic.com** > Settings > Billing, add a few dollars of credit.
   Then **API Keys** > **Create Key**. A scan costs about 1 cent, and each user is capped at a daily number of
   scans (`0005_ai_scan_quota`).
2. **USDA** (food search, free): **fdc.nal.usda.gov/api-key-signup**. The key arrives by email.
3. Store both on the server. The keys are typed at hidden prompts, so they never appear on screen, in shell
   history or in the chat:

```bash
~/Desktop/NutraVision/scripts/set-api-keys.sh "$REF"
```

The functions pick up new secrets immediately, with no redeploy needed.

## Password reset (2 minutes, dashboard)

"Forgot password?" emails a link that opens the app. Two settings stop that working today:

1. **Allow the app's link.** Dashboard > **Authentication** > **URL Configuration** > **Redirect URLs** >
   **Add URL** > `nutravision://auth/reset` > Save. *(Right now the list is empty, so the email's link
   opens `localhost:3000` instead.)*
2. **Real email delivery.** Supabase's built-in mailer only sends to members of your Supabase organization,
   at a few emails an hour. For real users, set up custom SMTP (Authentication > Emails > SMTP Settings),
   for example with Resend or SendGrid's free tier. For the demo, test it with your own (team member) email.

## Day-to-day upkeep

Run these from `~/Desktop/NutraVision`. The Supabase CLI is at `~/.local/supabase-cli/supabase`, and you're
logged in.

**Demo looks stale** (an empty "today" for Maria, James or Alex): move the demo history forward.

```bash
~/.local/supabase-cli/supabase db query --remote="$REF" --yes -f supabase/demo_refresh.sql
```

**Redeploy the functions** after editing anything in `supabase/functions/`:

```bash
~/.local/supabase-cli/supabase functions deploy food-search analyze-food --remote="$REF" --use-api
```

**A new migration file** (`supabase/migrations/0009_...sql`): apply it, then rerun the self-check. The
self-check must print no error, and it rolls back after itself.

```bash
~/.local/supabase-cli/supabase db query --remote="$REF" --yes -f supabase/migrations/0009_name.sql
```

```bash
~/.local/supabase-cli/supabase db query --remote="$REF" --yes -f supabase/tests/rls_check.sql
```

**Verify a doctor** who signed up (doctors can't reach patients until verified): see
`supabase/admin/verify_doctor.sql`.

## Starting over on a new project

Only if you ever need a fresh project:

1. Create the project in the dashboard. Turn off **Authentication > Sign In / Providers > Email > Confirm
   email**.
2. In order, run every file in `supabase/migrations/` (0001 to 0008), then `seed.sql`, `demo_vitals.sql`,
   `demo_symptoms.sql`, then `tests/rls_check.sql`. Use the `db query ... -f` command above with the new ref.
3. Deploy the functions and set the keys (above).
4. Point the app at it:

```bash
~/Desktop/NutraVision/scripts/configure-ios.sh --supabase-url https://<ref>.supabase.co --anon-key <anon or publishable key>
```

Never use the `service_role` or `secret` key in the app.

## Demo accounts

All use the password `demo1234`.

| Email | Who |
|---|---|
| `doctor@nutravision.demo` | Dr. Priya Shah (verified), linked to all three patients |
| `maria@nutravision.demo` | Type 2 diabetes |
| `james@nutravision.demo` | Hypertension; one pending doctor recommendation |
| `alex@nutravision.demo` | Bodybuilding and IBS, with a symptom diary |

## Troubleshooting

| Symptom | Fix |
|---|---|
| "AI analysis failed" on photo scan | No `ANTHROPIC_API_KEY`, or no Anthropic credit |
| "Food database unavailable" | The USDA demo key is rate-limited. Add `FDC_API_KEY` |
| A new doctor "waiting for license verification" | Expected. Verify them with `supabase/admin/verify_doctor.sql` |
| Function logs | Dashboard > Edge Functions > pick one > Logs |
