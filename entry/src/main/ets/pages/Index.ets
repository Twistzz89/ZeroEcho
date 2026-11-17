import { Session } from '../common/Session';
import { createStory } from '../data/StoryRepository';
import { SlotInfo } from '../data/SaveRepository';
import { GameViewModel } from '../viewmodels/GameViewModel';
import { GameEngine } from '../domain/GameEngine';
import { evaluateConditions } from '../domain/ConditionEvaluator';
import { explainEnding } from '../domain/EndingResolver';
import {
  GameState, GameAction, StoryDefinition, StoryNode, Puzzle, ChoiceViewModel,
  Clue, Ending, HistoryEntry, cloneState
} from '../models/Models';
import { StatusBar } from '../components/StatusBar';
import { ChoiceButton } from '../components/ChoiceButton';
import { ClueCard } from '../components/ClueCard';
import { SaveSlotCard } from '../components/SaveSlotCard';

@Entry
@Component
struct Index {
  private paths: NavPathStack = new NavPathStack();
  private story: StoryDefinition = createStory();
  private engine: GameEngine = new GameEngine(this.story);
  private vm: GameViewModel | undefined = Session.vm;
  private lastAction: GameAction | undefined = undefined;
  @State game: GameState = new GameState();
  @State ready: boolean = false;
  @State busy: boolean = true;
  @State hasGame: boolean = false;
  @State errorText: string = '';
  @State notice: string = '';
  @State slots: SlotInfo[] = [];
  @State unlockedEndings: string[] = [];
  @State largeText: boolean = false;
  @State expandedClue: string = '';
  @State answer: string = '';
  @State order: string = '';
  @State retryAction: boolean = false;

  aboutToAppear(): void {
    this.initialize();
  }

  private sync(): void {
    const controller = this.vm;
    if (controller === undefined) {
      this.busy = false;
      this.errorText = '应用初始化失败，请关闭并重新打开应用。';
      return;
    }
    this.game = cloneState(controller.state);
    this.ready = controller.ready;
    this.busy = controller.busy;
    this.hasGame = controller.hasGame;
    this.errorText = controller.error;
    this.notice = controller.message;
    this.slots = controller.slots.slice();
    this.unlockedEndings = controller.profile.unlockedEndingIds.slice();
    this.largeText = controller.profile.largeText;
  }

  private async initialize(): Promise<void> {
    const controller = this.vm;
    if (controller === undefined) {
      this.sync();
      return;
    }
    this.busy = true;
    try {
      await controller.initialize();
    } catch {
      this.errorText = '读取失败，请重试。原有存档未被清空。';
      this.busy = false;
      return;
    }
    this.sync();
  }

