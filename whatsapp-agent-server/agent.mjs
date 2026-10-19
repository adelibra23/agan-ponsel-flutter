import { createHmac } from 'node:crypto';

const ONE_DAY = 86400000;
const HANDOFF = /\b(admin|operator|manusia|cs|customer service|bicara (sama|dengan) orang|hubung(i|kan) admin)\b/i;
const STOP = /\b(stop|berhenti|jangan balas|matikan bot|hapus chat bot|nonaktifkan ai)\b/i;
const RESUME = /^(mulai|start|aktifkan ai|lanjutkan ai)$/i;

export function threadId(from, secret) {
  return createHmac('sha256', secret).update(from).digest('hex').slice(0, 16);
}
export function maskPhone(from) { return String(from).slice(-4); }
export function classify(text) {
  if (STOP.test(text)) return 'stop';
  if (HANDOFF.test(text)) return 'handoff';
  return 'ai';
}
export function aiHistory(list) {
  return list.slice(-12).map(x => ({ role: x.role, content: x.text.slice(0, 1200) }));
}
export function extractMessages(data, expectedPhoneId) {
  if (data?.object !== 'whatsapp_business_account') return [];
  const output = [];
  for (const entry of data.entry ?? []) {
    for (const change of entry.changes ?? []) {
      if (change.field !== 'messages') continue;
      const value = change.value ?? {};
      if (String(value.metadata?.phone_number_id ?? '') !== String(expectedPhoneId)) continue;
      for (const message of value.messages ?? []) {
        if (typeof message.id !== 'string' || !/^\d{8,18}$/.test(message.from ?? '')) continue;
        output.push({ id: message.id, from: message.from,
          text: message.type === 'text' ? String(message.text?.body ?? '').slice(0, 1200) : '',
          type: message.type, timestamp: Number(message.timestamp || 0) * 1000 });
      }
    }
  }
  return output;
}

