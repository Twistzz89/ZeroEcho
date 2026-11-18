# 本机环境只读检查

本页保留 2026-11-16 业务编码前的环境快照。后续已完成构建、安装与模拟器实测。[最终构建](evidence/delivery-build-check.json) · [设备运行](device-acceptance.md)

## 工具链

| 项目 | 发现与证据 |
| --- | --- |
| DevEco Studio | `D:\Huawei\DevEco Studio`；`product-info.json` 版本 `5.0.13.240`，build `233.14475.28.36.5013240` |
| HarmonyOS SDK | `D:\Huawei\DevEco Studio\sdk\default`；`sdk-pkg.json` 为 HarmonyOS 5.0.5，API 17，组件版本 `5.0.5.165` |
| ArkTS SDK | `sdk\default\openharmony\ets\oh-uni-package.json` 为 API 17，版本 `5.0.5.165` |
| Node | `D:\Huawei\DevEco Studio\tools\node\node.exe`；实测 `v18.20.1` |
| Java | `D:\Huawei\DevEco Studio\jbr\bin\java.exe`；实测 OpenJDK `17.0.12` |
| ohpm | `D:\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat`；实测 `5.0.19` |
| Hvigor | `D:\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js`；`tools\hvigor\hvigor\package.json` 为 `5.17.6` |
| HDC | `D:\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe` |
| Git | `C:\Users\luguangkuo\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe` |

系统 PATH 没有直接找到 hvigor、ohpm、hdc；应使用绝对路径。默认 node 来自 Codex runtime，与 DevEco 自带 Node 路径不同，构建应明确选择 DevEco Node。查询全局 `git config --global --get user.name` 和 `user.email` 均返回 1（未配置），不能推定用户真实提交身份。

## 已有工程与模板

`C:\Users\luguangkuo\DevEcoStudioProjects\MyApplication` 是空白 Hello World 工程，`entry/src/main/ets/pages/Index.ets` 仅显示 Hello World 并点击切换 Welcome。工程为 Stage 模型，`modelVersion=5.0.5`，`targetSdkVersion=5.0.5(17)`，`compatibleSdkVersion=5.0.5(17)`，`runtimeOS=HarmonyOS`。`signingConfigs` 为空，没有可用签名配置。未发现 `.git` 目录；Git 在该外部路径的访问还受到权限限制，未修改工程。

空模板已经有 `oh_modules` 中的 `@ohos/hypium@1.0.21` 和 `@ohos/hamock@1.0.0`。项目依赖配置与 Hvigor 配置可用于新工程兼容性参考；不应复制 `.idea`、`.hvigor` 或签名文件。官方内置工程模板在 `D:\Huawei\DevEco Studio\plugins\openharmony\lib\templates`。

发现另一个既有课程示例 `C:\Users\luguangkuo\Documents\Codex\2026-10-29\referenced-chatgpt-conversation-this-is-an\CustomComponentExample`，内容为实验七的自定义组件、生命周期、列表和 Promise 实验，同样 API 17。它不是零点回声项目，未改动。

`D:\Codex\ZeroEcho` 不存在。当前工作区及祖先目录未发现 AGENTS.md；在已有 MyApplication 和上述 Documents/Codex 范围搜索也未返回 AGENTS.md。

## 设备状态

执行 `hdc list targets -v` 退出码为 0，输出为空，当前没有连接目标。未发现正在运行的 DevEco Studio 或模拟器进程。模拟器程序存在于 `D:\Huawei\DevEco Studio\tools\emulator\Emulator.exe`。

已下载系统镜像：`C:\Users\luguangkuo\AppData\Local\Huawei\Sdk\system-image\HarmonyOS-5.0.5\phone_x86`。其元数据为 API 17，组件版本 `5.0.1.121`，guestVersion `HarmonyOS 5.0.1.121(SP1)`。镜像元数据不等于在线设备版本，未启动验证。`AppData\Local\Huawei\Emulator\deployed` 仅看到 `versionInfo.txt`，未发现已创建实例配置；可能需要在 DevEco Device Manager 创建/启动实例。

## 新工程候选构建命令

以下命令根据已安装工具与空模板配置整理，尚未在新工程验证。必须在新的可写工程根目录运行，避免写入现有课程工程。环境变量仅对子进程会话设置，不必改系统配置。

```powershell
$env:DEVECO_SDK_HOME = 'D:\Huawei\DevEco Studio\sdk'
$env:JAVA_HOME = 'D:\Huawei\DevEco Studio\jbr'
$env:NODE_HOME = 'D:\Huawei\DevEco Studio\tools\node'
& 'D:\Huawei\DevEco Studio\tools\node\node.exe' 'D:\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
```

SDK 环境变量路径应指向 `sdk`，其下有 `default/sdk-pkg.json`。已读本机 `hvigor-ohos-plugin/src/sdk/lib/property-get.js`，HarmonyOS 模式从 `DEVECO_SDK_HOME` 读取，不依赖空模板 `local.properties`。

## 初次环境检查时的缺口（历史记录）

1. 没有在线设备，需要创建/启动已有模拟器或连接真机，才能实际运行、测试关闭进程恢复和取得录屏。
2. 空模板没有签名配置；构建与安装签名能力需要在新工程实际验证，不能预称可安装。
3. 本人 Git 姓名、邮箱、GitHub 账号与目标仓库需核实；全局 Git 身份未配置，不替用户杜撰。
4. 新工程构建、设备测试、恢复测试均未执行；这些不是环境存在即可证明通过的项目。
