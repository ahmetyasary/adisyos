// Supabase Edge Function: delete-account
//
// Permanently deletes the authenticated user from auth.users using the
// service role key. Required for Apple App Store Guideline 5.1.1(v)
// compliance (in-app account deletion).
//
// Deploy:
//   supabase functions deploy delete-account
//
// The function expects the client's access token in the Authorization
// header (Supabase client adds this automatically when you call
// `supabase.functions.invoke('delete-account')` while signed in).
//
// @ts-nocheck  —  this file runs on Deno. The triple-slash directive above
// tells VSCode/Cursor to load Deno's ambient types so autocomplete works
// even without the Deno extension. The `ts-nocheck` silences any remaining
// module resolution warnings from IDE's Node-flavoured TS server; the
// Supabase CLI bundles this file with Deno so runtime is unaffected.
/* eslint-disable */
// @ts-nocheck

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const jsonHeaders = {
  ...corsHeaders,
  'Content-Type': 'application/json',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const jwt = authHeader.replace('Bearer ', '').trim()
    if (!jwt) {
      return json({ error: 'missing_authorization' }, 401)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!supabaseUrl || !serviceKey) {
      return json(
        { error: 'server_misconfigured', detail: 'env vars missing' },
        500,
      )
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const {
      data: { user },
      error: getUserErr,
    } = await admin.auth.getUser(jwt)
    if (getUserErr || !user) {
      return json(
        { error: 'invalid_session', detail: getUserErr?.message },
        401,
      )
    }

    // Delete the auth user. Any tables with a FK to auth.users(id) that are
    // ON DELETE CASCADE will be cleaned up automatically. If your schema
    // does not cascade, add explicit deletes here before this call, e.g.:
    //   await admin.from('orders').delete().eq('user_id', user.id)
    const { error: delErr } = await admin.auth.admin.deleteUser(user.id)
    if (delErr) {
      return json(
        { error: 'delete_failed', detail: delErr.message },
        500,
      )
    }

    return json({ ok: true, id: user.id })
  } catch (e) {
    return json(
      { error: 'unhandled', detail: e instanceof Error ? e.message : String(e) },
      500,
    )
  }
})
