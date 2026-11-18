@Component
export struct StatusBar {
  @Prop remaining: number = 18;
  @Prop trust: number = 50;
  @Prop clueCount: number = 0;

  build() {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(this.remaining.toString()).fontSize(25).fontWeight(FontWeight.Bold)
          .fontColor(this.remaining <= 3 ? '#F4BB69' : '#E8F1F5')
        Text('调查机会').fontSize(12).fontColor('#9CACBB')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 5 }) {
        Text(this.trust.toString()).fontSize(25).fontWeight(FontWeight.Bold).fontColor('#6EE3D2')
        Text('同伴信任').fontSize(12).fontColor('#9CACBB')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 5 }) {
        Text(this.clueCount.toString() + ' / 6').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#E8F1F5')
        Text('已获线索').fontSize(12).fontColor('#9CACBB')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(18).backgroundColor('#172733').borderRadius(16)
  }
}
