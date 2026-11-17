import { Choice, ChoiceViewModel, ConditionResult, Effect, EndingResult, GameAction, GameState, HistoryEntry, Puzzle, PuzzleAttempt, PuzzleResult, StoryDefinition, StoryNode, TransitionResult, cloneState } from '../models/Models';
import { validateStory } from '../data/StoryRepository';
import { evaluateConditions } from './ConditionEvaluator';
import { checkPuzzle } from './PuzzleService';
import { resolveEnding } from './EndingResolver';

export class GameEngine {
  private story: StoryDefinition;

  constructor(story: StoryDefinition) {
    const checked = validateStory(story);
    if (!checked.ok) {
      throw new Error(checked.error);
    }
    this.story = story;
  }

  getNode(nodeId: string): StoryNode | undefined {
    return this.story.nodes.find((node: StoryNode): boolean => node.id === nodeId);
  }

  private availability(state: GameState, choice: Choice): ConditionResult {
    if (state.endingId !== '') {
      return { ok: false, reason: '本局已结束，请开始新游戏或读取存档' };
    }
    if (choice.once && state.usedActionIds.indexOf(choice.id) >= 0) {
      return { ok: false, reason: '已完成，可在档案或回顾中查看' };
    }
    if (choice.effects.some((change: Effect): boolean => change.kind === 'clue' && state.clueIds.indexOf(change.key) >= 0)) {
      return { ok: false, reason: '已取得这条线索，可在档案中查看' };
    }
    const conditions: ConditionResult = evaluateConditions(choice.conditions, state);
    if (!conditions.ok) {
      return conditions;
    }
    if (state.remainingActions < choice.cost) {
      return { ok: false, reason: '调查机会不足，需要 ' + choice.cost + ' 次' };
    }
    return { ok: true, reason: '' };
  }

  getAvailableChoices(state: GameState): ChoiceViewModel[] {
    const node: StoryNode | undefined = this.getNode(state.currentNodeId);
    if (node === undefined) {
      return [];
    }
    return node.choices.map((choice: Choice): ChoiceViewModel => {
      const checked: ConditionResult = this.availability(state, choice);
      return { choice: choice, enabled: checked.ok, disabledReason: checked.reason };
    });
  }

  private reject(state: GameState, error: string, message: string): TransitionResult {
    return { ok: false, state: state, error: error, message: message };
  }

  dispatch(state: GameState, action: GameAction): TransitionResult {
    if (action === null || typeof action !== 'object' || !Number.isInteger(action.expectedRevision) ||
      typeof action.nodeId !== 'string' || typeof action.id !== 'string' || typeof action.kind !== 'string') {
      return this.reject(state, 'INVALID_ACTION', '动作格式无效');
    }
    if (!Number.isInteger(state.remainingActions) || state.remainingActions < 0 || state.remainingActions > 18 ||
      !Number.isInteger(state.trust) || state.trust < 0 || state.trust > 100) {
      return this.reject(state, 'INVALID_STATE', '游戏状态数值无效');
    }
    if (state.endingId !== '' || state.remainingActions === 0) {
      return this.reject(state, 'ENDED', '本局已结束，不能继续消耗机会或获得奖励');
    }
    if (action.expectedRevision !== state.revision || action.nodeId !== state.currentNodeId) {
      return this.reject(state, 'STALE_ACTION', '状态已更新，请根据当前页面重新操作');
    }
    const node: StoryNode | undefined = this.getNode(state.currentNodeId);
    if (node === undefined) {
      return this.reject(state, 'INVALID_NODE', '当前剧情节点不存在');
    }
    if (action.kind === 'choice') {
      return this.dispatchChoice(state, action, node);
    }
    if (action.kind === 'puzzle') {
      return this.dispatchPuzzle(state, action, node);
    }
    return this.reject(state, 'INVALID_ACTION', '不支持的动作类型');
  }

