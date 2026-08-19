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
Senin adın Ordi. Orderix adlı restoran/kafe adisyon uygulamasının içinde
çalışan Türkçe konuşan bir asistanısın. Kullanıcı işletme yöneticisidir.

SANA VERİLEN VERİ
Her soruyla "İŞLETME VERİSİ" JSON'u gelir. Sayısal cevapları YALNIZCA oradan ver.
Ayrıca "uygulamaKilavuzu" vardır: ekranlar, nasıl yapılır, terimler.

TERİMLER (karıştırma)
- açık hesap / açık adisyon = henüz ödenmemiş MASA. Süre: masalar.doluMasaDetay[].acikSureMetin
- açık gün = "Günü Bitir" yapılmamış çalışma oturumu. Süre: gunDurumu.aktifGunler[].sureMetin
- acikGunKaydi / acikGunSayisi = kaç oturum açık, SÜRE DEĞİLDİR. "Kaç gündür açık" sorusunda bunu cevap olarak kullanma.
- Follow-up: kullanıcı önce açık masaları sorduysa "kaç gündür açık hesap" o masanın süresidir; yoksa hem gün süresini hem masa süresini söyle.

KURALLAR
1. Veride olmayan sayıyı uydurma. Yoksa bunu söyle ve hangi ekrana bakılacağını yaz.
2. Uygulama hakkında her soruyu yanıtla: nasıl sipariş yazılır, gün nasıl kapanır, stok, rapor, personel, ödeme, indirim, masa taşıma. Kilavuzdaki ekran adlarını kullan.
3. Cevap varsayılan 80-160 kelime. Kullanıcı detay isterse uzat, en fazla 250 kelime.
4. Para: verideki paraBirimi, binlikte nokta, ondalıkta virgül (₺12.450,50).
5. En az bir işe yarar çıkarım veya sonraki adım ekle.
6. Düz metin. Liste için satır başı "• ". Vurgu için **iki yıldız**. Başlık/tablo/kod yok. Emoji yok.
7. Kullanıcıya "siz". Samimi ve net.
8. YAZMA ARAÇLARI
   Ekleme (hemen uygulanır, onay sorma, aracı çağır): create_table,
   add_section, add_menu_category, add_menu_item, add_staff, add_order,
   set_stock_new, start_day, clock_in, start_break.
   Değişiklik (uygulama Evet/Hayır soracak; sen yine aracı çağır,
   kullanıcıya ayrıca onay sorma): rename_table, rename_section,
   rename_menu_category, update_menu_item, set_stock, apply_discount,
   take_payment, partial_payment, move_orders, end_day, clock_out,
   end_break, set_company_name, set_currency, update_staff, advance_kitchen.
   SİLME YASAK: masa/ürün/kategori/personel/bölüm silme, sipariş iptali,
   masa temizleme, stok takibini kaldırma. Bu araçlar yok; istese de
   reddet ve “silme yapamam” de.
9. Alakasız konularda kibarca işletmeye ve uygulamaya çevir.
10. Araç çağırırken kısa bir cümle yaz. Eksik zorunlu alan varsa aracı
    çağırma; neyin eksik olduğunu söyle (eklemede “emin misiniz” sorma).
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

function extractActions(payload: any): { name: string; args: Record<string, unknown> }[] {
  const parts = payload?.candidates?.[0]?.content?.parts
  if (!Array.isArray(parts)) return []
  const out: { name: string; args: Record<string, unknown> }[] = []
  for (const p of parts) {
    const fc = p?.functionCall
    if (!fc?.name) continue
    const args = fc.args && typeof fc.args === 'object' ? fc.args : {}
    const name = String(fc.name)
    if (/delete|remove|clear|sil/i.test(name)) continue
    out.push({ name, args })
  }
  return out
}

const str = (d: string) => ({ type: 'STRING', description: d })
const num = (d: string) => ({ type: 'NUMBER', description: d })

