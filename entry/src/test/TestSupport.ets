import { GameAction, GameState, StoryDefinition, TransitionResult, createInitialState } from '../main/ets/models/Models';
import { GameEngine } from '../main/ets/domain/GameEngine';
import { createStory } from '../main/ets/data/StoryRepository';
import { Clock, SaveEnvelope, SaveRepository, TextStore } from '../main/ets/data/SaveRepository';
import { GameViewModel } from '../main/ets/viewmodels/GameViewModel';

export class FixedClock implements Clock {
  now(): string { return '2026-11-16T12:00:00.000Z'; }
}

// Only the I/O boundary is replaced. Production parsing, queueing, engine and ViewModel remain real.
export class FakeTextStore implements TextStore {
  files: Map<string, string> = new Map<string, string>();
  writes: string[] = [];
  startedWrites: string[] = [];
  failKey: string = '';
  failuresLeft: number = 0;
  failReads: boolean = false;
  failReadKey: string = '';
  private readGate: Promise<void> = Promise.resolve();
  private writeGate: Promise<void> = Promise.resolve();
  private releaseRead: () => void = (): void => {};
  private releaseWrite: () => void = (): void => {};

  holdReads(): void {
    this.readGate = new Promise<void>((resolve: () => void): void => { this.releaseRead = resolve; });
  }
  releaseReads(): void { this.releaseRead(); }
  holdWrites(): void {
    this.writeGate = new Promise<void>((resolve: () => void): void => { this.releaseWrite = resolve; });
  }
  releaseWrites(): void { this.releaseWrite(); }
  async read(key: string): Promise<string> {
    await this.readGate;
    if (this.failReads || key === this.failReadKey) { throw new Error('Injected read failure'); }
    const value = this.files.get(key);
    return value === undefined ? '' : value;
  }
  async writeAtomic(key: string, value: string): Promise<void> {
    this.startedWrites.push(key);
    await this.writeGate;
    if (this.failuresLeft > 0 && (this.failKey === '' || key === this.failKey)) {
      this.failuresLeft--;
      throw new Error('Injected atomic write failure');
    }
    this.files.set(key, value);
    this.writes.push(key);
  }
}

export function choiceAction(state: GameState, id: string): GameAction {
  return { kind: 'choice', nodeId: state.currentNodeId, id: id, expectedRevision: state.revision, answer: '', order: '' };
}
export function puzzleAction(state: GameState, id: string, answer: string, order: string = ''): GameAction {
  return { kind: 'puzzle', nodeId: state.currentNodeId, id: id, expectedRevision: state.revision, answer: answer, order: order };
}

export class TestRig {
  story: StoryDefinition = createStory();
  engine: GameEngine = new GameEngine(this.story);
  state: GameState = createInitialState(this.story);
  choose(id: string): void { this.accept(this.engine.dispatch(this.state, choiceAction(this.state, id))); }
  solve(id: string, answer: string, order: string = ''): void {
    this.accept(this.engine.dispatch(this.state, puzzleAction(this.state, id, answer, order)));
  }
  choices(ids: string[]): void { ids.forEach((id: string): void => this.choose(id)); }
  private accept(result: TransitionResult): void {
    if (!result.ok) { throw new Error('Route failed: ' + result.error + ' / ' + result.message); }
    this.state = result.state;
  }
}

export function cabinetRig(firstChoice: string = 'share'): TestRig {
  const rig = new TestRig();
  rig.choices([firstChoice, 'take-note', 'note-to-cabinet']);
  return rig;
}

export function completeEvidenceRig(): TestRig {
  const rig = cabinetRig();
  rig.solve('P01', '0417');
  rig.choices(['cooperate', 'record-witness', 'take-calibration', 'calibration-back',
    'take-gateway', 'gateway-back', 'take-config', 'config-back', 'open-timeline']);
  rig.solve('P02', '00:00', 'task-first');
  return rig;
}

export function partialEvidenceRig(): TestRig {
  const rig = cabinetRig('hold');
  rig.solve('P01', '0417');
  rig.choices(['work-alone', 'alone-to-hub', 'take-gateway', 'gateway-back', 'take-config', 'config-back', 'to-report']);
  return rig;
}

export function insufficientEvidenceRig(): TestRig {
  const rig = new TestRig();
  rig.choices(['share', 'skip-note', 'skip-cabinet', 'work-alone', 'alone-to-hub', 'to-report']);
  return rig;
}

export function rawSave(story: StoryDefinition, state: GameState, slot: string = 'auto'): string {
  const envelope: SaveEnvelope = {
    schemaVersion: 1, contentVersion: story.contentVersion, slotId: slot,
    savedAt: new FixedClock().now(), deleted: false, state: state
  };
  return JSON.stringify(envelope);
}

export class ViewModelRig {
  story: StoryDefinition = createStory();
  store: FakeTextStore = new FakeTextStore();
  repository: SaveRepository = new SaveRepository(this.store, this.story, new FixedClock());
  vm: GameViewModel = new GameViewModel(this.story, this.repository);
  async start(): Promise<void> { await this.vm.initialize(); await this.vm.newGame(); }
  async choose(id: string): Promise<void> { await this.vm.act(choiceAction(this.vm.state, id)); }
}
