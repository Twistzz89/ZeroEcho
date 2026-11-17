import { EndingResult, GameState } from '../models/Models';

export function resolveEnding(state: GameState, atSummary: boolean, behavior: string): EndingResult {
  if (state.remainingActions === 0) {
    return { endingId: 'E03', reasons: ['调查机会已耗尽，优先进入调查中断结局。'] };
  }
  if (!atSummary || (behavior !== 'submit' && behavior !== 'stop')) {
    return { endingId: '', reasons: [] };
  }
  if (behavior === 'stop') {
    return { endingId: 'E04', reasons: ['你在最后报告阶段主动结束了调查。'] };
  }
  const hasAccess: boolean = state.clueIds.indexOf('CL02') >= 0;
  const hasConfig: boolean = state.clueIds.indexOf('CL05') >= 0;
  const hasTimeline: boolean = state.clueIds.indexOf('CL06') >= 0;
  const firstSolved: boolean = state.solvedPuzzleIds.indexOf('P01') >= 0;
  const secondSolved: boolean = state.solvedPuzzleIds.indexOf('P02') >= 0;
  if (hasAccess && hasConfig && hasTimeline && firstSolved && secondSolved && state.trust >= 60) {
    return { endingId: 'E01', reasons: ['访问记录、任务配置与已校正时间线齐全。', '两个谜题均已完成。', '同伴信任为 ' + state.trust + '，达到60。', '标准时间00:00的回滚任务早于00:02的人员进入。'] };
  }
  if (hasAccess && hasConfig && firstSolved) {
    const reasons: string[] = ['访问记录与定时任务配置齐全，档案柜谜题已完成，足以定位并修复任务配置。'];
    if (!hasTimeline || !secondSolved) {
      reasons.push('尚未完成完整时间线校正，人员进入与回滚的先后关系仍缺少完整核验。');
    }
    if (state.trust < 60) {
      reasons.push('同伴信任为 ' + state.trust + '，未达到完整真相所需的60。');
    }
    return { endingId: 'E02', reasons: reasons };
  }
  const reasons: string[] = ['提交时证据尚不足以进入完整真相或局部修复。'];
  if (!hasAccess || !firstSolved) {
    reasons.push('缺少已解锁的访问记录。');
  }
  if (!hasConfig) {
    reasons.push('缺少定时任务配置。');
  }
  return { endingId: 'E04', reasons: reasons };
}

export function explainEnding(state: GameState): string[] {
  if (state.endingId === '') {
    return ['调查尚未结束。'];
  }
  const stopped: boolean = state.history.length > 0 && state.history[state.history.length - 1].actionId === 'stop';
  return resolveEnding(state, true, stopped ? 'stop' : 'submit').reasons;
}