const ORDI_TOOLS = [
  {
    functionDeclarations: [
      {
        name: 'create_table',
        description: 'Yeni masa. Ad yoksa onerilenSonrakiMasaAdi.',
        parameters: {
          type: 'OBJECT',
          properties: {
            name: str('Masa 14'),
            sectionName: str('Salon, Bahçe'),
          },
        },
      },
      {
        name: 'add_section',
        description: 'Yeni bölüm.',
        parameters: {
          type: 'OBJECT',
          properties: { name: str('Bölüm adı') },
          required: ['name'],
        },
      },
      {
        name: 'add_menu_category',
        description: 'Yeni menü kategorisi.',
        parameters: {
          type: 'OBJECT',
          properties: { name: str('Kategori') },
          required: ['name'],
        },
      },
      {
        name: 'add_menu_item',
        description: 'Kategori altına ürün. Kategori yoksa oluşturulur.',
        parameters: {
          type: 'OBJECT',
          properties: {
            category: str('Kategori'),
            name: str('Ürün'),
            price: num('25.5'),
          },
          required: ['category', 'name', 'price'],
        },
      },
      {
        name: 'add_staff',
        description: 'Personel ekle. PIN 4 hane zorunlu.',
        parameters: {
          type: 'OBJECT',
          properties: { name: str('Ad'), pin: str('4821') },
          required: ['name', 'pin'],
        },
      },
      {
        name: 'add_order',
        description: 'Masaya menüden sipariş ekle. Silme/iptal yok.',
        parameters: {
          type: 'OBJECT',
          properties: {
            table: str('Masa adı'),
            item: str('Ürün adı'),
            qty: num('Adet, varsayılan 1'),
          },
          required: ['table', 'item'],
        },
      },
      {
        name: 'set_stock_new',
        description: 'İlk kez stok takibi aç. Mevcut takip için set_stock kullan.',
        parameters: {
          type: 'OBJECT',
          properties: { item: str('Ürün'), count: num('Adet') },
          required: ['item', 'count'],
        },
      },
      {
        name: 'start_day',
        description: 'Çalışma gününü başlat.',
        parameters: { type: 'OBJECT', properties: {} },
      },
      {
        name: 'clock_in',
        description: 'Personeli vardiyaya al.',
        parameters: {
          type: 'OBJECT',
          properties: { staff: str('Personel adı, yoksa aktif personel') },
        },
      },
      {
        name: 'start_break',
        description: 'Personel molası başlat.',
        parameters: {
          type: 'OBJECT',
          properties: { staff: str('Personel adı') },
        },
      },
      {
        name: 'rename_table',
        description: 'Masa adını/bölümünü değiştir (onay gerekir).',
        parameters: {
          type: 'OBJECT',
          properties: {
            table: str('Mevcut ad'),
            newName: str('Yeni ad'),
            section: str('Opsiyonel bölüm'),
          },
          required: ['table', 'newName'],
        },
      },
      {
        name: 'rename_section',
        description: 'Bölüm adını değiştir (onay).',
        parameters: {
          type: 'OBJECT',
          properties: { section: str('Mevcut'), newName: str('Yeni') },
          required: ['section', 'newName'],
        },
      },
      {
        name: 'rename_menu_category',
        description: 'Kategori adını değiştir (onay).',
        parameters: {
          type: 'OBJECT',
          properties: { category: str('Mevcut'), newName: str('Yeni') },
          required: ['category', 'newName'],
        },
      },
      {
        name: 'update_menu_item',
        description: 'Ürün adı veya fiyatı (onay).',
        parameters: {
          type: 'OBJECT',
          properties: {
            category: str('Kategori'),
            name: str('Mevcut ürün'),
            newName: str('Yeni ad'),
            price: num('Yeni fiyat'),
          },
          required: ['name'],
        },
      },
      {
        name: 'set_stock',
        description: 'Mevcut stoğu güncelle (onay). Yeni takip: set_stock_new.',
        parameters: {
          type: 'OBJECT',
          properties: { item: str('Ürün'), count: num('Adet') },
          required: ['item', 'count'],
        },
      },
      {
        name: 'apply_discount',
        description: 'Masaya yüzde indirim (onay).',
        parameters: {
          type: 'OBJECT',
          properties: { table: str('Masa'), percent: num('0-100') },
          required: ['table', 'percent'],
        },
      },
      {
        name: 'take_payment',
        description: 'Masayı nakit veya kart ile kapat (onay). Sipariş silmez.',
        parameters: {
          type: 'OBJECT',
          properties: {
            table: str('Masa'),
            method: str('cash veya card / nakit veya kart'),
          },
          required: ['table'],
        },
      },
      {
        name: 'partial_payment',
        description: 'Ürün bazlı kısmi ödeme (onay).',
        parameters: {
          type: 'OBJECT',
          properties: {
            table: str('Masa'),
            item: str('Ürün'),
            qty: num('Adet'),
            method: str('cash veya card'),
          },
          required: ['table', 'item'],
        },
      },
      {
        name: 'move_orders',
        description: 'Tüm siparişleri başka masaya taşı (onay).',
        parameters: {
          type: 'OBJECT',
          properties: { from: str('Kaynak masa'), to: str('Hedef masa') },
          required: ['from', 'to'],
        },
      },
      {
        name: 'end_day',
        description: 'Günü kapat. Açık masa varken başarısız (onay).',
        parameters: { type: 'OBJECT', properties: {} },
      },
      {
        name: 'clock_out',
        description: 'Vardiyadan çıkar (onay).',
        parameters: {
          type: 'OBJECT',
          properties: { staff: str('Personel') },
        },
      },
      {
        name: 'end_break',
        description: 'Molayı bitir (onay).',
        parameters: {
          type: 'OBJECT',
          properties: { staff: str('Personel') },
        },
      },
      {
        name: 'set_company_name',
        description: 'İşletme adı (onay).',
        parameters: {
          type: 'OBJECT',
          properties: { name: str('Yeni ad') },
          required: ['name'],
        },
      },
      {
        name: 'set_currency',
        description: 'Para birimi sembolü (onay).',
        parameters: {
          type: 'OBJECT',
          properties: { symbol: str('₺ € $') },
          required: ['symbol'],
        },
      },
      {
        name: 'update_staff',
        description: 'Personel adı veya PIN (onay). Silme yok.',
        parameters: {
          type: 'OBJECT',
          properties: {
            staff: str('Mevcut ad'),
            newName: str('Yeni ad'),
            pin: str('4 hane'),
          },
          required: ['staff'],
        },
      },
      {
        name: 'advance_kitchen',
        description: 'Mutfak biletini pending→preparing→ready ilerlet (onay).',
        parameters: {
          type: 'OBJECT',
          properties: { table: str('Masa'), item: str('Ürün') },
          required: ['table'],
        },
      },
    ],
  },
]

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
      maxOutputTokens: 1400,
      ...(withThinking ? { thinkingConfig: thinkingConfigFor(model) } : {}),
    },
    tools: ORDI_TOOLS,
    toolConfig: { functionCallingConfig: { mode: 'AUTO' } },
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
          const actions = extractActions(parsed)
          if (answer || actions.length) {
            return json({ answer, actions, model, source: 'gemini' })
          }
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
