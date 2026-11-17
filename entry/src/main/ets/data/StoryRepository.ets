import { Choice, Clue, Condition, ConditionGroup, Effect, Ending, Puzzle, StoryDefinition, StoryNode, ValidationResult } from '../models/Models';

function group(all: Condition[] = [], any: Condition[] = []): ConditionGroup {
  return { all: all, any: any };
}

function condition(kind: string, key: string = '', value: number = 0): Condition {
  return { kind: kind, key: key, value: value };
}

function effect(kind: string, key: string = '', value: number = 0): Effect {
  return { kind: kind, key: key, value: value };
}

function choice(id: string, text: string, target: string, cost: number = 0,
  once: boolean = false, conditions: ConditionGroup = group(), effects: Effect[] = [], behavior: string = 'move'): Choice {
  return { id: id, text: text, targetNodeId: target, cost: cost, once: once, conditions: conditions, effects: effects, behavior: behavior };
}

function node(id: string, chapter: string, title: string, text: string, choices: Choice[],
  speaker: string = '调查记录', kind: string = 'normal', puzzleId: string = ''): StoryNode {
  return { id: id, chapterId: chapter, title: title, speaker: speaker, kind: kind, text: text, puzzleId: puzzleId, choices: choices };
}

export function createStory(): StoryDefinition {
  const clues: Clue[] = [
    { id: 'CL01', title: '实验笔记', category: '纸质档案', text: '页边写着“访问档案 04-17”。档案柜使用四位编号，开头的0也是编号的一部分。记录仅用于本次虚构实验。' },
    { id: 'CL02', title: '实验室访问记录', category: '访问档案', text: '门禁采用标准时间：00:02，林澈进入实验室。进入记录与操作记录不同，单凭这一条不能证明回滚由人员触发。' },
    { id: 'CL03', title: '时钟校准记录', category: '设备日志', text: '校准单注明：网关时钟比标准时间快5分钟。换算时应从网关显示时间减去5分钟。' },
    { id: 'CL04', title: '网关事件记录', category: '设备日志', text: '网关本地时间00:05：启动rollback_nightly任务。该日志使用网关自身时钟，不能直接与门禁标准时间比较。' },
    { id: 'CL05', title: '定时任务配置', category: '配置备份', text: '配置备份：rollback_nightly在标准时间00:00触发，执行测试数据回滚。迁移配置时未关闭演示用任务，是本次异常的来源。' },
    { id: 'CL06', title: '已校正时间线', category: '推理结论', text: '00:05减去5分钟，对应标准时间00:00。回滚任务先发生，人员在00:02后进入。两条记录并不支持“人员进入导致回滚”的推断。' }
  ];
  const puzzles: Puzzle[] = [
    { id: 'P01', title: '档案柜编号', hint: '实验笔记中的04-17对应四位编号。输入时保留开头的0。查看提示不扣机会。', conditions: group([condition('clue', 'CL01')]), answer: '0417', order: '', rewardClueId: 'CL02', targetNodeId: 'N05', cost: 1 },
    { id: 'P02', title: '校正零点时间线', hint: '网关显示00:05，校准单说明它快5分钟。门禁记录的人员进入时间为标准时间00:02。请填写任务标准时间并判断先后。', conditions: group([condition('clue', 'CL03'), condition('clue', 'CL04')]), answer: '00:00', order: 'task-first', rewardClueId: 'CL06', targetNodeId: 'N13', cost: 1 }
  ];
  const endings: Ending[] = [
    { id: 'E01', title: '完整真相', text: '证据与时间线相互印证。你和林澈一起撤销误设的回滚任务，澄清了关于人员操作的误会，并为实验室留下可复查的记录。' },
    { id: 'E02', title: '局部修复', text: '你找到了定时任务并修复配置，系统恢复正常。但时间线或沟通仍有缺口，关于当晚的误会还需要后续核实。' },
    { id: 'E03', title: '调查中断', text: '调查机会耗尽，开放时段结束。当前线索被保留，但这次调查无法继续；你可以从手动存档重试，或开启新一局。' },
    { id: 'E04', title: '未解疑云', text: '调查暂时结束。现有证据不足以给出可靠结论，你把尚待核实的问题列入报告，没有把猜测写成事实。' }
  ];
  const nodes: StoryNode[] = [
    node('N01', '第一章 零点来信', '零点的求助', '云岚学院实验楼的灯还亮着。林澈发来消息：“演示数据回到了昨天的状态，大家以为是我误操作了。”你决定先回应这条求助。今晚只剩18次调查机会。', [
      choice('share', '共享收到的信息，约定一起核查', 'N02', 1, true, group(), [effect('trust', '', 10), effect('flag', 'shared')]),
      choice('hold', '暂时保留信息，先独自核查', 'N02', 1, true, group(), [effect('flag', 'reserved')]),
      choice('accuse', '未核实就质疑林澈的操作', 'N02', 1, true, group(), [effect('trust', '', -10), effect('flag', 'accused')])
    ], '林澈'),
    node('N02', '第一章 零点来信', '实验桌上的笔记', '桌边压着一份实验笔记，旁边是带编号锁的访问档案柜。你可以先检查笔记，也可以暂时跳过，之后再回来。', [
      choice('take-note', '调查实验笔记', 'N03', 1, true, group(), [effect('clue', 'CL01')]),
      choice('skip-note', '先去档案柜', 'N04')
    ]),
    node('N03', '第一章 零点来信', '四位档案号', '笔记写着“访问档案 04-17”。你把它收入线索档案。编号中的0不是装饰，输入档案柜时需要保留。', [choice('note-to-cabinet', '前往档案柜', 'N04')]),
    node('N04', '第一章 零点来信', '档案柜', '档案柜显示四位编号输入框。你可以尝试解锁，也可以先推进调查。有效的四位答案每次消耗1次机会；格式错误不扣机会。', [
      choice('cabinet-back', '回到实验桌查看笔记', 'N02'),
      choice('skip-cabinet', '暂时跳过档案柜', 'N05')
    ], '档案终端', 'puzzle', 'P01'),
    node('N05', '第二章 错位时间', '是否一起调查', '林澈在走廊等你。愿意共享信息带来的信任，可以让你获得现场协助；如果信任不足，你仍能独立检查终端日志。', [
      choice('cooperate', '邀请林澈协助，进入现场核对', 'N06', 0, false, group([condition('trust', '', 60)])),
      choice('work-alone', '独自检查设备日志', 'N07', 0, false)
    ], '林澈'),
    node('N06', '第二章 错位时间', '愿意合作的同伴', '林澈把自己的操作过程逐项说明：“我进门时看到回滚已经发生。”你记录了这条口述，但仍需要原始日志来核验。', [
      choice('record-witness', '记录口述并继续核查', 'N08', 1, true, group(), [effect('flag', 'witnessed')]),
      choice('witness-back', '口述已记录，返回调查区', 'N08', 0, false, group([condition('flag', 'witnessed')]))
    ], '林澈'),
    node('N07', '第二章 错位时间', '独立核查', '你决定从设备记录入手。没有同伴直接协助，配置备份入口需要先从网关日志中定位。所有结论仍可通过原始记录核实。', [choice('alone-to-hub', '进入设备调查区', 'N08')]),
    node('N08', '第二章 错位时间', '三份不同来源的记录', '校准单、网关事件与配置备份放在不同位置。比较时间前先确认各自使用的时钟。你可以自由安排调查顺序，也可以带着已有证据整理报告。', [
      choice('take-calibration', '调查时钟校准单', 'N09', 1, true, group(), [effect('clue', 'CL03')]),
      choice('take-gateway', '调查网关事件日志', 'N10', 1, true, group(), [effect('clue', 'CL04')]),
      choice('take-config', '调查定时任务配置', 'N11', 1, true, group([], [condition('trust', '', 60), condition('clue', 'CL04')]), [effect('clue', 'CL05')]),
      choice('open-timeline', '校正时间线', 'N12', 0, false, group([condition('clue', 'CL03'), condition('clue', 'CL04')])),
      choice('revisit-cabinet', '返回档案柜补查', 'N04'),
      choice('to-report', '整理最后报告', 'N13')
    ]),
    node('N09', '第二章 错位时间', '快了五分钟', '校准记录已归档。网关比标准时间快5分钟，因此网关时间必须减去5分钟后再比较。', [choice('calibration-back', '返回调查区', 'N08')]),
    node('N10', '第二章 错位时间', '零点零五分的任务', '事件记录已归档。网关本地时间00:05启动了一个回滚任务；日志还列出了它的配置备份位置。低信任路线现在也可以调查配置。', [choice('gateway-back', '返回调查区', 'N08')]),
    node('N11', '第二章 错位时间', '遗漏的演示任务', '配置显示：演示任务在标准时间00:00触发回滚。你找到了可以修复的配置问题，但还需比较访问记录与校正后的事件时间。', [choice('config-back', '返回调查区', 'N08')]),
    node('N12', '第二章 错位时间', '把时钟放到同一刻度', '请根据CL03和CL04填写标准时间，并判断任务启动与人员进入的先后。门禁记录中人员进入的标准时间为00:02。合法答案提交消耗1次机会。', [choice('timeline-back', '返回查看线索，稍后再解', 'N08')], '时间线工作台', 'puzzle', 'P02'),
    node('N13', '第三章 最后报告', '证据准备好了吗', '报告只写已经核实的事实。提交与结束调查都不消耗机会；证据和信任将共同决定结局。你也可以继续补充调查。', [
      choice('submit', '提交当前证据与结论', 'N13', 0, true, group(), [], 'submit'),
      choice('stop', '主动结束调查，保留疑问', 'N13', 0, true, group(), [], 'stop'),
      choice('report-back', '返回补充调查', 'N08')
    ], '报告草稿', 'summary')
  ];
  for (let index: number = 0; index < endings.length; index++) {
    const ending: Ending = endings[index];
    nodes.push(node(ending.id, '调查结局', ending.title, ending.text, [], '调查归档', 'ending'));
  }
  const story: StoryDefinition = {
    storyId: 'zero-echo', contentVersion: 1, startNodeId: 'N01', nodes: nodes,
    clues: clues, puzzles: puzzles, endings: endings, flagIds: ['shared', 'reserved', 'accused', 'witnessed']
  };
  const checked: ValidationResult = validateStory(story);
  if (!checked.ok) {
    throw new Error(checked.error);
  }
  return story;
}

