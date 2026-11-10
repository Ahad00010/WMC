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

The race server authenticates through the Supabase lobby RPC using the rider’s access token. PostgREST verifies the JWT and the RPC derives identity from `auth.uid()`; the server never accepts an identity from the client. JWTs remain usable until expiry even if a session is revoked, so this is not immediate sign-out revocation.

## In-session chat and emotes

Chat and emotes use the authenticated race WebSocket and are broadcast only to connected riders in the same room; they do not use the old client-authoritative match RPCs. Chat is ephemeral, is not persisted or replayed on reconnect, is limited to 180 characters and one message per rider per second, and is displayed as text. There is no moderation, reporting, or blocking system. Wheelie and nitro are three-second cosmetic effects; they do not modify server physics or results. Wheelie requires forward movement or throttle. The race server and website must both be updated for these features.

## AI riders

The host may fill unused slots with server-controlled AI before starting. Bots use the same movement physics and track-limit rules, but their pace and qualifying behavior have not been calibrated on real devices. At least two human connections are still required. AI races are excluded from authoritative career stats: the existing results database accepts only real profiles and would otherwise miscount places or reject the result. AI settings live in the race server room and are reset if that server restarts.

## Circuit selection

The selectable tracks are approximate centreline traces based on the supplied reference diagrams; they are not surveyed recreations, and their scenery uses the existing generic environment. The browser and server use the same circuit data. The host chooses before creating a lobby, and the server waits for all connected riders to load that circuit before starting. Switching circuits reloads the page; a guest returns to the lobby afterward. Per-circuit practice best laps are stored separately. All six layouts and AI behavior should be playtested on real desktop and Android devices. Deploy the website and race server from the same revision.

## Full-grid performance

Desktop and touch devices batch remote rider bodies into one instanced draw call and create riders over several frames. Desktop merges the detailed fallback rider and bike geometry into a single lit mesh and culls opponents outside the camera view; touch devices use a lighter low-poly mesh. Remote body shadows and desktop PBR materials are simplified; the local bike is unchanged. Their map markers represent actual rider positions, so close riders can overlap at small map scales. Remote visuals interpolate server snapshots and predict at most 100 ms when a snapshot is late; this does not affect authoritative physics or timing. AI curvature is precomputed and common snapshots are serialized once per broadcast. These measures reduce work but do not guarantee 60 FPS on every device or eliminate freezes caused by network/server stalls; profile a real mobile device with a full grid.

### Mobile rendering budget

On coarse-pointer devices the renderer uses adaptive 3D resolution (0.5–0.85 CSS pixels, starting at 0.75 and capped by the device's pixel ratio), no MSAA or dynamic shadow pass, fewer decorative trees, chunk-culling for track and barriers, a 10 Hz minimap and a 4 Hz standings tower. Physics, input and authoritative snapshots are not rate-limited by these visual settings. The same Ducati model is supplied as a lower-detail `bike-mobile.glb`, derived from the bundled `bike-model.txt` (Kenny3D89, CC BY 4.0). It retains named wheels and standard glTF compatibility. To regenerate using glTF Transform 4.5.1, base64-decode the original and run `gltf-transform optimize input.glb bike-mobile.glb --compress false --flatten false --instance false --join false --palette false --simplify-ratio 0.25 --simplify-error 0.005 --texture-size 512 --texture-compress auto`. Mobile bike materials use lighter lit shaders while retaining their textures; desktop retains the original local bike asset and graphics settings. The fallback built-in bike remains available if the mobile model fails to load. Test actual mobile GPU performance and appearance; neither a steady 60 FPS nor network/server responsiveness is guaranteed by the renderer changes.

## Race gaps

The race tower shows a gap to the rider immediately ahead when the authoritative server has timed both through the same sampled track position. An upward arrow means the gap has decreased; a downward arrow means it has increased. There is a small deadband to prevent flicker, and no arrow is shown until a trend can be compared for the same pair. Before a shared crossing, after an overtake, or when timing is otherwise unavailable, the gap is hidden rather than estimated from speed. Lapped riders show a lap gap, and finished riders use finish times. Track sample spacing makes live times approximate. History is bounded to approximately one lap per rider and has no effect on race physics or results.

## Rider nameplates

Practice and multiplayer show a rider's full display name and colored number plate just above the rider helmet. Tags follow the rendered rider’s movement, lean, and wheelie; multiplayer tags use the authoritative roster and the same smoothed poses as remote bikes; practice uses the signed-in profile, with the existing guest identity as fallback. Tags are screen-space DOM elements reused per rider rather than extra WebGL meshes or textures. They are culled behind the camera, off-screen, or beyond 350 metres; overlapping tags can stack upward with a stem toward the bike. This keeps mobile text readable at a fixed size but crowded grids can still overlap. Labels are projected every rendered frame to avoid visible lag behind moving bikes and the camera. Overlap stacking uses a stable rider order and eased vertical offsets, while the stem remains anchored to the bike. This increases per-frame DOM work on crowded grids, so test on real devices. Tags do not affect controls, network traffic, or physics.

The local Ducati uses `marc-rider.glb`, a static rider extracted from the user-supplied `marquez_on_bike.zip`, converted to glTF 2.0, simplified and recolored red. It shares the existing rider lean and wheelie pivot; it is not a skeletal animation. If the rider asset fails to load, the procedural rider remains visible. Remote riders retain the batched low-poly/detailed fallback visuals to avoid multiplying textured draw calls on a full grid. The supplied archive did not include license or attribution information; verify rights before redistributing it. Fit and performance still require real-device visual testing.
