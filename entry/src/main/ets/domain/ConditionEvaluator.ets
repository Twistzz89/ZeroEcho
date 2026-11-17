import { Condition, ConditionGroup, ConditionResult, GameState } from '../models/Models';

export function evaluateCondition(condition: Condition, state: GameState): ConditionResult {
  if (condition.kind === 'clue') {
    return { ok: state.clueIds.indexOf(condition.key) >= 0, reason: '需要线索 ' + condition.key };
  }
  if (condition.kind === 'trust') {
    return { ok: state.trust >= condition.value, reason: '需要信任至少 ' + condition.value };
  }
  if (condition.kind === 'puzzle') {
    return { ok: state.solvedPuzzleIds.indexOf(condition.key) >= 0, reason: '需要完成谜题 ' + condition.key };
  }
  if (condition.kind === 'flag') {
    return { ok: state.flags.indexOf(condition.key) >= 0, reason: '需要经历：' + condition.key };
  }
  if (condition.kind === 'actions') {
    return { ok: state.remainingActions >= condition.value, reason: '需要至少 ' + condition.value + ' 次调查机会' };
  }
  return { ok: false, reason: '未知条件类型：' + condition.kind };
}

export function evaluateConditions(group: ConditionGroup, state: GameState): ConditionResult {
  for (let index: number = 0; index < group.all.length; index++) {
    const result: ConditionResult = evaluateCondition(group.all[index], state);
    if (!result.ok) {
      return result;
    }
  }
  if (group.any.length > 0) {
    const reasons: string[] = [];
    let matched: boolean = false;
    for (let index: number = 0; index < group.any.length; index++) {
      const result: ConditionResult = evaluateCondition(group.any[index], state);
      if (result.reason.indexOf('未知条件类型：') === 0) {
        return result;
      }
      matched = matched || result.ok;
      reasons.push(result.reason);
    }
    if (!matched) {
      return { ok: false, reason: reasons.join('，或') };
    }
  }
  return { ok: true, reason: '' };
}
