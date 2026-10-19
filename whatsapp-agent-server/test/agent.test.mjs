import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHmac } from 'node:crypto';
import { JsonState } from '../state.mjs';
import { Agent, aiHistory, classify, extractMessages } from '../agent.mjs';
import { buildServer } from '../server.mjs';

const now = () => Date.now();
const message = (id, text, from = '6281234567890') => ({
  id, text, from, type: 'text', timestamp: now(),
});

test('intent routing recognizes human takeover and STOP, not ordinary chat', () => {
  assert.equal(classify('Saya mau bicara sama admin'), 'handoff');
  assert.equal(classify('Tolong jangan balas lagi'), 'stop');
  assert.equal(classify('Apakah charger Samsung tersedia?'), 'ai');
  assert.deepEqual(aiHistory(Array.from({ length: 15 }, (_, i) => ({ role: 'user', text: `${i}`, at: 0 }))).length, 12);
});

test('WhatsApp webhook accepts only matching business phone and text payload', () => {
  const sample = { object: 'whatsapp_business_account', entry: [{ changes: [
    { field: 'messages', value: { metadata: { phone_number_id: '123' }, messages: [
      { id: 'wamid.test.1', from: '6281234567890', timestamp: Math.floor(now() / 1000), type: 'text', text: { body: 'Halo' } },
    ] } },
  ] }] };
  assert.equal(extractMessages(sample, '123')[0].text, 'Halo');
  assert.equal(extractMessages(sample, '999').length, 0);
});

test('Agent preserves context across incoming turns, deduplicates and pauses for admin', async () => {
  const folder = await mkdtemp(join(tmpdir(), 'agana-core-'));
  try {
    const state = await JsonState.open(join(folder, 'state.json'));
    state.value.enabled = true;
    const outgoing = [], contexts = [];
    const agent = new Agent({ state, secret: 'some-admin-token-long-enough', ready: () => true,
      phoneReady: () => true, facts: {},
      sendText: async (phone, text) => outgoing.push({ phone, text }),
      respond: async history => { contexts.push(history); return 'Baik, saya bantu.'; },
    });
    assert.equal(await agent.accept(message('a', 'Halo AGANA')), true);
    await agent.tasks.get('6281234567890');
    assert.equal(await agent.accept(message('a', 'Halo AGANA')), false);
    assert.equal(await agent.accept(message('b', 'Kalau untuk charger?')), true);
    await agent.tasks.get('6281234567890');
    assert.equal(outgoing.length, 2);
    assert.match(outgoing[0].text, /asisten AI otomatis/);
    assert.equal(contexts.length, 2);
    assert.equal(contexts[1].length, 3);
    assert.equal(contexts[1][0].content, 'Halo AGANA');
    assert.equal(await agent.accept(message('c', 'Boleh bicara sama admin?')), true);
    await agent.tasks.get('6281234567890');
    assert.match(outgoing[2].text, /alihkan percakapan/);
    assert.equal(await agent.accept(message('d', 'Halo lagi')), true);
    await agent.tasks.get('6281234567890');
    assert.equal(outgoing.length, 3);
    assert.equal(state.value.threads['6281234567890'].paused, true);
    const restored = await JsonState.open(join(folder, 'state.json'));
    assert.equal(restored.value.threads['6281234567890'].paused, true);
    assert.equal(restored.value.jobs.a.status, 'done');
  } finally { await rm(folder, { recursive: true, force: true }); }
});

