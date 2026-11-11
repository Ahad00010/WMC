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

The authoritative stats migration `202611100004_authoritative_stats.sql` has already been applied to the WMC Supabase project. The `202611100005_ten_rider_limit.sql` migration has also been applied to the WMC project. Do not apply either again to that project. New projects need all migrations in order. The old prototype stats are not included in authoritative stats.

## Development

Run `npm ci --prefix server` and `npm test --prefix server`. Set the environment variables above and run `npm start --prefix server`. The browser must use HTTPS/WSS in production. Test with two real accounts and devices before relying on it, including qualifying, reconnect, finish ordering and a server restart. Client-reported legacy match RPCs remain in the existing database for compatibility with the currently deployed site and must be revoked only as part of an audited cutover; they are not used by this client.

The race server authenticates through the Supabase lobby RPC using the rider’s access token. PostgREST verifies the JWT and the RPC derives identity from `auth.uid()`; the server never accepts an identity from the client. JWTs remain usable until expiry even if a session is revoked, so this is not immediate sign-out revocation.

## In-session chat and emotes

Chat and emotes use the authenticated race WebSocket and are broadcast only to connected riders in the same room; they do not use the old client-authoritative match RPCs. Chat is ephemeral, is not persisted or replayed on reconnect, is limited to 180 characters and one message per rider per second, and is displayed as text. There is no moderation, reporting, or blocking system. Wheelie and nitro are three-second cosmetic effects; they do not modify server physics or results. Wheelie requires forward movement or throttle. The race server and website must both be updated for these features.

## AI riders

Lobbies and race grids are limited to 10 total riders, including AI. The host may fill unused slots with server-controlled AI before starting. Bots use the same movement physics and track-limit rules, but their pace and qualifying behavior have not been calibrated on real devices. At least two human connections are still required. AI races are excluded from authoritative career stats: the existing results database accepts only real profiles and would otherwise miscount places or reject the result. AI settings live in the race server room and are reset if that server restarts.

## Circuit selection

The selectable tracks are approximate centreline traces based on the supplied reference diagrams; they are not surveyed recreations, and their scenery uses the existing generic environment. The browser and server use the same circuit data. The host chooses before creating a lobby, and the server waits for all connected riders to load that circuit before starting. Switching circuits reloads the page; a guest returns to the lobby afterward. Per-circuit practice best laps are stored separately. All six layouts and AI behavior should be playtested on real desktop and Android devices. Deploy the website and race server from the same revision.

## Full-grid performance

On desktop and touch devices, once both real assets load, each visible opponent uses shared instanced parts from the textured Ducati and Marc rider; the procedural batch is retained as a loading/error fallback. Desktop uses the optimized Ducati asset for opponents while retaining the full local bike. Instances are frustum-culled per rider, created over several frames and share geometry and materials rather than cloning a full model per bike. Remote wheels are static; lean, wheelies, nitro and nameplates use the shared rider pose. Their map markers represent actual rider positions, so close riders can overlap at small map scales. Remote visuals interpolate server snapshots and predict at most 100 ms when a snapshot is late; this does not affect authoritative physics or timing. AI curvature is precomputed and common snapshots are serialized once per broadcast. These measures reduce work but do not guarantee 60 FPS on every device or eliminate freezes caused by network/server stalls; profile a real mobile device with a full grid.

### Mobile rendering budget

On coarse-pointer devices the renderer uses antialiasing and adaptive 3D resolution starting at 1.1, with a minimum of one drawing pixel per CSS pixel and a maximum of 1.25 (limited by device pixel ratio), to keep the road readable. The mobile bike is simplified with textures and named wheels retained; decorative trees are reduced and shadows disabled. Desktop is unchanged. Actual performance and road visibility must be tested on the affected phone.

## Disconnects and lag diagnostics

A lost connection has a 60-second race rejoin window. Explicitly leaving still ends a two-human session immediately; an expired connection now reports a connection loss instead. The client retries and replaces a silent WebSocket after 15 seconds with no received traffic. The server accepts three missed heartbeat intervals before terminating a dead socket. A disconnected rider coasts under neutral input; their race is not paused. Deploy both the website and race server for these changes.

The existing `/health/diagnostics` response includes aggregate `raceServer` counters: current rooms and connections, process-lifetime event-loop delay p95 and maximum in milliseconds, accumulated simulation time dropped after stalls over 250ms, and snapshots skipped because a socket's send buffer was full. Counters reset on server restart; event-loop delay includes the 20ms sampling interval. They do not identify a player or prove whether an individual phone or network is the bottleneck. Capture these numbers while the issue occurs, together with the approximate UTC time and test conditions; no tokens or private information are needed. The Render free tier and network route can still cause lag, and a server restart still ends active races.

