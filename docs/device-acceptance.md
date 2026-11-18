# API17 模拟器运行与存档验收

2026 年 11 月 17—18 日，Huawei_Phone 手机模拟器运行包 com.twistzz89.zeroecho，入口 EntryAbility。设备分辨率 1260 × 2720。以下状态均从界面实际操作后读取，截图保留设备原始画面。[完整操作记录](evidence/device-run.jsonl)

|操作|观察结果|证据|
|---|---|---|
|按成本调查及解谜|取得笔记后剩余 16 次机会。合法错答 1111 后剩余 15 次，无 CL02。正确的 0417 取得访问记录。|[错答反馈](screenshots/04-wrong-puzzle.png) · [笔记详情](screenshots/15-clue-detail.png)|
|信任改变后续选项|信任 50 时协助入口锁定。取得网关日志 CL04 后能独立访问任务配置。最后剩余 12 次、信任 50，得到 E02。|[协助锁定](screenshots/16-locked-choice.png) · [配置锁定](screenshots/17-locked-config.png) · [独自调查结局](screenshots/18-solo-ending.png)|
|校正时钟|信任 60，取得 CL03、CL04 后输入 00:00，选择任务先发生。得到 CL06 并进入最终报告。|[时间线工作台](screenshots/09-timeline.png)|
|同一存档对比|手动槽 1 在 N08，机会 11、信任 60、4 条线索、13 步历史。补配置并解 P02 得 E01（9、60、6），只补配置得 E02（10、60、5）。两个结局都进入图鉴。|[E01](screenshots/10-ending-e01.png) · [E02](screenshots/13-ending-e02.png) · [图鉴](screenshots/14-gallery.png)|
|只读页面|档案展示已取得的线索，回顾展示每次实际动作。进入、返回后保存的业务版本保持原值。|[档案](screenshots/11-clues.png) · [回顾](screenshots/12-history.png)|
|手动档与异常|向空槽 3 正常保存并确认覆盖，得到经验证的副本。只向该测试槽的主文件写入一个截断字符，重新启动后出现恢复入口。确认恢复后，完整状态等于副本。取消删除保留数据，确认删除写入双删除标记。槽 1、2 逐字段未变。|[恢复入口](screenshots/19-recover-slot.png) · [逐项检查](evidence/device-slot-checks.json)|
|个人设置|切换大字号后读取设置文件确认变化，切回原值后图鉴与设置完整。进入两次清空确认并选择保留，自动档及两个手动档完整。|[设置与清空取消记录](evidence/device-slot-checks.json)|
|交付 HAP|从空的依赖与构建目录重新构建，覆盖安装成品包后成功进入已取得的 E02。安装前后完整自动档相同。|[安装及 SHA-256](evidence/delivery-build-check.json)|

## T07　结束进程后恢复

1. 在 N08 完成手动保存。记录自动档及进程号 5608，结束应用后再次取进程号，结果为空。
2. 启动 EntryAbility，得到新进程号 5893。由首页继续调查，场景、机会 11、信任 60、4 条线索均保持原值。
3. 对比完整保存记录。包括 11 个 GameState 字段、13 条历史、谜题尝试次数、已用动作、标记和外层版本、槽位、保存时间，全部相等。[结束前记录](evidence/restart-before.json) · [恢复后记录](evidence/restart-after.json) · [比对结果](evidence/device-restart-result.json)
4. 在录屏中另以信任 50 的 N04 错答状态验证一次。旧进程 2303 消失，新进程 7741，完整记录相等，恢复后还能以 0417 继续解谜。[录屏中的第二次重启](evidence/device-restart-filmed.json)

较早一次尝试在前台切换时出现 LIFECYCLE_TIMEOUT，堆栈处于渲染服务调用。该次未完成验收；成功记录单独保留。[首次超时日志](evidence/device-restart-first-attempt-freeze.txt)

## 复现与覆盖范围

先从首页开局并做一次有效操作，确认“已自动保存”，用存档页保留一个手动槽。记下节点、各项数值、线索、历史。用 DevEco 的设备调试工具彻底停止该应用，再正常启动并继续，逐项核对。完整 JSON 位于应用私有文件目录，调试模拟器可按本仓库的两份重启记录核对。

自动化执行器按模拟器界面文字和控件位置操作，每步记录操作后读取的实际状态。操作记录中也保留了对话框处尚未改变进度的点击。损坏注入仅用于一次性测试槽，游戏路线均通过正常按钮和输入框推进。四种结局的模块测试覆盖详见 [Hypium 结果](test-results.md)，设备实录覆盖 E01、E02。
