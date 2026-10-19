import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { randomBytes } from 'node:crypto';

export class JsonState {
  constructor(filename, value) {
    this.filename = filename;
    this.value = value;
    this.writing = Promise.resolve();
  }
  static async open(filename) {
    let value = { enabled: false, threads: {}, jobs: {}, optOutIds: {}, metrics: { sent: 0, failed: 0 } };
    try {
      const data = JSON.parse(await readFile(filename, 'utf8'));
      if (data && data.threads && data.jobs && data.metrics) value = data;
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    value.optOutIds ??= {};
    return new JsonState(filename, value);
  }
  async persist() {
    const snapshot = JSON.stringify(this.value);
    this.writing = this.writing.then(async () => {
      await mkdir(dirname(this.filename), { recursive: true });
      const temp = `${this.filename}.${randomBytes(5).toString('hex')}.tmp`;
      await writeFile(temp, snapshot, { encoding: 'utf8', mode: 0o600 });
      await rename(temp, this.filename);
    });
    return this.writing;
  }
  prune(now = Date.now()) {
    const cutoff = now - 7 * 24 * 60 * 60 * 1000;
    for (const [id, job] of Object.entries(this.value.jobs)) {
      if (job.when < cutoff) delete this.value.jobs[id];
    }
    for (const [phone, thread] of Object.entries(this.value.threads)) {
      if (thread.updated < cutoff) delete this.value.threads[phone];
    }
  }
}