## Race gaps

The race tower shows a gap to the rider immediately ahead when the authoritative server has timed both through the same sampled track position. An upward arrow means the gap has decreased; a downward arrow means it has increased. There is a small deadband to prevent flicker, and no arrow is shown until a trend can be compared for the same pair. Before a shared crossing, after an overtake, or when timing is otherwise unavailable, the gap is hidden rather than estimated from speed. Lapped riders show a lap gap, and finished riders use finish times. Track sample spacing makes live times approximate. History is bounded to approximately one lap per rider and has no effect on race physics or results.

## Rider nameplates

Practice and multiplayer show a rider's full display name and colored number plate just above the rider helmet. Tags follow the rendered rider’s movement, lean, and wheelie; multiplayer tags use the authoritative roster and the same smoothed poses as remote bikes; practice uses the signed-in profile, with the existing guest identity as fallback. Tags are screen-space DOM elements reused per rider rather than extra WebGL meshes or textures. They are culled behind the camera, off-screen, or beyond 350 metres; overlapping tags can stack upward with a stem toward the bike. This keeps mobile text readable at a fixed size but crowded grids can still overlap. Labels are projected every rendered frame to avoid visible lag behind moving bikes and the camera. Overlap stacking uses a stable rider order and eased vertical offsets, while the stem remains anchored to the bike. This increases per-frame DOM work on crowded grids, so test on real devices. Tags do not affect controls, network traffic, or physics.

The local Ducati uses `marc-rider.glb`, a static rider extracted from the user-supplied `marquez_on_bike.zip`, converted to glTF 2.0, simplified and selectively recolored to approximate the Ducati texture’s red. White, navy and dark panels and the separate original decals are preserved. To regenerate the suit texture from the archive, install Pillow and run `python3 scripts/recolor-marc-rider.py` from the repository root. It shares the existing rider lean and wheelie pivot; it is not a skeletal animation. If the rider asset fails to load, the procedural rider remains visible. Remote riders on both desktop and mobile share instanced textured versions of the bike and rider, with the procedural fallback if assets fail to load. The supplied archive did not include license or attribution information; verify rights before redistributing it. Fit and performance still require real-device visual testing.

## Practice with AI and desktop multiplayer

The practice circuit picker offers an optional nine-bot grid for both race and qualifying; with it unchecked practice stays solo. The browser runs the same AI steering and bike physics formulas as the server, with fixed substeps, real positions and lap timing. Practice bots are local, do not use multiplayer or career stats, and collide with the player while active; AI bikes can still pass through each other to prevent bot traffic jams. The current practice session ends when the player finishes or qualifying ends; no online result is saved. AI qualifying validity varies by track and should be playtested. `practice-ai.js` keeps copies of the server controller and physics functions; parity is checked by tests on every circuit.

Desktop shadows update every frame to keep the bike shadow aligned. Desktop circuit sections are culled when off-screen and high-DPI resolution can adapt during sustained slow frames. Actual desktop performance has not been measured.

## Bike contact

Active human riders collide with other active human and AI riders in authoritative multiplayer; practice uses the same swept contact logic between the player and practice AI. Approaching impacts transfer momentum and can reduce the striking bike’s speed or push the other bike forward or sideways; sideways drift decays over time. Separating or stationary riders are not repeatedly penalized. AI-to-AI contact is disabled to avoid gridlock; finished or retired riders no longer block the track. Collision bounds use heading-aligned capsules sized to the scaled Ducati: roughly 2.42m long and 0.86m wide. They are approximations rather than exact bike meshes; lean and animation are not reflected in the bounds. The browser predicts contact against displayed remote riders while snapshots are fresh, then reconciles to the authoritative server; latency can still affect how contact appears. Finished riders continue simulated movement without changing their recorded results so client prediction does not loop back to the finish. Both website and race server must be deployed for multiplayer contact changes. Test with real devices and connections.

## Multiplayer correction after contact

The race server remains authoritative. The client estimates one-way delay from an authenticated WebSocket ping (assuming roughly symmetric latency), extrapolates recent snapshots within a bounded window, and eases ordinary prediction errors with a speed-limited correction rather than teleporting at a fixed error distance. A server-issued reset sequence still allows an intentional reset to take effect immediately. The client only sends latency probes when the server advertises support, for compatibility with older deployments. Large delays, asymmetric routes, packet loss and visual interpolation can still make contact appear imperfect; test with both riders and the updated server.
