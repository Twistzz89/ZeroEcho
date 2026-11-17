# 参考与素材来源

查阅日期：2026年11月16日。源码按本项目需求编写，未移植整份学生作业。

- [OpenHarmony官方应用示例](https://github.com/openharmony/applications_app_samples)：有限范围检查工程组织、原生组件与测试示例方向，仓库Apache-2.0；本项目没有直接搬运业务源码。其API兼容性仍以本机API17实际构建为准。
- [华为Preferences持久化文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-preferences/)：核实flush持久化要求。本项目完整历史采用沙箱JSON文件，不将跨键写入称作事务。
- [OpenHarmony Core File Kit](https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-core-file-kit/js-apis-file-fs.md)：核对readText、write、fsync与同目录rename接口，同时以安装SDK声明检验API17可用性。
- [DevEco 5.x本地测试](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-local-test-V5/)：Hypium测试入口、Hvigor test与Previewer机制。
- [模拟器命令行](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-emulator-command-line/)：本机5.x使用-hvd/-path/-imageRoot启动已有实例。
- [Navigation页面路由](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-navigation-jump/)：Navigation/NavDestination/NavPathStack结构，API签名另与本机SDK核对。

工程配置参考本机DevEco Studio创建的Hello World空模板，保留兼容SDK、Hvigor与Hypium版本，移除样例业务和非必要备份扩展。图标是项目内原创SVG波形图；剧情、角色、学校和日志均为虚构本地内容；无外网素材和音乐依赖。

教师评分标准和个人报告模板来自用户提供文件。任务书中的节点数量、测试建议和里程碑不作为额外教师硬性要求。
