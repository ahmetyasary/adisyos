// Supabase Edge Function: ordi
//
// Server-side brain for the "Ordi" in-app assistant. The Gemini API key lives
// here and never reaches the client, so it cannot be extracted from a shipped
// .ipa/.apk.
//
// Responsibilities:
//   1. Authenticate the caller and require the `admin` role — Ordi answers
//      questions about revenue, so staff sessions must not reach it.
//   2. Enforce a per-tenant daily question quota so one tenant cannot burn the
//      whole project's free-tier Gemini allowance.
//   3. Forward question + pre-aggregated business snapshot to Gemini and return
//      the answer as plain text.
//
// Deploy:
//   supabase secrets set GEMINI_API_KEY=...
//   supabase functions deploy ordi
//
// Optional secrets:
//   ORDI_MODEL        — pin a single model instead of the built-in chain
//   ORDI_DAILY_LIMIT  — questions per tenant per day (default 120)
//
// If this function is unreachable or out of quota the Flutter client falls back
// to its own offline rule-based answers, so a failure here degrades the feature
// rather than breaking it.
//
/* eslint-disable */
// @ts-nocheck

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const jsonHeaders = { ...corsHeaders, 'Content-Type': 'application/json' }

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders })
}

// ── Limits ───────────────────────────────────────────────────────────────
// The snapshot is built by the client from data it already holds in memory.
// These caps bound both the Gemini bill and the blast radius of a tampered
// client sending a huge payload.
const MAX_QUESTION_CHARS = 1000
const MAX_CONTEXT_CHARS = 60000
const MAX_HISTORY_TURNS = 8

// Free-tier Flash models, best first. A model that has been retired or is
// rate-limited falls through to the next one, so the function keeps working
// without a redeploy when Google rotates its lineup.
const MODEL_CHAIN = [
  'gemini-3.6-flash',
  'gemini-3.5-flash',
  'gemini-3-flash-preview',
  'gemini-3.1-flash-lite',
]

const SYSTEM_PROMPT = `
Senin adın Ordi. Orderix adlı restoran/kafe adisyon ve işletme yönetimi
uygulamasının içinde çalışan Türkçe konuşan bir yapay zeka asistanısın.
Kullanıcı işletme sahibi ya da yöneticisidir.

SANA VERİLEN VERİ
Her soruyla birlikte "İŞLETME VERİSİ" başlığı altında, uygulamanın o anki
canlı verisinden üretilmiş bir JSON özeti alırsın. Tüm sayısal cevaplarını
YALNIZCA bu veriye dayandır.

KURALLAR
1. Veride olmayan bir sayıyı asla uydurma. Bilgi yoksa "Bu veriye şu an
   erişemiyorum" de ve kullanıcıya uygulamada nereye bakabileceğini söyle.
2. Kısa ve net konuş. Cevap 120 kelimeyi geçmesin. Kullanıcı detay isterse uzat.
3. Para tutarlarını verideki "paraBirimi" sembolü ile ve binlik ayraçlı yaz
   (örnek: ₺12.450,50). Ondalıkta virgül, binlikte nokta kullan.
4. Sadece rakam sıralamakla kalma; en az bir tane işe yarar çıkarım veya öneri
   ekle (örnek: "Dün aynı saatte %20 daha fazlaydı, akşam vardiyasına bakın").
5. Biçim: düz metin. Başlık, tablo, kod bloğu ve markdown kullanma. Listeler
   için satır başına "• " koy. Vurgu için **iki yıldız** kullanabilirsin.
6. Sadece bu işletme, verileri ve restoran işletmeciliği hakkında konuş.
   Alakasız konularda kibarca konuyu işletmeye çevir.
7. Emoji kullanma. Samimi ama profesyonel bir ton kullan, kullanıcıya "siz"
   diye hitap et.
8. Kullanıcı bir işlem yapmanı isterse (masa açma, sipariş ekleme, silme gibi)
   bunu yapamayacağını, sadece okuyup analiz ettiğini söyle ve uygulamada
   hangi ekrandan yapabileceğini anlat.
`.trim()

/** Extracts the concatenated text of the first candidate, or '' if none. */
function extractText(payload: any): string {
  const parts = payload?.candidates?.[0]?.content?.parts
  if (!Array.isArray(parts)) return ''
  return parts
    .map((p: any) => (typeof p?.text === 'string' ? p.text : ''))
    .join('')
    .trim()
}

/** Thinking is configured differently across generations; 3.x rejects the 2.5 field. */
function thinkingConfigFor(model: string) {
  if (model.startsWith('gemini-2.5')) return { thinkingBudget: 0 }
  return { thinkingLevel: 'low' }
}

