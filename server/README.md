# WMC race server: Render setup

This server runs authoritative simulation in one Node process. The GitHub Pages site continues to use Supabase for Google login and friend lobbies. Multiplayer start remains disabled until the site's `race-server-config.js` contains the server URL. A server restart currently aborts in-progress races; it does not restore rooms from disk. Free hosting is for testing, not guaranteed race availability.

## Create the service

1. At https://render.com create an account, link GitHub, and create **New → Web Service** using the `Ahad00010/WMC` repository. Choose the `main` branch and **Free** instance. Leave Root Directory blank (the server reads `index.html` for the exact track geometry).
2. Set runtime to **Node**. Build command: `npm ci --prefix server --omit=dev`. Start command: `npm start --prefix server`. Render provides `PORT` automatically.
3. Under Environment add:
   - `SUPABASE_URL`: `https://siwvtpijqgtshaknzoyb.supabase.co`
   - `SUPABASE_PUBLISHABLE_KEY`: the public publishable key in `auth-config.js`.
   - `ALLOWED_ORIGINS`: `https://ahad00010.github.io` (an origin, without `/WMC/` or a trailing slash).
   - `SUPABASE_SECRET_KEY`: the project's **secret key** (`sb_secret_…`), copied directly from the Supabase dashboard into Render's private environment setting. Never put this in Git, browser code, or chat. This is optional for a test, but without it the server cannot record race stats. The key has broad access, so restrict access to the Render dashboard. The older variable names `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` remain supported; if both old and new variables are set, the new names take priority. See https://supabase.com/docs/guides/api/api-keys.
4. Deploy. Open `https://YOUR-SERVICE.onrender.com/health`; it should return `{"ok":true}`. Do not send keys, passwords or screenshots containing them to anyone.
5. The public server address is `wss://YOUR-SERVICE.onrender.com/race`. The site must be configured with that URL before multiplayer can start. Give the developer only the public URL; never share secrets. Use a single server instance: rooms currently live in one process.
6. For monitoring, create an UptimeRobot HTTP(s) monitor for `https://YOUR-SERVICE.onrender.com/health`, at the free 5-minute interval. This can keep an idle service warm, but cannot prevent outages, restarts or quota limits. It tests HTTP availability, not race correctness.

The authoritative stats migration `202611100004_authoritative_stats.sql` has already been applied to the WMC Supabase project. Do not apply it again to that project. New projects need all migrations in order. The old prototype stats are not included in authoritative stats.

## Development

Run `npm ci --prefix server` and `npm test --prefix server`. Set the environment variables above and run `npm start --prefix server`. The browser must use HTTPS/WSS in production. Test with two real accounts and devices before relying on it, including qualifying, reconnect, finish ordering and a server restart. Client-reported legacy match RPCs remain in the existing database for compatibility with the currently deployed site and must be revoked only as part of an audited cutover; they are not used by this client.
