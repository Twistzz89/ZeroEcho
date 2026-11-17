import { GameState, StoryDefinition, GameAction, createInitialState, cloneState } from '../models/Models';
import { GameEngine } from '../domain/GameEngine';
import { validateStory } from '../data/StoryRepository';
import { SaveRepository, Profile, SlotInfo } from '../data/SaveRepository';

export class GameViewModel {
  state: GameState;
  story: StoryDefinition;
  profile: Profile = new Profile();
  ready: boolean = false;
  busy: boolean = false;
  error: string = '';
  message: string = '';
  hasGame: boolean = false;
  slots: SlotInfo[] = [];
  private repository: SaveRepository;
  private engine: GameEngine;
  constructor(story: StoryDefinition, repository: SaveRepository) {
    this.story = story;
    this.repository = repository;
    this.state = createInitialState(story);
    this.engine = new GameEngine(story);
  }
  private begin(): boolean {
    if (this.busy) { return false; }
    if (!this.ready) { this.error = '数据尚未就绪，请先重新载入或处理存档错误'; return false; }
    this.busy = true;
    this.error = '';
    this.message = '';
    return true;
  }
  private async refresh(): Promise<void> { this.slots = await this.repository.listSlots(); }
  private async reconcileEndings(): Promise<boolean> {
    const next = new Profile();
    next.largeText = this.profile.largeText;
    next.unlockedEndingIds = this.profile.unlockedEndingIds.slice();
    for (const id of ['auto', '1', '2', '3']) {
      const load = await this.repository.load(id);
      if (load.status === 'valid' && load.state.endingId !== '' && !next.unlockedEndingIds.includes(load.state.endingId)) {
        next.unlockedEndingIds.push(load.state.endingId);
      }
    }
    if (next.unlockedEndingIds.length === this.profile.unlockedEndingIds.length) { return true; }
    const saved = await this.repository.saveProfile(next);
    if (!saved.ok) { this.error = '结局已保存，但图鉴未同步。请重新载入重试'; this.ready = false; return false; }
    this.profile = next;
    return true;
  }
  async initialize(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    this.ready = false;
    this.error = '';
    this.message = '';
    try {
      const valid = validateStory(this.story);
      if (!valid.ok) { this.error = valid.error; return; }
      const profile = await this.repository.loadProfile();
      if (!profile.ok) { this.error = profile.error; await this.refresh(); return; }
      this.profile = profile.profile;
      this.message = profile.error;
      if (profile.error !== '') {
        const repaired = await this.repository.saveProfile(this.profile, true);
        if (!repaired.ok) { this.error = '图鉴副本有效，但主文件恢复失败，请重试'; return; }
      }
      const load = await this.repository.load('auto');
      this.hasGame = load.status === 'valid';
      this.state = this.hasGame ? load.state : createInitialState(this.story);
      if (load.status !== 'valid' && load.status !== 'empty') {
        this.error = load.error + (load.recoverable ? '。可在存档页恢复最近有效副本' : '。可读取其他手动档或确认新游戏');
      }
      await this.refresh();
      this.ready = true;
      await this.reconcileEndings();
    } catch (_) { this.error = '初始化失败，请重试'; }
    finally { this.busy = false; }
  }
  async newGame(): Promise<void> {
    if (!this.begin()) { return; }
    try {
      const next = createInitialState(this.story);
      const save = await this.repository.save('auto', next, true);
      if (!save.ok) { this.error = save.error; return; }
      this.state = next;
      this.hasGame = true;
      this.message = '新的调查已保存，结局图鉴保持不变';
      await this.refresh();
    } finally { this.busy = false; }
  }
  async act(action: GameAction): Promise<void> {
    if (!this.begin()) { return; }
    try {
      if (!this.hasGame) { this.error = '请先开始或载入游戏'; return; }
      const result = this.engine.dispatch(this.state, action);
      if (!result.ok) { this.error = result.message; return; }
      const saved = await this.repository.save('auto', result.state);
      if (!saved.ok) { this.error = saved.error + '；本次动作未提交，可重试'; return; }
      this.state = cloneState(result.state);
      this.message = result.message + ' · 已自动保存';
      await this.refresh();
      await this.reconcileEndings();
    } finally { this.busy = false; }
  }
  async saveManual(slotId: string, overwrite: boolean): Promise<void> {
    if (!this.begin()) { return; }
    try {
      if (!['1', '2', '3'].includes(slotId) || !this.hasGame) { this.error = '请先开始游戏并选择手动槽位'; return; }
      const existing = await this.repository.load(slotId);
      if (existing.status !== 'empty' && !overwrite) { this.error = '该槽位已有数据，需要确认覆盖'; return; }
      const result = await this.repository.save(slotId, this.state, overwrite);
      if (!result.ok) { this.error = result.error; return; }
      this.message = '手动存档 ' + slotId + ' 已保存';
      await this.refresh();
    } finally { this.busy = false; }
  }
  async loadSlot(slotId: string, recover: boolean = false): Promise<void> {
    if (!this.begin()) { return; }
    try {
      const load = await this.repository.load(slotId, recover);
      if (load.status !== 'valid') { this.error = load.error || '该槽位尚无存档'; return; }
      // A manually loaded game becomes the automatic continuation only after a successful write.
      if (slotId !== 'auto' || recover) {
        const saved = await this.repository.save('auto', load.state, true);
        if (!saved.ok) { this.error = saved.error; return; }
      }
      this.state = load.state;
      this.hasGame = true;
      this.message = recover ? '已恢复有效副本并保存为自动档' : '存档已载入，未重复执行奖励';
      await this.refresh();
      await this.reconcileEndings();
    } finally { this.busy = false; }
  }
  async deleteSlot(slotId: string): Promise<void> {
    if (!this.begin()) { return; }
    try {
      const result = await this.repository.deleteSlot(slotId);
      if (!result.ok) { this.error = result.error; return; }
      if (slotId === 'auto') { this.hasGame = false; this.state = createInitialState(this.story); }
      this.message = '指定存档已删除，其他槽位和结局图鉴保持不变';
      await this.refresh();
    } finally { this.busy = false; }
  }
  async setLargeText(value: boolean): Promise<void> {
    if (!this.begin()) { return; }
    try {
      const next = new Profile();
      next.largeText = value;
      next.unlockedEndingIds = this.profile.unlockedEndingIds.slice();
      const result = await this.repository.saveProfile(next);
      if (!result.ok) { this.error = result.error; return; }
      this.profile = next;
      this.message = '阅读设置已保存';
    } finally { this.busy = false; }
  }
  async resetAll(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    this.error = '';
    try {
      this.hasGame = false;
      for (const id of ['auto', '1', '2', '3']) {
        const result = await this.repository.deleteSlot(id);
        if (!result.ok) { this.error = '部分数据未清除，请重试清空。' + result.error; this.ready = false; await this.refresh(); return; }
      }
      const next = new Profile();
      const saved = await this.repository.resetProfile();
      if (!saved.ok) { this.error = '存档已清空，图鉴清除失败，请重试'; this.ready = false; return; }
      this.profile = next;
      this.state = createInitialState(this.story);
      this.ready = true;
      this.message = '所有进度、图鉴及设置已清空';
      await this.refresh();
    } finally { this.busy = false; }
  }
}
