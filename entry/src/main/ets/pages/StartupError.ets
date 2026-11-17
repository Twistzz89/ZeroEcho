import { Session } from '../common/Session';

@Entry
@Component
struct StartupError {
  build() {
    Column({ space: 20 }) {
      Text('零点回声').fontSize(30).fontColor('#E7F1F5').fontWeight(FontWeight.Bold)
      Text('暂时无法开始调查').fontSize(22).fontColor('#F2C078')
      Text(Session.startupError).fontSize(18).fontColor('#C0CFDB').lineHeight(28)
      Text('已有存档没有被改写。请保留数据，修正配置后重新启动应用。')
        .fontSize(16).fontColor('#9CB1C4').lineHeight(26)
    }.width('100%').height('100%').padding(28).justifyContent(FlexAlign.Center)
    .backgroundColor('#0B1420')
  }
}
