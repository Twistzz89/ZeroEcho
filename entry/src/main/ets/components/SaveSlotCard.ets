@Component
export struct SaveSlotCard {
  @Prop titleText: string = '';
  @Prop description: string = '';
  @Prop statusText: string = '';
  @Prop automatic: boolean = false;
  @Prop canLoad: boolean = false;
  @Prop canSave: boolean = false;
  @Prop canDelete: boolean = false;
  @Prop recoverable: boolean = false;
  @Prop busy: boolean = false;
  onSave: () => void = () => {};
  onLoad: () => void = () => {};
  onDelete: () => void = () => {};
  onRecover: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Row() {
        Text(this.titleText).fontSize(19).fontWeight(FontWeight.Medium).fontColor('#E8F1F5')
        Blank()
        Text(this.statusText).fontSize(13).fontColor(this.canLoad ? '#6EE3D2' : '#E2B978')
      }.width('100%')
      Text(this.description).fontSize(14).lineHeight(22).fontColor('#AEBFCA').width('100%')
      Row({ space: 10 }) {
        Button('读取').fontSize(14).fontColor('#0E1B23').backgroundColor('#6EE3D2')
          .enabled(this.canLoad && !this.busy).onClick(() => this.onLoad())
        if (!this.automatic) {
          Button('保存').fontSize(14).backgroundColor('#29414D').fontColor('#E8F1F5')
            .enabled(this.canSave && !this.busy).onClick(() => this.onSave())
          Button('删除').fontSize(14).backgroundColor('#29414D').fontColor('#E8F1F5')
            .enabled(this.canDelete && !this.busy).onClick(() => this.onDelete())
        }
      }.width('100%')
      if (this.recoverable) {
        Button('从已验证副本恢复').fontSize(14).fontColor('#F4BB69').backgroundColor('#24313C')
          .enabled(!this.busy).onClick(() => this.onRecover())
      }
    }.alignItems(HorizontalAlign.Start).width('100%').padding(18)
      .backgroundColor('#172733').borderRadius(14)
  }
}
