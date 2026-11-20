# Papan Skor Pokédex Light Combo — Trainer Stadium

Papan skor interaktif Pokédex Light Combo dengan animasi avatar 2.5D, efek kartu TCG, dan API serverless Roblox untuk Vercel.

## Struktur Project
- `index.html`: Aplikasi scoreboard utama (juga dapat diakses melalui `/pokemon.html` via rewrite Vercel).
- `package.json`: Konfigurasi ES Module (`"type": "module"`) untuk Vercel Serverless Functions.
- `vercel.json`: Konfigurasi routing & rewrite endpoint API.
- `api/`:
  - `cari-roblox.js` (`/api/cari-roblox`): Pencarian profil & avatar Roblox.
  - `cookie-roblox.js` (`/api/cookie-roblox`): Validasi & status cookie Roblox.
  - `auto-add-friend.js` (`/api/auto-add-friend`): Fitur auto-add pertemanan Roblox.
