import { GameState, Puzzle, PuzzleResult, ConditionResult } from '../models/Models';
import { evaluateConditions } from './ConditionEvaluator';

export function checkPuzzle(puzzle: Puzzle, answer: string, order: string, state: GameState): PuzzleResult {
  if (state.solvedPuzzleIds.indexOf(puzzle.id) >= 0) {
    return { valid: false, correct: false, reason: '这个谜题已经完成，无需重复提交' };
  }
  const available: ConditionResult = evaluateConditions(puzzle.conditions, state);
  if (!available.ok) {
    return { valid: false, correct: false, reason: available.reason };
  }
  if (typeof answer !== 'string' || typeof order !== 'string') {
    return { valid: false, correct: false, reason: '答案格式错误' };
  }
  if (puzzle.id === 'P01') {
    if (!/^[0-9]{4}$/.test(answer)) {
      return { valid: false, correct: false, reason: '请输入4位数字，保留开头的0；格式错误不消耗机会' };
    }
  } else if (puzzle.id === 'P02') {
    if (!/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(answer) ||
      (order !== 'task-first' && order !== 'person-first')) {
      return { valid: false, correct: false, reason: '请选择有效的24小时制时间和事件顺序；格式错误不消耗机会' };
    }
  } else {
    return { valid: false, correct: false, reason: '未知谜题' };
  }
  const correct: boolean = answer === puzzle.answer && order === puzzle.order;
  return { valid: true, correct: correct, reason: correct ? '推理正确，已取得新线索' : '答案尚不正确，消耗1次调查机会；请查看线索后重试' };
}
