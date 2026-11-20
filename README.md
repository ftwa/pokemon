# Papan Skor Pokédex Light Combo — Trainer Stadium & Mode Auto (ntfy.sh)

Papan skor interaktif Pokédex Light Combo dengan **Mode Auto-Skor langsung via `ntfy.sh` Live SSE**, animasi avatar 2.5D, efek kartu TCG holografik, dan API utilitas Roblox.

## Struktur Project
- `index.html`: Aplikasi scoreboard utama + Panel **⚡ Mode Auto (ntfy.sh)** (juga dapat diakses melalui `/pokemon.html` via rewrite Vercel).
- `inject.lua`: Script bridge zero-lag untuk Roblox Executor (Fish It) yang mengirim langsung ke `ntfy.sh`.
- `package.json`: Konfigurasi ES Module (`"type": "module"`) untuk Vercel Serverless Functions.
- `vercel.json`: Konfigurasi routing & rewrite endpoint API.
- `api/`:
  - `cari-roblox.js` (`/api/cari-roblox`): Pencarian profil & avatar Roblox.
  - `cookie-roblox.js` (`/api/cookie-roblox`): Validasi & status cookie Roblox.
  - `auto-add-friend.js` (`/api/auto-add-friend`): Fitur auto-add pertemanan Roblox.
