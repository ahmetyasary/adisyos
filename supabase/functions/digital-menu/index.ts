// Supabase Edge Function: digital-menu
//
// Public JSON API for restaurant menus + QR table orders (no JWT).
//
// GET  /functions/v1/digital-menu?t=<token>
// POST /functions/v1/digital-menu
//   body: { t, tableId, tableName?, items: [{id?, name, price, qty}], note? }
//
// Deploy:
//   supabase functions deploy digital-menu --no-verify-jwt
//
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, accept',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

function json(body: unknown, status = 200, cache = false) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': cache ? 'public, max-age=30' : 'no-store',
    },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceKey) {
    return json({ error: 'Sunucu yapılandırması eksik.' }, 500)
  }
  const admin = createClient(supabaseUrl, serviceKey)

  if (req.method === 'POST') {
    return handleOrder(req, admin)
  }
  if (req.method !== 'GET') {
    return json({ error: 'Yalnızca GET ve POST desteklenir.' }, 405)
  }

  const url = new URL(req.url)
  const token = (url.searchParams.get('t') ?? '').trim()
  if (!token) {
    return json({ error: 'Menü bağlantısı eksik.' }, 400)
  }

  const { data: cfg, error: cfgErr } = await admin
    .from('digital_menu_config')
    .select('tenant_id, menu_ids, enabled')
    .eq('token', token)
    .maybeSingle()

  if (cfgErr || !cfg) {
    return json({ error: 'Menü bulunamadı.' }, 404)
  }
  if (!cfg.enabled) {
    return json({ error: 'Bu dijital menü şu an kapalı.' }, 403)
  }

  const menuIds: number[] = Array.isArray(cfg.menu_ids) ? cfg.menu_ids : []
  if (menuIds.length === 0) {
    return json({ error: 'Henüz yayınlanan bir menü yok.' }, 404)
  }

  const tenantId = cfg.tenant_id as string

  const { data: settingsRows } = await admin
    .from('app_settings')
    .select('key, value')
    .eq('tenant_id', tenantId)
    .in('key', ['company_name', 'currency_symbol'])

  let companyName = 'Menü'
  let currency = '₺'
  for (const row of settingsRows ?? []) {
    if (row.key === 'company_name' && row.value) companyName = row.value
    if (row.key === 'currency_symbol' && row.value) currency = row.value
  }

  const { data: menus, error: menuErr } = await admin
    .from('menus')
    .select(
      'id, name, sort_order, menu_items(id, name, price, image_url, sort_order)',
    )
    .eq('tenant_id', tenantId)
    .in('id', menuIds)
    .order('sort_order')

  if (menuErr) {
    return json({ error: 'Menü yüklenemedi.' }, 500)
  }

  const orderMap = new Map(menuIds.map((id, i) => [id, i]))
  const sorted = [...(menus ?? [])].sort(
    (a, b) => (orderMap.get(a.id) ?? 0) - (orderMap.get(b.id) ?? 0),
  )

  const payload = {
    companyName,
    currency,
    menus: sorted.map((m) => {
      const items = [...(m.menu_items ?? [])].sort(
        (a: { sort_order?: number }, b: { sort_order?: number }) =>
          (a.sort_order ?? 0) - (b.sort_order ?? 0),
      )
      return {
        id: m.id,
        name: m.name,
        items: items.map((item: {
          id: number
          name: string
          price: number
          image_url?: string | null
        }) => ({
          id: item.id,
          name: item.name,
          price: Number(item.price),
          imageUrl: item.image_url ?? null,
        })),
      }
    }),
  }

  return json(payload, 200, true)
})

async function handleOrder(
  req: Request,
  // deno-lint-ignore no-explicit-any
  admin: any,
) {
  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Geçersiz istek gövdesi.' }, 400)
  }

  const token = String(body.t ?? '').trim()
  const tableIdRaw = body.tableId ?? body.table_id
  const tableId = Number(tableIdRaw)
  const tableName = String(body.tableName ?? body.table_name ?? '').trim()
  const note = String(body.note ?? body.customer_note ?? '').trim().slice(0, 500)
  const rawItems = Array.isArray(body.items) ? body.items : []

  if (!token) return json({ error: 'Menü bağlantısı eksik.' }, 400)
  if (!Number.isFinite(tableId) || tableId <= 0) {
    return json({ error: 'Masa bilgisi eksik. Lütfen masa QR kodunu kullanın.' }, 400)
  }
  if (rawItems.length === 0) {
    return json({ error: 'Sepet boş.' }, 400)
  }

  const { data: cfg, error: cfgErr } = await admin
    .from('digital_menu_config')
    .select('tenant_id, enabled')
    .eq('token', token)
    .maybeSingle()

  if (cfgErr || !cfg) return json({ error: 'Menü bulunamadı.' }, 404)
  if (!cfg.enabled) return json({ error: 'Bu dijital menü şu an kapalı.' }, 403)

  const tenantId = cfg.tenant_id as string

  const { data: table, error: tableErr } = await admin
    .from('tables')
    .select('id, name')
    .eq('tenant_id', tenantId)
    .eq('id', tableId)
    .maybeSingle()

  if (tableErr || !table) {
    return json({ error: 'Masa bulunamadı.' }, 404)
  }

  const items: Array<{
    id: number | null
    name: string
    price: number
    qty: number
  }> = []

  for (const it of rawItems) {
    if (!it || typeof it !== 'object') continue
    const row = it as Record<string, unknown>
    const name = String(row.name ?? '').trim()
    const price = Number(row.price)
    const qty = Math.max(1, Math.min(99, Math.floor(Number(row.qty ?? row.quantity ?? 1))))
    if (!name || !Number.isFinite(price) || price < 0) continue
    const idNum = Number(row.id)
    items.push({
      id: Number.isFinite(idNum) ? idNum : null,
      name: name.slice(0, 120),
      price,
      qty,
    })
  }

  if (items.length === 0) {
    return json({ error: 'Geçerli ürün yok.' }, 400)
  }

  const { data: inserted, error: insErr } = await admin
    .from('digital_menu_orders')
    .insert({
      tenant_id: tenantId,
      table_id: tableId,
      table_name: tableName || (table.name as string) || `Masa ${tableId}`,
      items,
      customer_note: note,
      status: 'pending',
      updated_at: new Date().toISOString(),
    })
    .select('id')
    .single()

  if (insErr) {
    console.error('digital_menu_orders insert', insErr)
    return json({ error: 'Sipariş gönderilemedi.' }, 500)
  }

  return json({
    ok: true,
    id: inserted?.id,
    message: 'Siparişiniz alındı. Onay bekleniyor.',
  })
}
