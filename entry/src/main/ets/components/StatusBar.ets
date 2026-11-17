@Component
export struct StatusBar {
  @Prop remaining: number = 18;
  @Prop trust: number = 50;
  @Prop clueCount: number = 0;

  @Builder
  metric(label: string, value: string, tone: string) {
    Column({ space: 5 }) {
      Text(value).fontSize(25).fontWeight(FontWeight.Bold).fontColor(tone)
      Text(label).fontSize(12).fontColor('#9CACBB')
    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
  }

  build() {
    Row({ space: 12 }) {
      this.metric('调查机会', this.remaining.toString(), this.remaining <= 3 ? '#F4BB69' : '#E8F1F5')
      this.metric('同伴信任', this.trust.toString(), '#6EE3D2')
      this.metric('已获线索', this.clueCount.toString() + ' / 6', '#E8F1F5')
    }.width('100%').padding(18).backgroundColor('#172733').borderRadius(16)
  }
}
