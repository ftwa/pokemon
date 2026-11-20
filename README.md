# Papan Skor Pokédex Light Combo — Trainer Stadium & Mode Auto

Papan skor interaktif Pokédex Light Combo dengan **Mode Auto-Skor Roblox (`inject.lua` → `/api/catch` → `ntfy.sh` Live SSE)**, animasi avatar 2.5D, efek kartu TCG holografik, dan API serverless untuk Vercel.

## Struktur Project
- `index.html`: Aplikasi scoreboard utama + Panel **⚡ Mode Auto-Skor** (juga dapat diakses melalui `/pokemon.html` via rewrite Vercel).
- `inject.lua`: Script bridge zero-lag untuk Roblox Executor (Fish It) dengan dual-delivery (`/api/catch` + fallback `ntfy.sh`).
- `package.json`: Konfigurasi ES Module (`"type": "module"`) untuk Vercel Serverless Functions.
- `vercel.json`: Konfigurasi routing & rewrite endpoint API.
- `api/`:
  - `catch.js` (`/api/catch`): Penerima tangkapan otomatis dari Roblox Executor & broadcaster SSE.
  - `cari-roblox.js` (`/api/cari-roblox`): Pencarian profil & avatar Roblox.
  - `cookie-roblox.js` (`/api/cookie-roblox`): Validasi & status cookie Roblox.
  - `auto-add-friend.js` (`/api/auto-add-friend`): Fitur auto-add pertemanan Roblox.
