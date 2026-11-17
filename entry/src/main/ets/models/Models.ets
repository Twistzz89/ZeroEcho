export interface Condition {
  kind: string;
  key: string;
  value: number;
}

export interface ConditionGroup {
  all: Condition[];
  any: Condition[];
}

export interface Effect {
  kind: string;
  key: string;
  value: number;
}

export interface Choice {
  id: string;
  text: string;
  targetNodeId: string;
  cost: number;
  once: boolean;
  conditions: ConditionGroup;
  effects: Effect[];
  behavior: string;
}

export interface StoryNode {
  id: string;
  chapterId: string;
  title: string;
  speaker: string;
  kind: string;
  text: string;
  puzzleId: string;
  choices: Choice[];
}

export interface Clue {
  id: string;
  title: string;
  category: string;
  text: string;
}

export interface Puzzle {
  id: string;
  title: string;
  hint: string;
  conditions: ConditionGroup;
  answer: string;
  order: string;
  rewardClueId: string;
  targetNodeId: string;
  cost: number;
}

export interface Ending {
  id: string;
  title: string;
  text: string;
}

export interface StoryDefinition {
  storyId: string;
  contentVersion: number;
  startNodeId: string;
  nodes: StoryNode[];
  clues: Clue[];
  puzzles: Puzzle[];
  endings: Ending[];
  flagIds: string[];
}

export interface PuzzleAttempt {
  puzzleId: string;
  count: number;
}

export interface HistoryEntry {
  sequence: number;
  fromNodeId: string;
  actionId: string;
  actionText: string;
  toNodeId: string;
  cost: number;
  trustDelta: number;
  clueIds: string[];
  puzzleId: string;
  message: string;
}

export class GameState {
  currentNodeId: string = '';
  remainingActions: number = 18;
  trust: number = 50;
  clueIds: string[] = [];
  solvedPuzzleIds: string[] = [];
  flags: string[] = [];
  usedActionIds: string[] = [];
  attempts: PuzzleAttempt[] = [];
  history: HistoryEntry[] = [];
  endingId: string = '';
  revision: number = 0;
}

export interface GameAction {
  kind: string;
  nodeId: string;
  id: string;
  expectedRevision: number;
  answer: string;
  order: string;
}

export interface TransitionResult {
  ok: boolean;
  state: GameState;
  error: string;
  message: string;
}

export interface ConditionResult {
  ok: boolean;
  reason: string;
}

export interface ChoiceViewModel {
  choice: Choice;
  enabled: boolean;
  disabledReason: string;
}

export interface PuzzleResult {
  valid: boolean;
  correct: boolean;
  reason: string;
}

export interface EndingResult {
  endingId: string;
  reasons: string[];
}

export interface ValidationResult {
  ok: boolean;
  error: string;
}

export function cloneState(state: GameState): GameState {
  const next: GameState = new GameState();
  next.currentNodeId = state.currentNodeId;
  next.remainingActions = state.remainingActions;
  next.trust = state.trust;
  next.clueIds = state.clueIds.slice();
  next.solvedPuzzleIds = state.solvedPuzzleIds.slice();
  next.flags = state.flags.slice();
  next.usedActionIds = state.usedActionIds.slice();
  next.attempts = state.attempts.map((item: PuzzleAttempt): PuzzleAttempt => {
    return { puzzleId: item.puzzleId, count: item.count };
  });
  next.history = state.history.map((item: HistoryEntry): HistoryEntry => {
    return {
      sequence: item.sequence, fromNodeId: item.fromNodeId, actionId: item.actionId,
      actionText: item.actionText, toNodeId: item.toNodeId, cost: item.cost,
      trustDelta: item.trustDelta, clueIds: item.clueIds.slice(), puzzleId: item.puzzleId,
      message: item.message
    };
  });
  next.endingId = state.endingId;
  next.revision = state.revision;
  return next;
}

export function createInitialState(story: StoryDefinition): GameState {
  const state: GameState = new GameState();
  state.currentNodeId = story.startNodeId;
  return state;
}
