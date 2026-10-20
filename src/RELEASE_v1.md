# v1.0 release steps

Do these in order when v1.0 is approved. Until step 4, the live app keeps working as before.

1. **Database.** Supabase → SQL Editor: run parts 1–3 of `migrate_v1.sql` (sadhana settings, opt-in sangha, push tables).
2. **Notification keys.** Generate a VAPID key pair (Claude does this at release time).
   - Public key → `config.json` as `VAPID_PUBLIC`.
   - Supabase → Edge Functions → Secrets: `VAPID_PUBLIC`, `VAPID_PRIVATE`, `VAPID_SUBJECT` (`mailto:` your email).
3. **Push function.** Deploy `supabase/functions/push-tick` (Dashboard → Edge Functions → Deploy new function, paste `index.ts`). Then put the project URL and anon key into part 4 of `migrate_v1.sql` and run it.
4. **App.** Run `build.py`, commit the built site to `main`, push. Phones pick up the update on next launch.
5. **First open.** Each person sees "Make the checklist your own", the setup steps and the tour once.
