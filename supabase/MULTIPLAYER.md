> Historical prototype notes: the current game uses the authoritative race server; see `server/README.md`. Current lobbies and grids are limited to 10 riders.

# Multiplayer implementation and limitations

The site uses private friend lobbies, not a public matchmaking service or dedicated game server. The host starts a match with 2–15 lobby members. The database schedules the session start, tracks qualifying and race phase transitions, orders qualifying by the submitted best valid lap, assigns a random race-only grid, and records the order in which finish reports arrive. A match remains open until every remaining member reports completion. Closing the host's lobby removes it for everyone.

Each browser runs its own physics and sends position, progress and completion to Supabase about every 750 ms; remote bikes are visual interpolations and do not collide. This is a **client-authoritative prototype**, not a secure competitive server: modified clients can falsify laps, positions or results, and network latency can affect finish order. The polling rate and rendering have not been load-tested for 15 simultaneous riders. Internet interruption, tab throttling or a rider disconnecting can delay or indefinitely hold a session open; there is currently no automatic DNF or complete reconnect recovery. A trusted authoritative race server, dedicated real-time transport, abuse controls, and a disconnect policy are needed for reliable competitive multiplayer.

The app displays an intro and a shared scheduled start rather than claiming to find a dedicated server. The qualification timer remains 10 minutes, with up to five flying attempts. Live snapshots use caller-checked security-definer functions; table access is denied to anonymous and authenticated roles directly. The frontend requires a configured Supabase account and completed rider profile. Test with two separately signed-in accounts, and on real mobile devices, before relying on match results.

Migrations in `supabase/migrations` document database objects. The match migration was applied to the configured WMC Supabase project; do not re-run it against the same project. Practice mode remains local.
