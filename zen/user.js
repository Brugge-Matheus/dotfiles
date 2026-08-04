// ============================================================
//  user.js — Zen Browser
//  Aceleração de vídeo por hardware (VA-API) na iGPU Intel (iHD)
//  Objetivo: YouTube/streaming em 1440p sem travar, decode na GPU
//  (Raptor Lake decodifica VP9 e AV1 em hardware).
//  Requer: intel-media-driver (VA-API iHD) — ver arch/packages/01-foundation.txt
//  Deploy: arch/install.sh copia/linka este arquivo no perfil ativo do Zen.
//  Este arquivo é lido na inicialização do Zen e sobrepõe o prefs.js.
// ============================================================

// Liga o decode de vídeo por hardware via FFmpeg + VA-API
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.enabled", true);

// Decode roda no processo RDD usando o backend FFmpeg/VA-API
user_pref("media.rdd-ffmpeg.enabled", true);

// Compositor WebRender (necessário para o pipeline acelerado)
user_pref("gfx.webrender.all", true);

// AV1 habilitado (YouTube serve 1440p+ em AV1; a iGPU decodifica em HW)
user_pref("media.av1.enabled", true);

// Não força fallback pra software quando o HW está disponível
user_pref("media.hardware-video-decoding.force-enabled", true);
