@Component
export struct ClueCard {
  @Prop code: string = '';
  @Prop titleText: string = '';
  @Prop category: string = '';
  @Prop contentText: string = '';
  @Prop unlocked: boolean = false;
  @Prop expanded: boolean = false;
  @Prop largeText: boolean = false;
  onOpen: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Row() {
        Text(this.code).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#6EE3D2')
        Blank()
        Text(this.unlocked ? this.category : '未取得').fontSize(12).fontColor('#9CACBB')
      }.width('100%')
      Text(this.unlocked ? this.titleText : '待发现的线索')
        .fontSize(this.largeText ? 21 : 18).fontWeight(FontWeight.Medium).fontColor('#E8F1F5').width('100%')
      if (this.unlocked && this.expanded) {
        Text(this.contentText).fontSize(this.largeText ? 20 : 16).lineHeight(this.largeText ? 30 : 25)
          .fontColor('#C9D6DE').width('100%')
      } else {
        Text(this.unlocked ? '点击查看记录' : '继续调查以解锁此档案')
          .fontSize(14).fontColor('#9CACBB').width('100%')
      }
    }.alignItems(HorizontalAlign.Start).width('100%').padding(18).id('clue-' + this.code)
      .backgroundColor('#172733').borderRadius(14)
      .border({ width: 1, color: this.expanded && this.unlocked ? '#64BFB6' : '#293D49' })
      .onClick(() => { if (this.unlocked) { this.onOpen(); } })
  }
}