  private finish(state: GameState, next: GameState, node: StoryNode, actionId: string,
    actionText: string, cost: number, behavior: string, puzzleId: string, message: string): TransitionResult {
    const ending: EndingResult = resolveEnding(next, node.kind === 'summary', behavior);
    if (ending.endingId !== '') {
      next.endingId = ending.endingId;
      next.currentNodeId = ending.endingId;
      message = message + '；' + ending.reasons.join(' ');
    }
    next.revision = state.revision + 1;
    const entry: HistoryEntry = {
      sequence: next.revision, fromNodeId: state.currentNodeId, actionId: actionId,
      actionText: actionText, toNodeId: next.currentNodeId, cost: cost,
      trustDelta: next.trust - state.trust,
      clueIds: next.clueIds.filter((id: string): boolean => state.clueIds.indexOf(id) < 0),
      puzzleId: puzzleId, message: message
    };
    next.history.push(entry);
    return { ok: true, state: next, error: '', message: message };
  }

  private dispatchChoice(state: GameState, action: GameAction, node: StoryNode): TransitionResult {
    const selected: Choice | undefined = node.choices.find((choice: Choice): boolean => choice.id === action.id);
    if (selected === undefined) {
      return this.reject(state, 'INVALID_CHOICE', '当前节点不存在这个选项');
    }
    const checked: ConditionResult = this.availability(state, selected);
    if (!checked.ok) {
      return this.reject(state, 'CHOICE_LOCKED', checked.reason);
    }
    if (this.getNode(selected.targetNodeId) === undefined) {
      return this.reject(state, 'INVALID_TARGET', '剧情目标无效，状态未改变');
    }
    const next: GameState = cloneState(state);
    next.remainingActions -= selected.cost;
    next.currentNodeId = selected.targetNodeId;
    if (selected.once) {
      next.usedActionIds.push(selected.id);
    }
    for (let index: number = 0; index < selected.effects.length; index++) {
      const effect: Effect = selected.effects[index];
      if (effect.kind === 'trust') {
        next.trust = Math.max(0, Math.min(100, next.trust + effect.value));
      } else if (effect.kind === 'clue') {
        if (next.clueIds.indexOf(effect.key) < 0) {
          next.clueIds.push(effect.key);
        }
      } else if (effect.kind === 'flag') {
        if (next.flags.indexOf(effect.key) < 0) {
          next.flags.push(effect.key);
        }
      } else {
        return this.reject(state, 'INVALID_EFFECT', '剧情效果无效，状态未改变');
      }
    }
    return this.finish(state, next, node, selected.id, selected.text, selected.cost, selected.behavior, '', '已执行：' + selected.text);
  }

  private dispatchPuzzle(state: GameState, action: GameAction, node: StoryNode): TransitionResult {
    if (node.kind !== 'puzzle' || node.puzzleId !== action.id) {
      return this.reject(state, 'INVALID_PUZZLE', '当前节点不能提交这个谜题');
    }
    const puzzle: Puzzle | undefined = this.story.puzzles.find((item: Puzzle): boolean => item.id === action.id);
    if (puzzle === undefined) {
      return this.reject(state, 'INVALID_PUZZLE', '谜题不存在');
    }
    const result: PuzzleResult = checkPuzzle(puzzle, action.answer, action.order, state);
    if (!result.valid) {
      return this.reject(state, 'INVALID_ANSWER', result.reason);
    }
    if (state.remainingActions < puzzle.cost) {
      return this.reject(state, 'INSUFFICIENT_ACTIONS', '调查机会不足');
    }
    const next: GameState = cloneState(state);
    next.remainingActions -= puzzle.cost;
    const attempt: PuzzleAttempt | undefined = next.attempts.find((item: PuzzleAttempt): boolean => item.puzzleId === puzzle.id);
    if (attempt === undefined) {
      next.attempts.push({ puzzleId: puzzle.id, count: 1 });
    } else {
      attempt.count++;
    }
    if (result.correct) {
      next.solvedPuzzleIds.push(puzzle.id);
      if (next.clueIds.indexOf(puzzle.rewardClueId) < 0) {
        next.clueIds.push(puzzle.rewardClueId);
      }
      next.currentNodeId = puzzle.targetNodeId;
    }
    return this.finish(state, next, node, puzzle.id, puzzle.title + (result.correct ? '：正确' : '：重试'),
      puzzle.cost, 'move', result.correct ? puzzle.id : '', result.reason);
  }
}
