# 零点回声软件需求说明书

版本 1.0，2026 年 11 月 18 日本地验收版。最初的 0.1 需求说明于业务编码前建立，Git 提交 3b10881 保留原文。下表的“初始状态”保留当时记录，末尾列出现行验收结果。

## 背景与范围

《零点回声：校园信号疑云》是移动应用开发基础主题一的 HarmonyOS 原生离线应用。用户扮演虚构校园实验室成员，通过调查、沟通、谜题校准和提交证据，解释零点发生的数据回滚事件。核心规则实际执行，不依赖联网服务。方案目标为三章、六条线索、两个谜题、四个结局、一个自动档与三个手动档；节点数量服从完整流程，不机械凑数。

## 需求及验收

|编号|需求|验收|初始状态|
|---|---|---|---|
|FR01|新游戏与继续游戏|18次机会、50信任、空线索；启动读取完成前禁止操作|待实现|
|FR02|条件分支和状态迁移|all/any、信任、线索、谜题、标记和成本条件；过期revision拒绝；至少两处分支有效|待实现|
|FR03|线索档案|六条线索，重复获取无扣费或奖励，未取得不剧透|待实现|
|FR04|两个谜题|0417保留前导零；00:00与task-first组合；无效格式不扣费，合法错误扣1|待实现|
|FR05|四结局与图鉴|E03耗尽优先；总结节点才判E01/E02/E04；每个结局有从起点的合法路径|待实现|
|FR06|自动档与手动档|动作保存成功才提交UI状态；3个手动槽，覆盖/删除确认，串行保存与有效备份|待实现|
|FR07|恢复及错误处理|验证版本、字段、范围和引用；损坏提示；关闭进程后完整状态一致|待实现|
|FR08|原生页面及交互|首页、探索、档案、回顾、存档、结局图鉴、设置可达；统一V1状态与Navigation|待实现|
|FR09|测试与证据|正常、边界、异常测试；Mock存储失败；真实构建、设备操作及重启证据|待实现|
|FR10|交付与贡献|README、真实贡献、录屏及基于证据的模板个人报告|待实现|

## 架构和接口

页面和可复用组件 → GameViewModel → GameEngine → ConditionEvaluator / PuzzleService / EndingResolver / StoryRepository。
GameViewModel → SaveRepository → TextStore → HarmonyOS应用沙箱文件。Profile与游戏槽逻辑独立。时间通过Clock接口注入。

数据源为只读强类型StoryDefinition；GameState保存currentNodeId、remainingActions、trust、clueIds、solvedPuzzleIds、flags、usedActionIds、attempts、history、endingId、revision。GameAction带nodeId、id、kind、expectedRevision及答案和事件顺序。失败返回原状态和明确错误；成功返回独立副本，不在原对象上扣费。

存档SaveEnvelope具有schemaVersion、contentVersion、slotId、savedAt和state。存档不包含剧情全文或图片。使用沙箱JSON文件，临时文件写入/同步/替换主文件，并保留最近经过验证的副本；不使用Preferences多键写入冒充事务。存档体积通过实际测试测量。所有写入由ViewModel忙碌锁与Repository队列协调，启动/加载/保存失败时阻止进一步剧情推进。删除槽不清空其他槽或图鉴。Profile存储结局和字体设置，新游戏保留Profile，清空全部须确认。

## 核心规则

初始18机会、50信任，信任限制0—100。每个动作声明非负整数成本。有效选择与谜题提交后revision加1，历史记录起终点和实际变化；免费阅读与菜单不改变业务状态。一次性动作禁止重复奖励。结局后的本局只读。

谜题一需要CL01，正确字符串0417取得CL02。谜题二需要CL03和CL04，正确标准时间00:00且任务先于人员取得CL06。错误合法答案消耗1次；空白、格式非法不消耗。

结局优先级：任何有效动作使机会为0立即E03；总结节点提交且机会>0、CL02/CL05/CL06齐、P01/P02完成、信任≥60为E01；有CL02/CL05且P01完成为E02；总结节点主动结束或证据不足为E04。提交/结束成本0，不能在普通节点默认触发E04。

## 非功能要求

API以实际安装的HarmonyOS 5.0.5(API17)兼容环境为基线；严格ArkTS语法、原生ArkUI V1状态管理及Navigation。交互显示成本、禁用原因、加载/忙碌/空档/失败反馈，中文清晰可读。核心离线；不记录凭据；不依赖退出回调保存。完整设备流程与进程重启为独立验收，不以桌面逻辑测试替代。

## 分工与未知项

独立项目，卢广阔负责整体工程，无组员。GitHub 为 Twistzz89，目标仓库为 Twistzz89/ZeroEcho。Codex 辅助编写、调试、测试和整理文档。远程同步、教师访问和学习通提交待本人完成。电子提交时间待本人核实。

## 追溯约定

需求编号 → 模块和接口 → 测试编号 → 证据路径 → 真实个人Commit。未执行项保留“待执行”。最终开发状态记录docs/progress.md，测试实测记录docs/test-results.md。

## 本地验收对照

|需求|实现与接口|复核记录|提交|
|---|---|---|---|
|FR01、FR02|GameViewModel.newGame、GameEngine.dispatch、ConditionEvaluator|T01、T02、T09、T14、S30、S31；两条信任路线实录|cdf611d、a2c0082|
|FR03、FR04|StoryRepository、ClueCard、PuzzleService.checkPuzzle|T03、T04、T13、T16、T17；设备档案、错答及时间线截图|cdf611d、a2c0082|
|FR05|EndingResolver、Profile|T05、T06、T08、T11、T23；E01、E02 设备结果及图鉴|cdf611d、a2c0082|
|FR06、FR07|SaveRepository、FileTextStore、StateValidator、启动错误页|T07 两次设备重启；T19—T22、S26、S39—S44；设备槽 3 显式副本恢复|cdf611d、7031d77、a2c0082|
|FR08|Index、StatusBar、ChoiceButton、ClueCard、SaveSlotCard|7 个入口实测可达，状态栏与存档值一致，字号可保存|cdf611d、c45f8ba|
|FR09|entry/src/test、构建脚本、设备记录|43/43，干净检出复测，交付 HAP 已覆盖安装并启动|a2c0082 及后续验收提交|
|FR10|README、演示视频、本地 Git 历史、教师模板报告|本地交付完成；GitHub 推送、教师访问及实际课程提交待办|见实际 Git 历史|

入口：[模块测试](test-results.md) · [设备验收](device-acceptance.md) · [贡献记录](contributions.md) · [录屏](evidence/zero-echo-demo.mp4)。