function unique(ids: string[]): boolean {
  return ids.every((id: string, index: number): boolean => typeof id === 'string' && id.length > 0 && ids.indexOf(id) === index);
}

function checkConditions(value: ConditionGroup, story: StoryDefinition): boolean {
  if (value === null || typeof value !== 'object' || !Array.isArray(value.all) || !Array.isArray(value.any)) {
    return false;
  }
  const all: Condition[] = value.all.concat(value.any);
  return all.every((item: Condition): boolean => {
    if (item === null || typeof item !== 'object' || typeof item.key !== 'string' || !Number.isInteger(item.value)) {
      return false;
    }
    if (item.kind === 'clue') {
      return story.clues.some((clue: Clue): boolean => clue.id === item.key);
    }
    if (item.kind === 'puzzle') {
      return story.puzzles.some((puzzle: Puzzle): boolean => puzzle.id === item.key);
    }
    if (item.kind === 'flag') {
      return story.flagIds.indexOf(item.key) >= 0;
    }
    return (item.kind === 'trust' && item.value >= 0 && item.value <= 100) ||
      (item.kind === 'actions' && item.value >= 0 && item.value <= 18);
  });
}

export function validateStory(story: StoryDefinition): ValidationResult {
  const fail: ValidationResult = { ok: false, error: '剧情配置无效' };
  if (story === null || typeof story !== 'object' || typeof story.storyId !== 'string' ||
    !Number.isInteger(story.contentVersion) || story.contentVersion < 1 ||
    !Array.isArray(story.nodes) || !Array.isArray(story.clues) || !Array.isArray(story.puzzles) ||
    !Array.isArray(story.endings) || !Array.isArray(story.flagIds)) {
    return fail;
  }
  if (story.nodes.some((item: StoryNode): boolean => item === null || typeof item !== 'object') ||
    story.clues.some((item: Clue): boolean => item === null || typeof item !== 'object') ||
    story.puzzles.some((item: Puzzle): boolean => item === null || typeof item !== 'object') ||
    story.endings.some((item: Ending): boolean => item === null || typeof item !== 'object')) {
    return fail;
  }
  const nodeIds: string[] = story.nodes.map((item: StoryNode): string => item.id);
  const clueIds: string[] = story.clues.map((item: Clue): string => item.id);
  const puzzleIds: string[] = story.puzzles.map((item: Puzzle): string => item.id);
  const endingIds: string[] = story.endings.map((item: Ending): string => item.id);
  if (!unique(nodeIds) || !unique(clueIds) || !unique(puzzleIds) || !unique(endingIds) || !unique(story.flagIds) || nodeIds.indexOf(story.startNodeId) < 0) {
    return { ok: false, error: '剧情ID重复或起点无效' };
  }
  if (story.clues.some((item: Clue): boolean => typeof item.title !== 'string' || typeof item.category !== 'string' || typeof item.text !== 'string') ||
    story.endings.some((item: Ending): boolean => typeof item.title !== 'string' || typeof item.text !== 'string')) {
    return { ok: false, error: '线索或结局说明缺失' };
  }
  const actionIds: string[] = [];
  for (let index: number = 0; index < story.nodes.length; index++) {
    const item: StoryNode = story.nodes[index];
    if (typeof item.title !== 'string' || typeof item.text !== 'string' || typeof item.chapterId !== 'string' ||
      typeof item.speaker !== 'string' || typeof item.puzzleId !== 'string' ||
      ['normal', 'puzzle', 'summary', 'ending'].indexOf(item.kind) < 0 || !Array.isArray(item.choices) ||
      (item.kind !== 'ending' && item.choices.length === 0) ||
      (item.kind === 'puzzle' && puzzleIds.indexOf(item.puzzleId) < 0)) {
      return { ok: false, error: '剧情节点内容或出口无效：' + item.id };
    }
    for (let actionIndex: number = 0; actionIndex < item.choices.length; actionIndex++) {
      const action: Choice = item.choices[actionIndex];
      if (action === null || typeof action !== 'object' || typeof action.id !== 'string' || !action.id ||
        typeof action.text !== 'string' || typeof action.once !== 'boolean' || !Number.isInteger(action.cost) ||
        action.cost < 0 || action.cost > 18 || nodeIds.indexOf(action.targetNodeId) < 0 ||
        !Array.isArray(action.effects) || !checkConditions(action.conditions, story) ||
        ['move', 'submit', 'stop'].indexOf(action.behavior) < 0 ||
        (action.behavior !== 'move' && (item.kind !== 'summary' || action.cost !== 0))) {
        return { ok: false, error: '剧情选项、目标或条件无效：' + item.id };
      }
      actionIds.push(action.id);
      for (let effectIndex: number = 0; effectIndex < action.effects.length; effectIndex++) {
        const change: Effect = action.effects[effectIndex];
        if (change === null || typeof change !== 'object' || typeof change.key !== 'string' || !Number.isInteger(change.value) ||
          !((change.kind === 'trust' && Math.abs(change.value) <= 100) ||
            (change.kind === 'clue' && clueIds.indexOf(change.key) >= 0) ||
            (change.kind === 'flag' && story.flagIds.indexOf(change.key) >= 0))) {
          return { ok: false, error: '非法剧情效果：' + action.id };
        }
        if (!action.once) {
          return { ok: false, error: '带奖励的动作必须为一次性：' + action.id };
        }
      }
    }
  }
  if (!unique(actionIds)) {
    return { ok: false, error: '剧情动作ID重复' };
  }
  for (let index: number = 0; index < story.puzzles.length; index++) {
    const puzzle: Puzzle = story.puzzles[index];
    if (['P01', 'P02'].indexOf(puzzle.id) < 0 || typeof puzzle.title !== 'string' || typeof puzzle.hint !== 'string' ||
      typeof puzzle.answer !== 'string' || typeof puzzle.order !== 'string' || puzzle.cost !== 1 ||
      clueIds.indexOf(puzzle.rewardClueId) < 0 || nodeIds.indexOf(puzzle.targetNodeId) < 0 || !checkConditions(puzzle.conditions, story)) {
      return { ok: false, error: '谜题配置无效：' + puzzle.id };
    }
  }
  if (!['E01', 'E02', 'E03', 'E04'].every((id: string): boolean => endingIds.indexOf(id) >= 0 &&
    story.nodes.some((item: StoryNode): boolean => item.id === id && item.kind === 'ending'))) {
    return { ok: false, error: '缺少结局配置' };
  }
  return { ok: true, error: '' };
}
