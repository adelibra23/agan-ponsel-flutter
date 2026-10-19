import http from 'node:http';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { resolve } from 'node:path';
import { JsonState } from './state.mjs';
import { Agent, extractMessages } from './agent.mjs';
import { askAi } from './ai.mjs';

function constantEquals(a, b) {
  const aa = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  return aa.length === bb.length && timingSafeEqual(aa, bb);
}
function readBody(req, max = 512000) {
  return new Promise((resolve, reject) => {
    let chunks = [], bytes = 0;
    req.on('data', x => {
      bytes += x.length;
      if (bytes > max) {
        reject(Error('Payload terlalu besar'));
        req.destroy();
        return;
      }
      chunks.push(x);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}
function reply(res, status, value) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
  res.end(JSON.stringify(value));
}

export function fromEnv(env = process.env) {
  let facts = {};
  try { facts = JSON.parse(env.SHOP_FACTS_JSON || '{}'); }
  catch { throw Error('SHOP_FACTS_JSON harus berisi JSON yang valid'); }
  if (!facts || typeof facts !== 'object' || Array.isArray(facts)) {
    throw Error('SHOP_FACTS_JSON harus objek JSON');
  }
  return {
    port: Number(env.PORT || 3000), host: env.HOST || '0.0.0.0',
    filename: resolve(env.DATA_FILE || './data/agana-wa.json'),
    waToken: env.WA_ACCESS_TOKEN || '',
    waPhoneId: env.WA_PHONE_NUMBER_ID || '',
    waVerifyToken: env.WA_VERIFY_TOKEN || '',
    waAppSecret: env.WA_APP_SECRET || '',
    waVersion: env.WA_GRAPH_VERSION || 'v24.0',
    adminToken: env.ADMIN_TOKEN || '',
    aiProvider: env.AI_PROVIDER || 'groq',
    aiApiKey: env.AI_API_KEY || '',
    aiModel: env.AI_MODEL || 'openai/gpt-oss-20b',
    facts,
  };
}

export async function buildServer(cfg, { fetchFn = fetch } = {}) {
  if (cfg.adminToken.length < 24 || cfg.waAppSecret.length < 16 || cfg.waVerifyToken.length < 16 ||
      cfg.adminToken.startsWith('GANTI_') || cfg.waVerifyToken.startsWith('GANTI_') ||
      cfg.waAppSecret.startsWith('APP_SECRET_DARI_')) {
    throw Error('ADMIN_TOKEN minimal 24 karakter; WA_APP_SECRET dan WA_VERIFY_TOKEN minimal 16');
  }
  if (!/^v\d+\.0$/.test(cfg.waVersion)) throw Error('WA_GRAPH_VERSION tidak valid');
  const state = await JsonState.open(cfg.filename);
  const phoneReady = () => /^\d{5,25}$/.test(cfg.waPhoneId) && Boolean(cfg.waToken) && !cfg.waToken.startsWith('TOKEN_META_');
  const aiReady = () => Boolean(cfg.aiApiKey && cfg.aiModel) && !cfg.aiApiKey.startsWith('KUNCI_DARI_');
  const ready = () => phoneReady() && aiReady();
  async function sendText(to, body, replyId) {
    const endpoint = `https://graph.facebook.com/${cfg.waVersion}/${encodeURIComponent(cfg.waPhoneId)}/messages`;
    const response = await fetchFn(endpoint, {
      method: 'POST', headers: { Authorization: `Bearer ${cfg.waToken}`,
        'Content-Type': 'application/json' },
      body: JSON.stringify({ messaging_product: 'whatsapp', to,
        type: 'text', text: { preview_url: false, body },
        ...(replyId ? { context: { message_id: replyId } } : {}) }),
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw Error(`WhatsApp send failed ${response.status}`);
  }
  const agent = new Agent({ state, secret: cfg.waAppSecret, ready,
    phoneReady, facts: cfg.facts, sendText,
    respond: (history, facts) => askAi({ provider: cfg.aiProvider,
      apiKey: cfg.aiApiKey, model: cfg.aiModel, history, shopFacts: facts, fetchFn }),
  });

  const server = http.createServer(async (req, res) => {
    let path, params;
    try {
      const url = new URL(req.url, 'http://localhost');
      path = url.pathname;
      params = url.searchParams;
    } catch { reply(res, 400, { error: 'Bad URL' }); return; }
    if (req.method === 'GET' && path === '/health') {
      reply(res, 200, { ok: true, service: 'AGANA WhatsApp Agent' }); return;
    }
    if (req.method === 'GET' && path === '/webhook') {
      const accepted = params.get('hub.mode') === 'subscribe' &&
        constantEquals(params.get('hub.verify_token'), cfg.waVerifyToken);
      if (!accepted) { reply(res, 403, { error: 'Verification failed' }); return; }
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(params.get('hub.challenge') || '');
      return;
    }
    if (req.method === 'POST' && path === '/webhook') {
      try {
        const raw = await readBody(req);
        const signature = `sha256=${createHmac('sha256', cfg.waAppSecret).update(raw).digest('hex')}`;
        if (!constantEquals(signature, req.headers['x-hub-signature-256'] || '')) {
          reply(res, 403, { error: 'Invalid signature' }); return;
        }
        const payload = JSON.parse(raw.toString('utf8'));
        for (const message of extractMessages(payload, cfg.waPhoneId)) {
          await agent.accept(message); // durable queue before acknowledging webhook
        }
        reply(res, 200, { received: true });
      } catch (error) {
        // Do not log webhook payloads or full customer messages.
        reply(res, 500, { error: 'Webhook could not be processed' });
      }
      return;
    }
    if (!path.startsWith('/admin/')) {
      reply(res, 404, { error: 'Not found' }); return;
    }
    const supplied = (req.headers.authorization || '').replace(/^Bearer /, '');
    if (!constantEquals(supplied, cfg.adminToken)) {
      reply(res, 401, { error: 'Unauthorized' }); return;
    }
    try {
      if (req.method === 'GET' && path === '/admin/status') {
        reply(res, 200, { ...agent.status(),
          ai_ready: aiReady(), phone_ready: phoneReady() });
        return;
      }
      if (req.method === 'POST' && path === '/admin/agent') {
        const body = JSON.parse((await readBody(req, 8192)).toString('utf8'));
        if (typeof body.enabled !== 'boolean') { reply(res, 400, { error: 'enabled must be bool' }); return; }
        reply(res, 200, { ...(await agent.enabled(body.enabled)),
          ai_ready: aiReady(), phone_ready: phoneReady() });
        return;
      }
      const match = /^\/admin\/threads\/([a-f0-9]{16})\/handoff$/.exec(path);
      if (req.method === 'POST' && match) {
        const body = JSON.parse((await readBody(req, 8192)).toString('utf8'));
        if (typeof body.paused !== 'boolean') { reply(res, 400, { error: 'paused must be bool' }); return; }
        reply(res, 200, await agent.handoff(match[1], body.paused));
        return;
      }
      reply(res, 404, { error: 'Not found' });
    } catch (_) {
      reply(res, 400, { error: 'Invalid admin request' });
    }
  });
  return { server, agent, state };
}

if (process.argv[1] && import.meta.url === new URL(`file://${resolve(process.argv[1])}`).href) {
  const config = fromEnv();
  const { server, agent } = await buildServer(config);
  await agent.recover();
  server.listen(config.port, config.host, () => {
    console.log(`AGANA WhatsApp webhook listening on port ${config.port}. Agent starts paused.`);
  });
}