export class Agent {
  constructor({ state, secret, ready, phoneReady, sendText, respond, facts = {} }) {
    this.state = state;
    this.secret = secret;
    this.ready = ready;
    this.phoneReady = phoneReady;
    this.sendText = sendText;
    this.respond = respond;
    this.facts = facts;
    this.tasks = new Map();
  }
  threadFor(from) {
    let thread = this.state.value.threads[from];
    if (!thread) {
      thread = { history: [], paused: false, updated: Date.now(), lastMessageAt: 0, burst: [] };
      this.state.value.threads[from] = thread;
    }
    return thread;
  }
  async accept(message) {
    const jobs = this.state.value.jobs;
    if (jobs[message.id]) return false;
    if (!message.timestamp || message.timestamp > Date.now() + 5 * 60 * 1000 ||
        Date.now() - message.timestamp > ONE_DAY) return false;
    jobs[message.id] = { ...message, when: Date.now(), status: 'pending' };
    this.state.prune();
    await this.state.persist();
    this.queue(message.from, message.id);
    return true;
  }
  queue(from, id) {
    const prev = this.tasks.get(from) || Promise.resolve();
    const next = prev.catch(() => {}).then(() => this.process(id));
    this.tasks.set(from, next);
    next.finally(() => { if (this.tasks.get(from) === next) this.tasks.delete(from); })
      .catch(() => {});
  }
  async recover() {
    for (const job of Object.values(this.state.value.jobs)) {
      if (job.status === 'pending' || job.status === 'processing') {
        job.status = 'pending';
        this.queue(job.from, job.id);
      }
    }
  }
  async process(id) {
    const job = this.state.value.jobs[id];
    if (!job || job.status === 'done') return;
    job.status = 'processing';
    await this.state.persist();
    try {
      await this._handle(job);
      job.status = 'done';
    } catch (error) {
      job.status = 'failed';
      this.state.value.metrics.failed++;
      // Avoid emitting phone, prompt, access token or provider response logs.
      console.error('WhatsApp message processing failed (details suppressed)');
    }
    await this.state.persist();
  }
  async _handle(message) {
    const thread = this.threadFor(message.from);
    const first = thread.history.length === 0 || message.timestamp - thread.lastMessageAt > ONE_DAY;
    if (first) thread.history = [];
    thread.lastMessageAt = message.timestamp;
    thread.updated = Date.now();
    thread.burst = thread.burst.filter(t => Date.now() - t < 60000);
    thread.burst.push(Date.now());
    if (thread.burst.length > 12) return;
    if (!this.state.value.enabled || !this.ready()) return;
    const text = message.text.trim();
    let resumed = false;
    const hashedPhone = threadId(message.from, this.secret);
    if (this.state.value.optOutIds?.[hashedPhone]) {
      // STOP persists as an HMAC pseudonym after chat content is purged.
      // Only an explicit START from this phone can resume the bot.
      if (!RESUME.test(text)) return;
      delete this.state.value.optOutIds[hashedPhone];
      thread.paused = false;
      resumed = true;
    }
    if (thread.paused) return;
    const action = classify(text);
    const prefix = first
      ? 'Halo! Saya AGANA, asisten AI otomatis AGAN PONSEL. Percakapan dapat diproses penyedia AI; jangan kirim PIN, OTP, atau data sensitif.\n\n'
      : '';
    let answer;
    if (resumed) {
      answer = 'Balasan AGANA aktif kembali. Silakan tulis pertanyaanmu.';
    } else if (action === 'stop') {
      thread.paused = true;
      this.state.value.optOutIds[hashedPhone] = Date.now();
      answer = 'Baik, balasan otomatis dinonaktifkan. Jika ingin mengaktifkan kembali, balas MULAI.';
    } else if (action === 'handoff') {
      thread.paused = true;
      answer = 'Baik, saya alihkan percakapan ke admin AGAN PONSEL. Mohon tunggu balasan admin.';
    } else if (!text) {
      answer = 'Saat ini saya bisa membaca pesan teks. Untuk foto, video, atau voice note, mohon tuliskan pertanyaannya atau minta bantuan admin.';
    } else {
      thread.history.push({ role: 'user', text, at: Date.now() });
      try {
        answer = await this.respond(aiHistory(thread.history), this.facts);
      } catch (_) {
        thread.paused = true;
        answer = 'Maaf, sambungan AI sedang bermasalah. Saya hentikan balasan otomatis agar admin dapat membantu. Mohon tunggu.';
      }
    }
    if (!answer) return;
    // Send only in the customer service window following an inbound message.
    if (Date.now() - message.timestamp >= ONE_DAY || !this.state.value.enabled) return;
    const outgoing = (prefix + answer).slice(0, 2500);
    await this.sendText(message.from, outgoing, message.id);
    this.state.value.metrics.sent++;
    thread.history.push({ role: 'assistant', text: answer, at: Date.now() });
    thread.history = thread.history.slice(-12);
    thread.updated = Date.now();
  }
  status() {
    return {
      enabled: this.state.value.enabled,
      ai_ready: this.ready(),
      phone_ready: this.phoneReady(),
      metrics: this.state.value.metrics,
      threads: Object.entries(this.state.value.threads)
        .sort((a, b) => b[1].updated - a[1].updated).slice(0, 20)
        .map(([phone, v]) => ({ id: threadId(phone, this.secret), last4: maskPhone(phone),
          paused: v.paused, updated: new Date(v.updated).toISOString() })),
    };
  }
  async enabled(value) {
    if (value && !this.ready()) throw Error('Konfigurasi WhatsApp atau AI belum lengkap');
    this.state.value.enabled = value;
    await this.state.persist();
    return this.status();
  }
  async handoff(id, paused) {
    const phone = Object.keys(this.state.value.threads)
      .find(p => threadId(p, this.secret) === id);
    if (!phone) throw Error('Percakapan tidak ditemukan');
    this.state.value.threads[phone].paused = paused;
    await this.state.persist();
    return this.status();
  }
}
