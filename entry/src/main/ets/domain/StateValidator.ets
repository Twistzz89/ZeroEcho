import { Choice, Clue, Effect, GameState, HistoryEntry, Puzzle, PuzzleAttempt, StoryDefinition, StoryNode, createInitialState } from '../models/Models';
import { evaluateConditions } from './ConditionEvaluator';
import { resolveEnding } from './EndingResolver';

function validStrings(items: string[], allowed: string[]): boolean {
  return Array.isArray(items) && items.every((id: string, index: number): boolean =>
    typeof id === 'string' && allowed.indexOf(id) >= 0 && items.indexOf(id) === index);
}

function sameStrings(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((value: string, index: number): boolean => value === right[index]);
}

function getNode(story: StoryDefinition, id: string): StoryNode | undefined {
  return story.nodes.find((node: StoryNode): boolean => node.id === id);
}

/** Empty result means valid. JSON casts never replace these runtime checks. */
export function validateState(state: GameState, story: StoryDefinition): string {
  if (state === null || typeof state !== 'object') {
    return '存档游戏状态不是对象';
  }
  const nodeIds: string[] = story.nodes.map((node: StoryNode): string => node.id);
  const clueIds: string[] = story.clues.map((clue: Clue): string => clue.id);
  const puzzleIds: string[] = story.puzzles.map((puzzle: Puzzle): string => puzzle.id);
  const actionIds: string[] = [];
  story.nodes.forEach((node: StoryNode): void => node.choices.forEach((choice: Choice): void => {
    if (choice.once) {
      actionIds.push(choice.id);
    }
  }));
  if (typeof state.currentNodeId !== 'string' || nodeIds.indexOf(state.currentNodeId) < 0 ||
    !Number.isInteger(state.remainingActions) || state.remainingActions < 0 || state.remainingActions > 18 ||
    !Number.isInteger(state.trust) || state.trust < 0 || state.trust > 100 ||
    !Number.isInteger(state.revision) || state.revision < 0 ||
    typeof state.endingId !== 'string' || ['', 'E01', 'E02', 'E03', 'E04'].indexOf(state.endingId) < 0) {
    return '存档节点、数值或结局字段无效';
  }
  if (!validStrings(state.clueIds, clueIds) || !validStrings(state.solvedPuzzleIds, puzzleIds) ||
    !validStrings(state.flags, story.flagIds) || !validStrings(state.usedActionIds, actionIds) ||
    !Array.isArray(state.attempts) || !Array.isArray(state.history)) {
    return '存档列表缺失、包含重复项或非法引用';
  }
  const seenAttempts: string[] = [];
  for (let index: number = 0; index < state.attempts.length; index++) {
    const attempt: PuzzleAttempt = state.attempts[index];
    if (attempt === null || typeof attempt !== 'object' || typeof attempt.puzzleId !== 'string' ||
      puzzleIds.indexOf(attempt.puzzleId) < 0 || seenAttempts.indexOf(attempt.puzzleId) >= 0 ||
      !Number.isInteger(attempt.count) || attempt.count < 1 || attempt.count > 18) {
      return '谜题尝试记录无效';
    }
    seenAttempts.push(attempt.puzzleId);
  }
  if (state.history.length !== state.revision) {
    return '状态版本与历史条数不一致';
  }
  const reconstructed: GameState = createInitialState(story);
  for (let index: number = 0; index < state.history.length; index++) {
    const entry: HistoryEntry = state.history[index];
    if (entry === null || typeof entry !== 'object' || entry.sequence !== index + 1 ||
      typeof entry.fromNodeId !== 'string' || typeof entry.toNodeId !== 'string' ||
      typeof entry.actionId !== 'string' || typeof entry.actionText !== 'string' || typeof entry.message !== 'string' ||
      typeof entry.puzzleId !== 'string' || !Number.isInteger(entry.cost) || entry.cost < 0 || entry.cost > 18 ||
      !Number.isInteger(entry.trustDelta) || Math.abs(entry.trustDelta) > 100 ||
      !validStrings(entry.clueIds, clueIds)) {
      return '历史记录字段无效';
    }
    if (reconstructed.endingId !== '' || entry.fromNodeId !== reconstructed.currentNodeId ||
      reconstructed.remainingActions < entry.cost) {
      return '历史路径不连续或结局后仍有操作';
    }
    const node: StoryNode | undefined = getNode(story, entry.fromNodeId);
    if (node === undefined) {
      return '历史节点不存在';
    }
    const priorTrust: number = reconstructed.trust;
    const gained: string[] = [];
    let behavior: string = 'move';
    if (node.kind === 'puzzle' && entry.actionId === node.puzzleId) {
      const puzzle: Puzzle | undefined = story.puzzles.find((item: Puzzle): boolean => item.id === entry.actionId);
      if (puzzle === undefined || !evaluateConditions(puzzle.conditions, reconstructed).ok ||
        reconstructed.solvedPuzzleIds.indexOf(puzzle.id) >= 0 || entry.cost !== puzzle.cost ||
        (entry.puzzleId !== '' && entry.puzzleId !== puzzle.id)) {
        return '历史谜题记录不符合规则';
      }
      let attempt: PuzzleAttempt | undefined = reconstructed.attempts.find((item: PuzzleAttempt): boolean => item.puzzleId === puzzle.id);
      if (attempt === undefined) {
        reconstructed.attempts.push({ puzzleId: puzzle.id, count: 1 });
      } else {
        attempt.count++;
      }
      if (entry.puzzleId === puzzle.id) {
        reconstructed.solvedPuzzleIds.push(puzzle.id);
        reconstructed.currentNodeId = puzzle.targetNodeId;
        if (reconstructed.clueIds.indexOf(puzzle.rewardClueId) < 0) {
          reconstructed.clueIds.push(puzzle.rewardClueId);
          gained.push(puzzle.rewardClueId);
        }
      }
    } else {
      const choice: Choice | undefined = node.choices.find((item: Choice): boolean => item.id === entry.actionId);
      if (choice === undefined || entry.puzzleId !== '' || entry.cost !== choice.cost ||
        !evaluateConditions(choice.conditions, reconstructed).ok ||
        (choice.once && reconstructed.usedActionIds.indexOf(choice.id) >= 0)) {
        return '历史选项记录不符合规则';
      }
      behavior = choice.behavior;
      reconstructed.currentNodeId = choice.targetNodeId;
      if (choice.once) {
        reconstructed.usedActionIds.push(choice.id);
      }
      for (let effectIndex: number = 0; effectIndex < choice.effects.length; effectIndex++) {
        const effect: Effect = choice.effects[effectIndex];
        if (effect.kind === 'trust') {
          reconstructed.trust = Math.max(0, Math.min(100, reconstructed.trust + effect.value));
        }
        if (effect.kind === 'clue') {
          if (reconstructed.clueIds.indexOf(effect.key) >= 0) {
            return '历史中重复取得线索';
          }
          reconstructed.clueIds.push(effect.key);
          gained.push(effect.key);
        }
        if (effect.kind === 'flag' && reconstructed.flags.indexOf(effect.key) < 0) {
          reconstructed.flags.push(effect.key);
        }
      }
    }
    reconstructed.remainingActions -= entry.cost;
    reconstructed.endingId = resolveEnding(reconstructed, node.kind === 'summary', behavior).endingId;
    if (reconstructed.endingId !== '') {
      reconstructed.currentNodeId = reconstructed.endingId;
    }
    if (entry.toNodeId !== reconstructed.currentNodeId || entry.trustDelta !== reconstructed.trust - priorTrust || !sameStrings(entry.clueIds, gained)) {
      return '历史结果与实际规则不一致';
    }
  }
  if (state.currentNodeId !== reconstructed.currentNodeId || state.remainingActions !== reconstructed.remainingActions ||
    state.trust !== reconstructed.trust || state.endingId !== reconstructed.endingId ||
    !sameStrings(state.clueIds, reconstructed.clueIds) || !sameStrings(state.solvedPuzzleIds, reconstructed.solvedPuzzleIds) ||
    !sameStrings(state.flags, reconstructed.flags) || !sameStrings(state.usedActionIds, reconstructed.usedActionIds) ||
    state.attempts.length !== reconstructed.attempts.length) {
    return '存档状态与历史推导结果不一致';
  }
  for (let index: number = 0; index < state.attempts.length; index++) {
    if (state.attempts[index].puzzleId !== reconstructed.attempts[index].puzzleId || state.attempts[index].count !== reconstructed.attempts[index].count) {
      return '谜题尝试次数与历史不一致';
    }
  }
  return '';
}
