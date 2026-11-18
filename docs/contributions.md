# 个人分工与提交对应

卢广阔，24物联2，学号 20240313213，GitHub 账号 Twistzz89。独立项目，无组员。本人负责整体工程及课程交付。Codex 辅助编写、修改代码与测试，协助执行构建、模拟器验收、文档撰写和报告排版。本人需能解释和演示对应实现。

|本地提交|可检查的变更|相关模块或证据|
|---|---|---|
|3b10881|业务编码前提交需求与初始规则|docs/requirements.md|
|cdf611d|实现原生调查流程、规则、存档与恢复|entry/src/main/ets 下的 domain、data、viewmodels、pages、components|
|7031d77|处理不可读主文件及启动出错的情况|SaveRepository.ets、EntryAbility.ets、StartupError.ets|
|a2c0082|加入官方 Hypium 用例及三轮真实结果|entry/src/test、docs/evidence/hypium-03-results.txt|
|c45f8ba|修复设备状态栏和槽位卡显示旧数据|StatusBar.ets、Index.ets、修复前后设备截图|
|5ddf041|记录模拟器分支、重启、备份恢复和交付 HAP 的干净构建|docs/device-acceptance.md、docs/evidence、docs/screenshots|

可运行 `git log --oneline --reverse` 查看完整本地历史，运行 `git show --stat 短哈希` 或 `git show 短哈希` 对照源码。作者配置仅对本项目有效，使用 Twistzz89 和该账号的 GitHub 隐私邮箱。

[目标 GitHub 仓库](https://github.com/Twistzz89/ZeroEcho)已由本人给出。本次按本人选择先完成本地交付，远程推送与教师访问核实留待之后。
