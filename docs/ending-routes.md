# 四结局合法操作路径

下列路径使用真实GameEngine从createInitialState创建的新局逐步执行；每次动作传入当前nodeId和expectedRevision。choice动作的answer与order为空字符串；puzzle动作填写表中答案。界面菜单和线索查看不计为业务动作。

## E01完整真相

1. share 共享信息
2. take-note 取得笔记
3. note-to-cabinet 前往档案柜
4. P01 提交0417，order为空
5. cooperate 协作调查
6. record-witness 记录口述
7. take-calibration 调查校准单
8. calibration-back 返回
9. take-gateway 调查网关
10. gateway-back 返回
11. take-config 调查配置
12. config-back 返回
13. open-timeline 打开时间线
14. P02 提交00:00与task-first
15. submit 提交结论

领域实测最终：E01，剩余10，信任60，revision15，线索6条。裸GameState JSON为3141个字符（非UTF-8字节数，不含存档信封）。

## E02局部修复

hold → take-note → note-to-cabinet → P01(0417，空order) → work-alone → alone-to-hub → take-gateway → gateway-back → take-config → config-back → to-report → submit。

领域实测最终：E02，剩余13，信任50，revision12，线索CL01/CL02/CL04/CL05。裸GameState JSON为2500个字符。

## E03调查中断

share → take-note → note-to-cabinet → 在P01连续16次提交合法但错误的1111（order为空）。

领域实测最终：E03，剩余0，信任60，revision19，P01尝试16次，未授予CL02。裸GameState JSON为3681个字符。达到E03后第17次尝试应被拒绝。

## E04未解疑云

share → skip-note → skip-cabinet → work-alone → alone-to-hub → to-report → submit。

领域实测最终：E04，剩余17，信任60，revision7，无线索。裸GameState JSON为1463个字符。最终submit也可替换为stop以验证主动结束。

## 验证边界

上述四条路线已于2026年11月16日在Windows宿主上执行同一份领域源码，并对每步JSON往返恢复执行严格状态验证；不是在模拟器或真机完成。设备路线验收、真实进程重启和录屏仍须独立执行并留证。字符数是当时实际序列化结果，包含用户可读中文历史；存储容量应另测UTF-8字节数及SaveEnvelope开销。
