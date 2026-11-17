import { GameState, StoryDefinition, createInitialState, cloneState } from '../models/Models';
import { validateState } from '../domain/StateValidator';

export interface TextStore {
  read(key: string): Promise<string>;
  writeAtomic(key: string, value: string): Promise<void>;
}

export interface Clock { now(): string; }
export class SystemClock implements Clock {
  now(): string { return new Date().toISOString(); }
}
export class Profile {
  schemaVersion: number = 1;
  unlockedEndingIds: string[] = [];
  largeText: boolean = false;
}
export interface SaveEnvelope {
  schemaVersion: number;
  contentVersion: number;
  slotId: string;
  savedAt: string;
  deleted: boolean;
  state: GameState;
}
export interface SlotInfo {
  id: string;
  status: string;
  savedAt: string;
  nodeId: string;
  revision: number;
  recoverable: boolean;
}
export interface LoadResult {
  status: string;
  state: GameState;
  savedAt: string;
  error: string;
  recoverable: boolean;
}
export interface WriteResult { ok: boolean; error: string; }
export interface ProfileResult { ok: boolean; profile: Profile; error: string; }

export class SaveRepository {
  private queue: Promise<void> = Promise.resolve();
  private store: TextStore;
  private story: StoryDefinition;
  private clock: Clock;
  constructor(store: TextStore, story: StoryDefinition, clock: Clock = new SystemClock()) {
    this.store = store;
    this.story = story;
    this.clock = clock;
  }
  private validSlot(slot: string): boolean { return ['auto', '1', '2', '3'].includes(slot); }
  private key(slot: string): string { return 'save-' + slot + '.json'; }
  private empty(status: string, error: string = ''): LoadResult {
    return { status: status, state: createInitialState(this.story), savedAt: '', error: error, recoverable: false };
  }
  private decode(raw: string, slot: string): LoadResult {
    if (raw === '') { return this.empty('empty'); }
    if (raw.length > 524288) { return this.empty('corrupt', '存档超过安全大小限制'); }
    try {
      const record = JSON.parse(raw) as SaveEnvelope;
      if (!record || typeof record !== 'object' || typeof record.schemaVersion !== 'number' ||
        typeof record.contentVersion !== 'number') { return this.empty('corrupt', '存档字段缺失'); }
      if (record.schemaVersion !== 1 || record.contentVersion !== this.story.contentVersion) {
        return this.empty('incompatible', '存档版本与当前剧情不兼容，原文件已保留');
      }
      if (record.slotId !== slot || typeof record.savedAt !== 'string' ||
        !Number.isFinite(Date.parse(record.savedAt)) || typeof record.deleted !== 'boolean') {
        return this.empty('corrupt', '存档元数据无效');
      }
      if (record.deleted) { return this.empty('empty'); }
      const error = validateState(record.state, this.story);
      if (error !== '') { return this.empty('corrupt', error); }
      return { status: 'valid', state: cloneState(record.state), savedAt: record.savedAt, error: '', recoverable: false };
    } catch (_) { return this.empty('corrupt', '无法解析存档JSON'); }
  }
  async load(slot: string, recover: boolean = false): Promise<LoadResult> {
    await this.queue;
    if (!this.validSlot(slot)) { return this.empty('error', '无效的存档槽位'); }
    try {
      const raw = await this.store.read(this.key(slot));
      const main = this.decode(raw, slot);
      // A tombstone is an intentional deletion. Never resurrect its backup.
      if ((main.status === 'empty' && raw !== '') || main.status === 'valid') { return main; }
      const backup = this.decode(await this.store.read(this.key(slot) + '.bak'), slot);
      main.recoverable = backup.status === 'valid';
      if (recover && main.recoverable) { return backup; }
      if (raw === '' && main.recoverable) {
        main.status = 'corrupt';
        main.error = '主存档为空或丢失，可恢复最近有效副本';
      }
      return main;
    } catch (_) { return this.empty('error', '存档读取失败，请重试'); }
  }
  private async serial(action: () => Promise<void>): Promise<WriteResult> {
    let result: WriteResult = { ok: true, error: '' };
    const task: Promise<void> = this.queue.then(async (): Promise<void> => {
      try { await action(); } catch (_) { result = { ok: false, error: '写入失败，上一份有效数据仍保留，请重试' }; }
    });
    this.queue = task;
    await task;
    return result;
  }
  async save(slot: string, state: GameState): Promise<WriteResult> {
    if (!this.validSlot(slot)) { return { ok: false, error: '无效的存档槽位' }; }
    const invalid = validateState(state, this.story);
    if (invalid !== '') { return { ok: false, error: invalid }; }
    const record: SaveEnvelope = {
      schemaVersion: 1, contentVersion: this.story.contentVersion, slotId: slot,
      savedAt: this.clock.now(), deleted: false, state: cloneState(state)
    };
    const raw = JSON.stringify(record);
    if (raw.length > 524288) { return { ok: false, error: '存档超过安全大小限制' }; }
    return this.serial(async (): Promise<void> => {
      const old = await this.store.read(this.key(slot));
      if (this.decode(old, slot).status === 'valid') {
        await this.store.writeAtomic(this.key(slot) + '.bak', old);
      }
      await this.store.writeAtomic(this.key(slot), raw);
    });
  }
  async deleteSlot(slot: string): Promise<WriteResult> {
    if (!this.validSlot(slot)) { return { ok: false, error: '无效的存档槽位' }; }
    const record: SaveEnvelope = {
      schemaVersion: 1, contentVersion: this.story.contentVersion, slotId: slot,
      savedAt: this.clock.now(), deleted: true, state: createInitialState(this.story)
    };
    return this.serial(async (): Promise<void> => {
      await this.store.writeAtomic(this.key(slot) + '.bak', JSON.stringify(record));
      await this.store.writeAtomic(this.key(slot), JSON.stringify(record));
    });
  }
  async listSlots(): Promise<SlotInfo[]> {
    const list: SlotInfo[] = [];
    for (const id of ['auto', '1', '2', '3']) {
      const result = await this.load(id);
      list.push({ id: id, status: result.status, savedAt: result.savedAt,
        nodeId: result.status === 'valid' ? result.state.currentNodeId : '',
        revision: result.status === 'valid' ? result.state.revision : 0, recoverable: result.recoverable });
    }
    return list;
  }
  private decodeProfile(raw: string): Profile | undefined {
    try {
      const p = JSON.parse(raw) as Profile;
      if (!p || p.schemaVersion !== 1 || !Array.isArray(p.unlockedEndingIds) || typeof p.largeText !== 'boolean') { return undefined; }
      const clean = new Profile();
      clean.largeText = p.largeText;
      for (const id of p.unlockedEndingIds) {
        if (typeof id !== 'string' || !['E01', 'E02', 'E03', 'E04'].includes(id) || clean.unlockedEndingIds.includes(id)) { return undefined; }
        clean.unlockedEndingIds.push(id);
      }
      return clean;
    } catch (_) { return undefined; }
  }
  async loadProfile(): Promise<ProfileResult> {
    await this.queue;
    try {
      const raw = await this.store.read('profile.json');
      const profile = this.decodeProfile(raw);
      if (profile) { return { ok: true, profile: profile, error: '' }; }
      const backup = this.decodeProfile(await this.store.read('profile.json.bak'));
      if (backup) { return { ok: true, profile: backup, error: '图鉴主文件损坏，已读取最近有效副本' }; }
      if (raw === '') { return { ok: true, profile: new Profile(), error: '' }; }
      return { ok: false, profile: new Profile(), error: '图鉴损坏，未覆盖原文件；可重试或在设置中确认重置' };
    } catch (_) { return { ok: false, profile: new Profile(), error: '图鉴读取失败，请重试' }; }
  }
  async saveProfile(profile: Profile): Promise<WriteResult> {
    const raw = JSON.stringify(profile);
    if (!this.decodeProfile(raw)) { return { ok: false, error: '图鉴数据无效' }; }
    return this.serial(async (): Promise<void> => {
      const old = await this.store.read('profile.json');
      if (this.decodeProfile(old)) { await this.store.writeAtomic('profile.json.bak', old); }
      await this.store.writeAtomic('profile.json', raw);
    });
  }
  async resetProfile(): Promise<WriteResult> {
    const raw = JSON.stringify(new Profile());
    return this.serial(async (): Promise<void> => {
      await this.store.writeAtomic('profile.json.bak', raw);
      await this.store.writeAtomic('profile.json', raw);
    });
  }
}
