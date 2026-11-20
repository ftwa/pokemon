// api/catch.js - Cloud Auto-Skor & Live Sync Engine untuk Pokédex Scoreboard
// Berjalan di Vercel Serverless + broadcast real-time via ntfy.sh SSE Bus

const DEFAULT_TOPIC = 'pokedex_auto_skor_live_bus_v1';

// Buffer in-memory untuk tangkapan terbaru (bertahan selama instance serverless hangat)
const RECENT_CATCHES = [];
const MAX_RECENT = 100;

let CONFIG_RULES = {
  forgotten: 4,
  secret: 3,
  mitos: 2,
  legend: 1,
  big: 1,
  shiny: 1,
  mutasi: 1,
  khususNama: '',
  khususBase: 5,
  khususBig: 2,
  khususShiny: 2,
  khususMutasi: 3
};

function sanitizeTopic(raw) {
  const clean = String(raw || DEFAULT_TOPIC)
    .trim()
    .replace(/[^a-zA-Z0-9_\-]/g, '');
  return clean || DEFAULT_TOPIC;
}

function hitungPoin(tierStr, namaIkan, varianStr, customRules = null) {
  const tierClean = String(tierStr || '').toLowerCase().trim();
  const namaClean = String(namaIkan || '').toLowerCase().trim();
  const varianClean = String(varianStr || '').toLowerCase().trim();

  const rules = { ...CONFIG_RULES, ...(customRules || {}) };
  const targetKhusus = String(rules.khususNama || '').toLowerCase().trim();

  // 1. Cek Ikan Khusus
  let isKhusus = false;
  if (targetKhusus && namaClean) {
    const list = targetKhusus.split(',').map(s => s.trim()).filter(Boolean);
    if (list.some(k => namaClean.includes(k))) {
      isKhusus = true;
    }
  }

  const teksCek = `${namaIkan} ${varianStr}`.toUpperCase();
  const bukanMutasi = ['none', '-', 'no', 'normal', '', 'shiny', 'big'];
  const varianTokens = varianClean
    .split(',')
    .map(v => v.trim())
    .filter(v => v && !bukanMutasi.includes(v));

  if (isKhusus || tierClean.includes('khusus') || tierClean.includes('special')) {
    const base = Number(rules.khususBase) || 5;
    let total = base;
    const rincian = [`ikan khusus +${base}`];

    if (/\bBIG\b/.test(teksCek)) {
      const b = Number(rules.khususBig) || 0;
      if (b > 0) { total += b; rincian.push(`big +${b}`); }
    }
    if (/\bSHINY\b/.test(teksCek)) {
      const s = Number(rules.khususShiny) || 0;
      if (s > 0) { total += s; rincian.push(`shiny +${s}`); }
    }
    if (varianTokens.length > 0) {
      const m = Number(rules.khususMutasi) || 0;
      if (m > 0) { total += m; rincian.push(`mutasi +${m}`); }
    }
    return { poin: total, rincian: rincian.join(', '), kategori: 'khusus', valid: true };
  }

  // 2. Kategori Tier Standar
  let kategori = 'legend';
  if (tierClean.includes('forgotten')) {
    kategori = 'forgotten';
  } else if (tierClean.includes('secret')) {
    kategori = 'secret';
  } else if (tierClean.includes('mythic') || tierClean.includes('mitos')) {
    kategori = 'mitos';
  } else if (tierClean.includes('legend')) {
    kategori = 'legend';
  } else if (['normal', 'rare', 'common', 'uncommon'].includes(tierClean)) {
    return { poin: 0, rincian: 'Bukan Tier Turnamen', kategori: 'normal', valid: false };
  }

  const poinDasarMap = {
    forgotten: Number(rules.forgotten) || 4,
    secret: Number(rules.secret) || 3,
    mitos: Number(rules.mitos) || 2,
    legend: Number(rules.legend) || 1
  };
  const basePoint = poinDasarMap[kategori] || 1;
  let total = basePoint;
  const rincian = [`${kategori} +${basePoint}`];

  if (/\bBIG\b/.test(teksCek)) {
    const b = Number(rules.big) || 0;
    if (b > 0) { total += b; rincian.push(`big +${b}`); }
  }
  if (/\bSHINY\b/.test(teksCek)) {
    const s = Number(rules.shiny) || 0;
    if (s > 0) { total += s; rincian.push(`shiny +${s}`); }
  }
  if (varianTokens.length > 0) {
    const m = Number(rules.mutasi) || 0;
    if (m > 0) { total += m; rincian.push(`mutasi +${m}`); }
  }

  return { poin: total, rincian: rincian.join(', '), kategori, valid: true };
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'GET') {
    return res.status(200).json({
      sukses: true,
      mode: 'POKEDEX_AUTO_CLOUD',
      topic: DEFAULT_TOPIC,
      rules: CONFIG_RULES,
      total: RECENT_CATCHES.length,
      catches: RECENT_CATCHES.slice(-25)
    });
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ sukses: false, pesan: 'Method Not Allowed' });
  }

  try {
    let body = req.body;
    if (typeof body === 'string') {
      try { body = JSON.parse(body); } catch (_) {}
    }
    body = body || {};

    if (body.rules && typeof body.rules === 'object') {
      CONFIG_RULES = { ...CONFIG_RULES, ...body.rules };
    }
    if (body.ikanKhususNama !== undefined) {
      CONFIG_RULES.khususNama = String(body.ikanKhususNama).trim();
    }

    const username = String(body.username || body.player || body.user || '').trim();
    const displayName = String(body.displayName || body.player || username).trim();
    const userId = Number(body.userId || 0) || 0;
    const rawFish = String(body.fish || body.ikan || '').trim();
    const rawVariant = String(body.variant || body.varian || '').trim();
    const rawTier = String(body.tier || body.kategori || '').trim();
    const topic = sanitizeTopic(body.room || body.topic || DEFAULT_TOPIC);

    if (!displayName || !rawFish) {
      return res.status(400).json({
        sukses: false,
        pesan: 'Data tidak lengkap (player dan fish wajib diisi).'
      });
    }

    const variantClean = (rawVariant && !['none', '-', ''].includes(rawVariant.toLowerCase())) ? rawVariant : '';
    const fullFishName = variantClean ? `${variantClean} ${rawFish}` : rawFish;
    const kalkulasi = hitungPoin(rawTier, rawFish, variantClean, CONFIG_RULES);

    if (!kalkulasi.valid || kalkulasi.poin <= 0) {
      return res.status(200).json({
        sukses: true,
        status: 'ignored',
        pesan: `Ikan '${fullFishName}' bukan tier turnamen (0 poin).`
      });
    }

    const eventId = String(body.id || `px_catch_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`);
    const catchEvent = {
      id: eventId,
      type: 'SYNC_CATCH',
      user: displayName,
      displayName,
      username: username || displayName,
      userId,
      ikan: fullFishName,
      fish: rawFish,
      variant: variantClean,
      rincian: kalkulasi.rincian,
      poin: kalkulasi.poin,
      kategori: kalkulasi.kategori,
      tier: kalkulasi.kategori,
      source: 'vercel_api',
      timestamp: Number(body.timestamp) || Date.now()
    };

    RECENT_CATCHES.push(catchEvent);
    if (RECENT_CATCHES.length > MAX_RECENT) RECENT_CATCHES.shift();

    let ntfyDelivered = false;
    try {
      const ntfyRes = await fetch(`https://ntfy.sh/${topic}`, {
        method: 'POST',
        headers: {
          'Title': 'Pokedex Auto Skor Catch',
          'Priority': 'urgent'
        },
        body: JSON.stringify(catchEvent)
      });
      ntfyDelivered = ntfyRes.ok;
    } catch (ntfyErr) {
      console.warn('[Pokedex Auto] ntfy broadcast error:', ntfyErr.message);
    }

    return res.status(200).json({
      sukses: true,
      status: 'ok',
      topic,
      ntfyDelivered,
      data: catchEvent
    });
  } catch (err) {
    console.error('[Pokedex Auto] /api/catch error:', err);
    return res.status(500).json({
      sukses: false,
      pesan: 'Internal Server Error: ' + err.message
    });
  }
}
