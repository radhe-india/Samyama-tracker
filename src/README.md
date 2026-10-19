# Samyama Sadhana – source

- `index.html` – the app (single file). Cloud keys are filled in at build time.
- `build.py` – builds the installable site into the repository root. It expects to live in `deploy/` next to `../index.html`; to rebuild here, copy `index.html` one level up or adjust the paths.
- `config.json` – Supabase project URL and publishable key (safe to be public).
- `setup.sql` – Supabase tables, privacy rules and admin setup.
- `sw.template.js` – offline support; `icon.html` – source for the app icon.

Live app: https://radhe-india.github.io/Samyama-tracker/