test('admin API authenticates, rejects unsigned webhook, enables agent and replies', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'agana-http-'));
  const sent = [];
  const config = {
    filename: join(dir, 'state.json'), adminToken: 'admin-secret-token-123456789999',
    waAppSecret: 'app-secret-1234567890', waVerifyToken: 'verification-secret-123',
    waPhoneId: '44555', waToken: 'business-token', waVersion: 'v24.0',
    aiProvider: 'groq', aiApiKey: 'ai-key-test', aiModel: 'mock-llm', facts: {},
  };
  const fetchFn = async (url, opts) => {
    if (String(url).includes('graph.facebook.com')) {
      sent.push(JSON.parse(opts.body));
      return new Response(JSON.stringify({ messages: [{ id: 'wamid.answer' }] }), { status: 200 });
    }
    return new Response(JSON.stringify({ choices: [{ message: { content: 'Kami melayani service HP. Untuk harga, silakan konfirmasi ke admin.' } }] }), { status: 200 });
  };
  const { server, agent, state } = await buildServer(config, { fetchFn });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    const noAuth = await fetch(base + '/admin/status');
    assert.equal(noAuth.status, 401);
    const auth = { Authorization: `Bearer ${config.adminToken}`, 'Content-Type': 'application/json' };
    const initial = await (await fetch(base + '/admin/status', { headers: auth })).json();
    assert.equal(initial.enabled, false);
    const enable = await fetch(base + '/admin/agent', { method: 'POST', headers: auth, body: JSON.stringify({ enabled: true }) });
    assert.equal(enable.status, 200);
    const challenge = await fetch(base + `/webhook?hub.mode=subscribe&hub.verify_token=${config.waVerifyToken}&hub.challenge=ok123`);
    assert.equal(await challenge.text(), 'ok123');
    const webhook = { object: 'whatsapp_business_account', entry: [{ changes: [{
      field: 'messages', value: { metadata: { phone_number_id: '44555' }, messages: [
        { id: 'wamid.123', from: '6281234567890', type: 'text', timestamp: `${Math.floor(now() / 1000)}`, text: { body: 'Apa bisa service HP?' } },
      ] },
    }] }] };
    const raw = JSON.stringify(webhook);
    const invalid = await fetch(base + '/webhook', { method: 'POST', headers: { 'x-hub-signature-256': 'invalid' }, body: raw });
    assert.equal(invalid.status, 403);
    const signature = 'sha256=' + createHmac('sha256', config.waAppSecret).update(raw).digest('hex');
    const ok = await fetch(base + '/webhook', { method: 'POST', headers: { 'x-hub-signature-256': signature }, body: raw });
    assert.equal(ok.status, 200);
    await agent.tasks.get('6281234567890');
    assert.equal(sent.length, 1);
    assert.match(sent[0].text.body, /Kami melayani service HP/);
    const again = await fetch(base + '/webhook', { method: 'POST', headers: { 'x-hub-signature-256': signature }, body: raw });
    assert.equal(again.status, 200);
    assert.equal(sent.length, 1);
    const adminStatus = await (await fetch(base + '/admin/status', { headers: auth })).json();
    assert.equal(adminStatus.threads[0].last4, '7890');
    const handoff = await fetch(`${base}/admin/threads/${adminStatus.threads[0].id}/handoff`, {
      method: 'POST', headers: auth, body: JSON.stringify({ paused: true }),
    });
    assert.equal(handoff.status, 200);
    assert.equal(state.value.threads['6281234567890'].paused, true);
  } finally {
    await new Promise(resolve => server.close(resolve));
    await rm(dir, { recursive: true, force: true });
  }
});


test('STOP opt-out survives history retention and requires explicit START to resume', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'agana-stop-'));
  try {
    const state = await JsonState.open(join(dir, 'state.json'));
    state.value.enabled = true;
    const replies = [];
    const agent = new Agent({ state, secret: 'some-admin-token-long-enough', ready: () => true,
      phoneReady: () => true, facts: {}, sendText: async (_, text) => replies.push(text),
      respond: async () => 'Saya bantu.' });
    await agent.accept(message('stop.1', 'STOP'));
    await agent.tasks.get('6281234567890');
    assert.equal(Object.keys(state.value.optOutIds).length, 1);
    state.value.threads['6281234567890'].updated = Date.now() - 8 * 86400000;
    state.prune();
    await state.persist();
    const reopened = await JsonState.open(join(dir, 'state.json'));
    assert.equal(Object.keys(reopened.value.threads).length, 0);
    assert.equal(Object.keys(reopened.value.optOutIds).length, 1);
    const secondAgent = new Agent({ state: reopened, secret: 'some-admin-token-long-enough',
      ready: () => true, phoneReady: () => true, facts: {},
      sendText: async (_, text) => replies.push(text), respond: async () => 'Saya bantu.' });
    await secondAgent.accept(message('stop.2', 'Mau tanya servis'));
    await secondAgent.tasks.get('6281234567890');
    assert.equal(replies.length, 1);
    await secondAgent.accept(message('stop.3', 'MULAI'));
    await secondAgent.tasks.get('6281234567890');
    assert.equal(Object.keys(reopened.value.optOutIds).length, 0);
    assert.equal(replies.length, 2);
  } finally { await rm(dir, { recursive: true, force: true }); }
});