  private async execute(operation: () => Promise<void>): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      await operation();
    } catch {
      this.errorText = '操作未能完成，请重试。';
      this.busy = false;
      return;
    }
    this.sync();
  }

  private open(name: string): void {
    this.paths.pushPathByName(name, '');
  }

  private openGame(): void {
    if (this.hasGame && this.ready && !this.busy) {
      this.open('explore');
    }
  }

  private confirmNewGame(): void {
    if (this.busy || !this.ready) {
      return;
    }
    const auto = this.slots.find((item: SlotInfo) => item.id === 'auto');
    if (this.hasGame || (auto !== undefined && auto.status !== 'empty')) {
      AlertDialog.show({
        title: '开始新调查',
        message: '自动进度将被新游戏替换。手动存档与已解锁结局会保留。需要保留当前路线时，请先存入手动槽。',
        primaryButton: { value: '取消', action: () => {} },
        secondaryButton: { value: '开始新游戏', action: () => { this.startGame(); } }
      });
    } else {
      this.startGame();
    }
  }

  private async startGame(): Promise<void> {
    const controller = this.vm;
    if (controller === undefined) { return; }
    await this.execute(async () => { await controller.newGame(); });
    if (this.hasGame && this.errorText.length === 0) {
      this.answer = '';
      this.order = '';
      this.retryAction = false;
      this.lastAction = undefined;
      this.paths.clear();
      this.open('explore');
    }
  }

  private async choose(action: GameAction): Promise<void> {
    const controller = this.vm;
    if (controller === undefined || this.busy || !this.ready) { return; }
    this.lastAction = action;
    await this.execute(async () => { await controller.act(action); });
    this.retryAction = this.errorText.length > 0 && this.game.revision === action.expectedRevision;
    if (this.game.revision !== action.expectedRevision) {
      this.answer = '';
      this.order = '';
      this.lastAction = undefined;
      this.retryAction = false;
    }
  }

  private chooseOption(view: ChoiceViewModel): void {
    const action: GameAction = {
      kind: 'choice', nodeId: this.game.currentNodeId, id: view.choice.id,
      expectedRevision: this.game.revision, answer: '', order: ''
    };
    this.choose(action);
  }

  private submitPuzzle(puzzle: Puzzle): void {
    const action: GameAction = {
      kind: 'puzzle', nodeId: this.game.currentNodeId, id: puzzle.id,
      expectedRevision: this.game.revision, answer: this.answer, order: this.order
    };
    this.choose(action);
  }

  private retryLastAction(): void {
    const action = this.lastAction;
    if (action !== undefined) {
      this.choose(action);
    }
  }

  private save(slot: SlotInfo): void {
    const controller = this.vm;
    if (controller === undefined || this.busy) { return; }
    if (slot.status !== 'empty') {
      AlertDialog.show({
        title: '覆盖手动存档 ' + slot.id,
        message: '仅替换这个槽位，其他存档与结局图鉴保持不变。',
        primaryButton: { value: '取消', action: () => {} },
        secondaryButton: {
          value: '确认覆盖',
          action: () => { this.execute(async () => { await controller.saveManual(slot.id, true); }); }
        }
      });
    } else {
      this.execute(async () => { await controller.saveManual(slot.id, false); });
    }
  }

  private confirmLoad(slot: SlotInfo, recover: boolean): void {
    AlertDialog.show({
      title: recover ? '恢复有效副本' : '读取存档',
      message: '这会将自动进度切换为所选存档。本局历史与资源将一同恢复，不会重新发放奖励。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '读取', action: () => { this.load(slot.id, recover); } }
    });
  }

  private async load(slotId: string, recover: boolean): Promise<void> {
    const controller = this.vm;
    if (controller === undefined) { return; }
    await this.execute(async () => { await controller.loadSlot(slotId, recover); });
    if (this.errorText.length === 0 && this.hasGame) {
      this.answer = '';
      this.order = '';
      this.retryAction = false;
      this.lastAction = undefined;
      this.open('explore');
    }
  }

  private confirmDelete(slot: SlotInfo): void {
    const controller = this.vm;
    if (controller === undefined) { return; }
    AlertDialog.show({
      title: '删除手动存档 ' + slot.id,
      message: '此槽位及其恢复副本将被删除。自动进度、其他手动档和图鉴不受影响。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        action: () => { this.execute(async () => { await controller.deleteSlot(slot.id); }); }
      }
    });
  }

  private confirmReset(): void {
    AlertDialog.show({
      title: '清空全部数据',
      message: '将删除全部存档、恢复副本、结局图鉴和设置，无法撤销。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '继续确认', action: () => {
          AlertDialog.show({
            title: '最后确认', message: '确定永久清空《零点回声》的全部本地数据？',
            primaryButton: { value: '保留数据', action: () => {} },
            secondaryButton: { value: '清空全部', action: () => { this.reset(); } }
          });
        }
      }
    });
  }

  private async reset(): Promise<void> {
    const controller = this.vm;
    if (controller === undefined) { return; }
    await this.execute(async () => { await controller.resetAll(); });
    if (this.errorText.length === 0) {
      this.paths.clear();
      this.retryAction = false;
      this.lastAction = undefined;
      this.answer = '';
      this.order = '';
    }
  }

  private setTextSize(value: boolean): void {
    const controller = this.vm;
    if (controller === undefined) { return; }
    this.execute(async () => { await controller.setLargeText(value); });
  }

  private node(): StoryNode | undefined { return this.engine.getNode(this.game.currentNodeId); }
  private nodeTitle(id: string): string {
    const node = this.engine.getNode(id);
    return node === undefined ? id : node.title;
  }
  private chapterTitle(): string {
    const node = this.node();
    if (node === undefined) { return '等待调查'; }
    if (this.game.endingId.length > 0) { return '调查结案'; }
    return node.chapterId;
  }
  private puzzle(): Puzzle | undefined {
    const node = this.node();
    if (node === undefined) { return undefined; }
    return this.story.puzzles.find((item: Puzzle) => item.id === node.puzzleId);
  }
  private choices(): ChoiceViewModel[] {
    return this.hasGame ? this.engine.getAvailableChoices(this.game) : [];
  }
  private puzzleReason(puzzle: Puzzle): string {
    return evaluateConditions(puzzle.conditions, this.game).reason;
  }
  private puzzleEnabled(puzzle: Puzzle): boolean {
    return this.ready && !this.busy && evaluateConditions(puzzle.conditions, this.game).ok &&
      this.game.solvedPuzzleIds.indexOf(puzzle.id) < 0 && this.game.remainingActions >= puzzle.cost;
  }
  private endingTitle(): string {
    const ending = this.story.endings.find((item: Ending) => item.id === this.game.endingId);
    return ending === undefined ? '调查结果' : ending.title;
  }
  private endingText(): string {
    const ending = this.story.endings.find((item: Ending) => item.id === this.game.endingId);
    return ending === undefined ? '' : ending.text;
  }
  private slotStatus(slot: SlotInfo): string {
    if (slot.status === 'valid') { return '可读取'; }
    if (slot.status === 'empty') { return '空槽位'; }
    if (slot.status === 'incompatible') { return '版本不兼容'; }
    if (slot.status === 'corrupt') { return '数据损坏'; }
    return '读取失败';
  }
  private slotDescription(slot: SlotInfo): string {
    if (slot.status !== 'valid') {
      return slot.recoverable ? '检测到经过校验的恢复副本，可选择恢复。' :
        slot.status === 'empty' ? '尚未保存进度。' : '该记录暂不可载入，原始数据保留。';
    }
    return this.nodeTitle(slot.nodeId) + ' · 已记录 ' + slot.revision.toString() + ' 步行动\n' +
      new Date(slot.savedAt).toLocaleString();
  }
  private historySummary(item: HistoryEntry): string {
    let value = '机会 −' + item.cost.toString();
    if (item.trustDelta !== 0) {
      value += '  ·  信任 ' + (item.trustDelta > 0 ? '+' : '') + item.trustDelta.toString();
    }
    if (item.clueIds.length > 0) { value += '  ·  取得 ' + item.clueIds.join('、'); }
    return value;
  }

  @Builder
  feedback() {
    if (this.busy) {
      Row({ space: 10 }) {
        LoadingProgress().width(20).height(20).color('#6EE3D2')
        Text('正在读取或保存，请稍候…').fontSize(14).fontColor('#AFD8D3')
      }.width('100%').padding({ top: 8, bottom: 8 })
    }
    if (this.errorText.length > 0) {
      Column({ space: 10 }) {
        Text(this.errorText).fontSize(15).lineHeight(24).fontColor('#F4BB69').width('100%')
        if (this.retryAction) {
          Button('重试上一步').backgroundColor('#384438').fontColor('#F4BB69')
            .enabled(!this.busy).onClick(() => this.retryLastAction())
        }
        Button('重新载入存档状态').fontSize(14).backgroundColor('#29414D').fontColor('#E8F1F5')
          .enabled(!this.busy).onClick(() => this.initialize())
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 8, bottom: 8 })
    } else if (this.notice.length > 0) {
      Text(this.notice).fontSize(14).lineHeight(22).fontColor('#7CD6CA').width('100%')
    }
  }

  @Builder
  pageHeader(title: string, subtitle: string) {
    Row({ space: 16 }) {
      Button('‹ 返回').fontSize(15).fontColor('#6EE3D2').backgroundColor('#172733')
        .onClick(() => { this.paths.pop(); })
      Blank()
      Button('首页').fontSize(14).fontColor('#9CACBB').backgroundColor('#172733')
        .onClick(() => this.paths.clear())
    }.width('100%').margin({ bottom: 14 })
    Text(title).fontSize(29).fontWeight(FontWeight.Bold).fontColor('#F2F7FA').width('100%')
    Text(subtitle).fontSize(14).lineHeight(22).fontColor('#9CACBB').width('100%')
    this.feedback()
  }

  @Builder
  shortcut(label: string, detail: string, destination: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Text(label).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#E8F1F5')
          Text(detail).fontSize(13).fontColor('#9CACBB')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text('›').fontSize(28).fontColor('#6EE3D2')
      }.width('100%').padding(18)
    }.width('100%').height('auto').backgroundColor('#172733').borderRadius(14)
      .enabled(!this.busy).onClick(() => this.open(destination))
  }

  @Builder
  home() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Text('ZERO ECHO').fontSize(12).letterSpacing(4).fontColor('#6EE3D2').fontWeight(FontWeight.Bold)
          Blank()
          Text('离线调查档案').fontSize(12).fontColor('#879BAB')
        }.width('100%').margin({ top: 20, bottom: 18 })
        Text('零点回声').fontSize(44).fontWeight(FontWeight.Bold).fontColor('#F2F7FA').width('100%')
        Text('校园信号疑云').fontSize(20).fontColor('#B9CBD6').width('100%')
        Column({ space: 12 }) {
          Text('00:00').fontSize(62).fontWeight(FontWeight.Lighter).fontColor('#6EE3D2').width('100%')
          Text('信号重现，记录却悄然回滚。\n在有限的调查机会里，找到被时间错位掩盖的真相。')
            .fontSize(this.largeText ? 20 : 16).lineHeight(this.largeText ? 30 : 26)
            .fontColor('#C9D6DE').width('100%')
          Text('三章故事  /  六条线索  /  四种结局').fontSize(12).fontColor('#839EAE').width('100%')
        }.width('100%').padding(22).backgroundColor('#142936').borderRadius(20)
          .margin({ top: 8, bottom: 4 }).alignItems(HorizontalAlign.Start)
        this.feedback()
        if (this.hasGame) {
          Text('当前进度  ·  ' + this.nodeTitle(this.game.currentNodeId)).fontSize(14).fontColor('#9CACBB').width('100%')
        }
        Button(this.game.endingId.length > 0 ? '查看本局结果' : '继续调查')
          .id('continue-game')
          .width('100%').height(54).fontSize(18).fontWeight(FontWeight.Bold)
          .backgroundColor('#6EE3D2').fontColor('#10252C')
          .enabled(this.ready && this.hasGame && !this.busy).onClick(() => this.openGame())
        Button('开始新游戏').id('new-game').width('100%').height(50).fontSize(17)
          .backgroundColor('#223C48').fontColor('#E8F1F5')
          .enabled(this.ready && !this.busy).onClick(() => this.confirmNewGame())
        this.shortcut('线索档案', '检视本局已收集的记录', 'archive')
        this.shortcut('存档管理', '自动进度与三个手动槽位', 'saves')
        this.shortcut('结局图鉴', this.unlockedEndings.length.toString() + ' / 4 已解锁', 'gallery')
        this.shortcut('设置与说明', '阅读字号、操作规则与数据管理', 'settings')
        Text('所有角色、学校与事件均为虚构。').fontSize(12).fontColor('#728B9B').margin({ top: 8, bottom: 20 })
      }.width('100%').padding({ left: 22, right: 22, top: 16, bottom: 24 })
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  puzzleForm(puzzle: Puzzle) {
    Column({ space: 12 }) {
      Text(puzzle.title).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#E8F1F5').width('100%')
      Text(puzzle.hint).fontSize(this.largeText ? 19 : 15).lineHeight(this.largeText ? 28 : 24)
        .fontColor('#B8CBD5').width('100%')
      if (this.game.solvedPuzzleIds.indexOf(puzzle.id) >= 0) {
        Text('此谜题已完成，线索已收入档案，无需再次提交。')
          .fontSize(15).lineHeight(24).fontColor('#6EE3D2').width('100%')
      }
      TextInput({ text: this.answer, placeholder: puzzle.id === 'P01' ? '输入四位档案编号' : '输入标准时间，例如 HH:MM' })
        .id('puzzle-answer')
        .fontSize(20).height(54).backgroundColor('#0E202B').fontColor('#E8F1F5').placeholderColor('#7F98A9')
        .maxLength(12).onChange((value: string) => { this.answer = value; })
      if (puzzle.id === 'P02') {
        Text('判断事件顺序').fontSize(14).fontColor('#9CACBB').width('100%')
        Button('任务先发生，人员后进入').width('100%').fontSize(15)
          .backgroundColor(this.order === 'task-first' ? '#406C70' : '#263D49').fontColor('#E8F1F5')
          .onClick(() => { this.order = 'task-first'; })
        Button('人员先进入，任务后发生').width('100%').fontSize(15)
          .backgroundColor(this.order === 'person-first' ? '#406C70' : '#263D49').fontColor('#E8F1F5')
          .onClick(() => { this.order = 'person-first'; })
      }
      if (this.puzzleReason(puzzle).length > 0) {
        Text(this.puzzleReason(puzzle)).fontSize(14).fontColor('#E2B978').width('100%')
      }
      Text('合法答案每次消耗 ' + puzzle.cost.toString() + ' 次机会；格式错误不扣费。提示免费，可先退出查看档案。')
        .fontSize(13).lineHeight(21).fontColor('#96AFBD').width('100%')
      Button('提交答案  −' + puzzle.cost.toString() + ' 次').width('100%').height(48)
        .id('puzzle-submit')
        .backgroundColor('#6EE3D2').fontColor('#10252C').fontSize(17)
        .enabled(this.puzzleEnabled(puzzle)).onClick(() => this.submitPuzzle(puzzle))
    }.width('100%').padding(18).alignItems(HorizontalAlign.Start).backgroundColor('#172E3B').borderRadius(16)
  }

  @Builder
  endingResult() {
    Text(this.game.endingId + '  /  调查已结束').fontSize(13).fontColor('#6EE3D2').width('100%')
    Text(this.endingTitle()).fontSize(31).fontWeight(FontWeight.Bold).fontColor('#F2F7FA').width('100%')
    Text(this.endingText()).fontSize(this.largeText ? 21 : 17).lineHeight(this.largeText ? 32 : 28)
      .fontColor('#C9D6DE').width('100%')
    Text('达成依据').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#E8F1F5').width('100%').margin({ top: 12 })
    ForEach(explainEnding(this.game), (reason: string) => {
      Text('· ' + reason).fontSize(this.largeText ? 19 : 15).lineHeight(this.largeText ? 29 : 24)
        .fontColor('#AFC5D1').width('100%')
    }, (reason: string) => reason)
    Button('回顾本局决策').width('100%').height(48).fontColor('#10252C').backgroundColor('#6EE3D2')
      .onClick(() => this.open('history'))
    Button('开始新的调查').width('100%').height(48).fontColor('#E8F1F5').backgroundColor('#29414D')
      .enabled(this.ready && !this.busy).onClick(() => this.confirmNewGame())
  }

  @Builder
  explore() {
    this.pageHeader('调查现场', this.chapterTitle())
    if (!this.hasGame) {
      Text('尚无可用进度，请返回首页开始新游戏。').fontSize(17).fontColor('#B9CBD6')
    } else {
      StatusBar({ remaining: this.game.remainingActions, trust: this.game.trust, clueCount: this.game.clueIds.length })
      Row({ space: 10 }) {
        Button('档案').fontColor('#BFE7E0').backgroundColor('#223C48').layoutWeight(1).onClick(() => this.open('archive'))
        Button('回顾').fontColor('#BFE7E0').backgroundColor('#223C48').layoutWeight(1).onClick(() => this.open('history'))
        Button('存档').fontColor('#BFE7E0').backgroundColor('#223C48').layoutWeight(1).onClick(() => this.open('saves'))
      }.width('100%')
      if (this.game.endingId.length > 0) {
        this.endingResult()
      } else if (this.node() !== undefined) {
        Text(this.node()!.title).fontSize(27).fontWeight(FontWeight.Bold).fontColor('#F2F7FA').width('100%').margin({ top: 10 })
        Text(this.node()!.speaker).fontSize(13).fontColor('#6EE3D2').width('100%')
        Text(this.node()!.text).fontSize(this.largeText ? 22 : 18).lineHeight(this.largeText ? 34 : 30)
          .fontColor('#CCD9E1').width('100%').margin({ bottom: 10 })
        if (this.puzzle() !== undefined) {
          this.puzzleForm(this.puzzle()!)
        }
        ForEach(this.choices(), (view: ChoiceViewModel) => {
          ChoiceButton({
            controlId: 'choice-' + view.choice.id,
            label: view.choice.text, cost: view.choice.cost, available: view.enabled,
            reason: view.disabledReason, busy: this.busy || !this.ready,
            onChoose: () => this.chooseOption(view)
          })
        }, (view: ChoiceViewModel) => view.choice.id + ':' + this.game.revision.toString())
        Text('阅读、查看档案与返回不消耗机会。').fontSize(12).fontColor('#8199A8').width('100%')
      }
    }
  }

  @Builder
  archive() {
    this.pageHeader('线索档案', '已取得 ' + this.game.clueIds.length.toString() + ' / 6 条 · 点击卡片查看详情')
    ForEach(this.story.clues, (clue: Clue) => {
      ClueCard({
        code: clue.id, titleText: clue.title, category: clue.category, contentText: clue.text,
        unlocked: this.game.clueIds.indexOf(clue.id) >= 0, expanded: this.expandedClue === clue.id,
        largeText: this.largeText,
        onOpen: () => { this.expandedClue = this.expandedClue === clue.id ? '' : clue.id; }
      })
    }, (clue: Clue) => clue.id)
  }

  @Builder
  history() {
    this.pageHeader('决策回顾', '只记录实际完成的行动。当前位置：' + this.nodeTitle(this.game.currentNodeId))
    if (this.game.history.length === 0) {
      Text('还没有决策记录。开始调查后，你的选择与状态变化会出现在这里。')
        .fontSize(17).lineHeight(28).fontColor('#AFC5D1')
    }
    ForEach(this.game.history, (item: HistoryEntry) => {
      Column({ space: 9 }) {
        Text('#' + item.sequence.toString() + '  ' + item.actionText).fontSize(this.largeText ? 21 : 17)
          .fontWeight(FontWeight.Medium).fontColor('#E8F1F5').width('100%')
        Text(this.nodeTitle(item.fromNodeId) + ' → ' + this.nodeTitle(item.toNodeId))
          .fontSize(13).fontColor('#96AFBD').width('100%')
        Text(this.historySummary(item)).fontSize(14).lineHeight(22).fontColor('#6EE3D2').width('100%')
        Text(item.message).fontSize(this.largeText ? 18 : 14).lineHeight(24).fontColor('#B6C9D4').width('100%')
      }.width('100%').padding(18).backgroundColor('#172733').borderRadius(14)
        .border({ width: 1, color: item.sequence === this.game.revision ? '#5BA9A6' : '#283E4B' })
    }, (item: HistoryEntry) => item.sequence.toString())
  }

  @Builder
  saves() {
    this.pageHeader('存档管理', '每次有效行动后自动保存。手动存档用于保留不同路线。')
    ForEach(this.slots, (slot: SlotInfo) => {
      SaveSlotCard({
        titleText: slot.id === 'auto' ? '自动进度' : '手动存档 ' + slot.id,
        description: this.slotDescription(slot), statusText: this.slotStatus(slot), automatic: slot.id === 'auto',
        canLoad: slot.status === 'valid', canSave: this.ready && this.hasGame,
        canDelete: slot.status !== 'empty', recoverable: slot.recoverable, busy: this.busy,
        onSave: () => this.save(slot), onLoad: () => this.confirmLoad(slot, false),
        onDelete: () => this.confirmDelete(slot), onRecover: () => this.confirmLoad(slot, true)
      })
    }, (slot: SlotInfo) => slot.id)
    if (this.slots.length === 0) {
      Text('尚未读取存档信息，可返回首页重试。').fontSize(16).fontColor('#AFC5D1')
    }
  }

  @Builder
  gallery() {
    this.pageHeader('结局图鉴', this.unlockedEndings.length.toString() + ' / 4 已解锁 · 开始新游戏会保留记录')
    ForEach(this.story.endings, (ending: Ending) => {
      Column({ space: 12 }) {
        Text(ending.id).fontSize(13).fontColor('#6EE3D2').width('100%')
        Text(this.unlockedEndings.indexOf(ending.id) >= 0 ? ending.title : '未解锁结局')
          .fontSize(this.largeText ? 24 : 21).fontWeight(FontWeight.Bold).fontColor('#E8F1F5').width('100%')
        Text(this.unlockedEndings.indexOf(ending.id) >= 0 ? ending.text : '不同的证据、信任与决策，会让调查走向不同结果。')
          .fontSize(this.largeText ? 20 : 16).lineHeight(this.largeText ? 30 : 26).fontColor('#B9CBD6').width('100%')
      }.width('100%').padding(20).backgroundColor('#172733').borderRadius(16)
    }, (ending: Ending) => ending.id)
  }

  @Builder
  settings() {
    this.pageHeader('设置与说明', '阅读偏好与本地数据管理')
    Row({ space: 14 }) {
      Column({ space: 6 }) {
        Text('大字号阅读').fontSize(19).fontColor('#E8F1F5')
        Text('调整剧情和档案正文大小').fontSize(13).fontColor('#9CACBB')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.largeText }).selectedColor('#58B8AD')
        .enabled(this.ready && !this.busy).onChange((value: boolean) => this.setTextSize(value))
    }.width('100%').padding(18).backgroundColor('#172733').borderRadius(14)
    Text('操作规则').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#E8F1F5').width('100%').margin({ top: 10 })
    Text('调查机会按有效行动扣除，不按现实时间倒计时。按钮标明成本；阅读、查看档案和普通返回免费。谜题格式无效不扣费，格式正确但答案错误会消耗一次机会。')
      .fontSize(this.largeText ? 20 : 16).lineHeight(this.largeText ? 30 : 26).fontColor('#BDCED8').width('100%')
    Text('机会耗尽会立刻结束调查。提交最终结论不扣机会，结果取决于证据和同伴信任。结局后可以回顾、读档或新开一局。')
      .fontSize(this.largeText ? 20 : 16).lineHeight(this.largeText ? 30 : 26).fontColor('#BDCED8').width('100%')
    Text('保存与恢复').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#E8F1F5').width('100%').margin({ top: 10 })
    Text('操作完成并保存成功后，界面才更新。出现保存错误时可重试同一行动。读取存档会恢复完整业务状态；手动存档不会因新游戏而删除。应用无需网络即可完成调查。')
      .fontSize(this.largeText ? 20 : 16).lineHeight(this.largeText ? 30 : 26).fontColor('#BDCED8').width('100%')
    Button('清空全部本地数据').width('100%').height(50).fontColor('#F0B08B').backgroundColor('#3B2D2D')
      .enabled(!this.busy).onClick(() => this.confirmReset()).margin({ top: 16 })
    Text('零点回声：校园信号疑云\n移动应用开发基础 · 主题一\n卢广阔 · 使用 Codex 辅助开发')
      .fontSize(13).lineHeight(23).fontColor('#829BAA').width('100%').margin({ top: 16 })
  }

  @Builder
  destination(name: string) {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          if (name === 'explore') { this.explore() }
          else if (name === 'archive') { this.archive() }
          else if (name === 'history') { this.history() }
          else if (name === 'saves') { this.saves() }
          else if (name === 'gallery') { this.gallery() }
          else if (name === 'settings') { this.settings() }
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ left: 22, right: 22, top: 20, bottom: 36 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
    }.hideTitleBar(true).backgroundColor('#0D1B25')
  }

  build() {
    Navigation(this.paths) {
      this.home()
    }.hideTitleBar(true).mode(NavigationMode.Stack).navDestination(this.destination)
      .width('100%').height('100%').backgroundColor('#0D1B25')
  }
}