async function callGemini(
  apiKey: string,
  model: string,
  contents: unknown,
  withThinking: boolean,
) {
  const body: Record<string, unknown> = {
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents,
    generationConfig: {
      temperature: 0.4,
      topP: 0.9,
      maxOutputTokens: 900,
      ...(withThinking ? { thinkingConfig: thinkingConfigFor(model) } : {}),
    },
    safetySettings: [],
  }

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify(body),
    },
  )

  const raw = await res.text()
  let parsed: any = null
  try {
    parsed = JSON.parse(raw)
  } catch {
    // Non-JSON body (proxy error page etc.) — keep `raw` for the log line.
  }
  return { status: res.status, parsed, raw }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405)
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const apiKey = Deno.env.get('GEMINI_API_KEY')

    if (!supabaseUrl || !serviceKey) {
      return json({ error: 'server_misconfigured', detail: 'supabase env' }, 500)
    }
    if (!apiKey) {
      // The client treats this as "use the offline brain".
      return json({ error: 'no_api_key' }, 503)
    }

    // ── Authenticate ─────────────────────────────────────────────────────
    const jwt = (req.headers.get('Authorization') ?? '')
      .replace('Bearer ', '')
      .trim()
    if (!jwt) return json({ error: 'missing_authorization' }, 401)

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const {
      data: { user },
      error: userErr,
    } = await admin.auth.getUser(jwt)
    if (userErr || !user) {
      return json({ error: 'invalid_session', detail: userErr?.message }, 401)
    }

    // ── Authorise: admin only ────────────────────────────────────────────
    const { data: profile, error: roleErr } = await admin
      .from('users')
      .select('roles(name)')
      .eq('id', user.id)
      .single()

    if (roleErr || (profile as any)?.roles?.name !== 'admin') {
      return json({ error: 'forbidden', detail: 'admin_only' }, 403)
    }

    // ── Daily quota (per tenant) ─────────────────────────────────────────
    const dailyLimit = Number(Deno.env.get('ORDI_DAILY_LIMIT') ?? '120')
    const since = new Date()
    since.setUTCHours(0, 0, 0, 0)

    const { count } = await admin
      .from('ordi_chats')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', user.id)
      .eq('role', 'user')
      .gte('created_at', since.toISOString())

    if (typeof count === 'number' && count >= dailyLimit) {
      return json({ error: 'daily_limit', limit: dailyLimit }, 429)
    }

    // ── Validate payload ────────────────────────────────────────────────
    let payload: any
    try {
      payload = await req.json()
    } catch {
      return json({ error: 'bad_request', detail: 'invalid_json' }, 400)
    }

    const question = String(payload?.question ?? '').trim()
    if (!question) return json({ error: 'bad_request', detail: 'empty_question' }, 400)
    if (question.length > MAX_QUESTION_CHARS) {
      return json({ error: 'bad_request', detail: 'question_too_long' }, 400)
    }

    const contextJson = JSON.stringify(payload?.context ?? {})
    if (contextJson.length > MAX_CONTEXT_CHARS) {
      return json({ error: 'bad_request', detail: 'context_too_large' }, 413)
    }

    // Prior turns give Ordi enough memory for follow-ups ("peki dün?") without
    // resending the whole conversation.
    const history = Array.isArray(payload?.history)
      ? payload.history.slice(-MAX_HISTORY_TURNS)
      : []

    const contents = [
      ...history.flatMap((turn: any) => {
        const text = String(turn?.text ?? '').trim()
        if (!text) return []
        const role = turn?.role === 'assistant' ? 'model' : 'user'
        return [{ role, parts: [{ text: text.slice(0, 2000) }] }]
      }),
      {
        role: 'user',
        parts: [
          {
            text:
              `İŞLETME VERİSİ (canlı, JSON):\n${contextJson}\n\n` +
              `KULLANICININ SORUSU:\n${question}`,
          },
        ],
      },
    ]

    // ── Ask Gemini ──────────────────────────────────────────────────────
    const pinned = Deno.env.get('ORDI_MODEL')
    const models = pinned ? [pinned, ...MODEL_CHAIN] : MODEL_CHAIN

    let lastStatus = 0
    let lastDetail = ''

    for (const model of models) {
      for (const withThinking of [true, false]) {
        const { status, parsed, raw } = await callGemini(
          apiKey,
          model,
          contents,
          withThinking,
        )

        if (status === 200) {
          const answer = extractText(parsed)
          if (answer) return json({ answer, model, source: 'gemini' })
          // 200 with no text means the answer was filtered or truncated.
          lastStatus = 502
          lastDetail =
            parsed?.candidates?.[0]?.finishReason ?? 'empty_candidate'
          break
        }

        lastStatus = status
        lastDetail = parsed?.error?.message ?? raw.slice(0, 300)

        // 400 INVALID_ARGUMENT is usually the thinking field this generation
        // doesn't know — worth one retry without it before changing model.
        if (status === 400 && withThinking) continue

        // Retrying the same model won't help for these; move on.
        break
      }

      // Quota/permission problems are key-wide, not model-specific.
      if (lastStatus === 401 || lastStatus === 403) break
    }

    console.error(`[ordi] gemini failed status=${lastStatus} detail=${lastDetail}`)
    return json(
      { error: 'gemini_unavailable', status: lastStatus, detail: lastDetail },
      503,
    )
  } catch (e) {
    console.error('[ordi] unhandled', e)
    return json(
      { error: 'unhandled', detail: e instanceof Error ? e.message : String(e) },
      500,
    )
  }
})
