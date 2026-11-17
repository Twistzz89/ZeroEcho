# 模拟器与本地测试能力审计

检查日期：2026-11-16。未修改主项目；未下载、升级或删除组件；未登录账号、读取凭据或清除模拟器用户数据。

## 已启动现成模拟器

此前默认路径未发现实例；继续读取 DevEco 的设备管理配置发现实际位置为 `D:\Huawei\huawei`。证据文件：

- `C:\Users\luguangkuo\AppData\Roaming\Huawei\DevEcoStudio5.0\options\deviceManager.xml` 中 `openharmonyDeployPath=D:/Huawei/huawei`。
- `D:\Huawei\huawei\lists.json`、`Huawei_Phone.ini`、`Huawei_Phone/config.ini`。

实例名为 `Huawei_Phone`，现有配置 API17、x86_64、4核、4GB RAM、1260×2720、520DPI，存储容量6GB。镜像目录为 `C:\Users\luguangkuo\AppData\Local\Huawei\Sdk\system-image\HarmonyOS-5.0.5\phone_x86`。

按已安装5.x版本使用官方兼容命令启动：

```powershell
Start-Process -FilePath 'D:\Huawei\DevEco Studio\tools\emulator\Emulator.exe' -WorkingDirectory 'D:\Huawei\DevEco Studio\tools\emulator' -ArgumentList @('-hvd','Huawei_Phone','-path','D:\Huawei\huawei','-imageRoot','C:\Users\luguangkuo\AppData\Local\Huawei\Sdk') -WindowStyle Hidden
```

普通沙箱内启动后进程快速退出且无日志；通过自动审批后的 `require_escalated` 执行启动，进程 PID14632 保持运行。`D:\Huawei\huawei\Huawei_Phone\Emulator.log` 在 21:17:25 显示 `Guest OS Boot Completed!!`。没有使用 reset 或 Wipe User Data。

升权执行 HDC 只读核实获得：

```text
127.0.0.1:5555    TCP    Connected    localhost    hdc
const.ohos.apiversion = 17
const.ohos.fullname = OpenHarmony-5.0.5.165
const.product.model = emulator
uname -m = x86_64
```

**沙箱可见性差异**：普通 `exec_command` 仍看不到宿主模拟器/HDC进程，返回空设备；升权命令可看见在线目标。后续 HDC 安装、运行和取证需要使用 `require_escalated`，不能把沙箱中的空结果认定为模拟器未启动。

HDC 路径：`D:\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`。目标参数：`-t 127.0.0.1:5555`。

## 无设备本地 Hypium 入口

已核对华为5.x官方 Local Test 文档及已安装 Hvigor 源码，支持在无设备情况下运行本地测试：

```powershell
$env:DEVECO_SDK_HOME = 'D:\Huawei\DevEco Studio\sdk'
$env:JAVA_HOME = 'D:\Huawei\DevEco Studio\jbr'
$env:NODE_HOME = 'D:\Huawei\DevEco Studio\tools\node'
& 'D:\Huawei\DevEco Studio\tools\node\node.exe' 'D:\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' test -p module=entry -p coverage=false --no-daemon
```

必须在目标工程根目录运行。`entry/src/test/List.test.ets` 为测试套件聚合入口，测试文件从 `@ohos/hypium` 导入 `describe`、`it`、`expect` 等。现有模板有 `LocalUnit.test.ets` 示例。

本地测试实际依赖 `D:\Huawei\DevEco Studio\sdk\default\openharmony\previewer\common\bin\Previewer.exe`，本机文件存在。已读安装目录中 `tools/hvigor/hvigor-ohos-plugin/node_modules/@ohos/coverage/lib/src/commandLine/localTest/previewer.js`，它使用 `spawn` 启动 Previewer、传入测试 ABC 与资源、监听 Hypium 结果并终止 Previewer，不需要 HDC 目标。代码默认 `windowsHide: true`。

结果文件：`entry/.test/default/intermediates/test/coverage_data/test_result.txt`；运行日志同目录 `coverage.log`。覆盖率启用时报告在 `entry/.test/default/outputs/test/reports`。

本次只审计入口，没有替主项目运行测试，因此不能将此记录作为业务测试通过证据。

## SDK TypeScript 模块

`D:\Huawei\DevEco Studio\sdk\default\openharmony\ets\build-tools\ets-loader\node_modules\typescript\lib\typescript.js`

同目录还有 `tsc.js`；package.json 声明 `ohos-typescript` 版本 `4.9.5-r4`。该路径是当前SDK所带编译模块，不能以普通TypeScript转译成功代替ArkTS/Hvigor构建通过。

## 官方参考

- [通过命令行使用模拟器](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-emulator-command-line/)：旧版本使用 `-hvd/-path/-imageRoot`，6.1以后新增选项不应用到本机5.x。
- [DevEco 5.x 本地测试](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-local-test-V5/)：`hvigorw test -p module=...`。
- [DevEco 5.x Hvigor命令行](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-hvigor-commandline-V5/)。
