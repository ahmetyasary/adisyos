// Supabase Edge Function: digital-menu
//
// Public JSON API for restaurant menus (no JWT). HTML is served from Storage
// (`public-menu/index.html`) because the Edge gateway forces `text/plain` for
// HTML bodies — Safari then shows source / downloads .txt.
//
// GET /functions/v1/digital-menu?t=<token>
// Accept: application/json  (always returns JSON)
//
// Deploy:
//   supabase functions deploy digital-menu --no-verify-jwt
//
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, accept',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=30',
    },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'GET') {
    return json({ error: 'Yalnızca GET desteklenir.' }, 405)
  }

  const url = new URL(req.url)
  const token = (url.searchParams.get('t') ?? '').trim()
  if (!token) {
    return json({ error: 'Menü bağlantısı eksik.' }, 400)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceKey) {
    return json({ error: 'Sunucu yapılandırması eksik.' }, 500)
  }

  const admin = createClient(supabaseUrl, serviceKey)

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

  return json(payload)
})
