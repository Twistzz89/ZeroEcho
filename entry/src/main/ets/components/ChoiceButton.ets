@Component
export struct ChoiceButton {
  @Prop controlId: string = '';
  @Prop label: string = '';
  @Prop cost: number = 0;
  @Prop available: boolean = true;
  @Prop reason: string = '';
  @Prop busy: boolean = false;
  onChoose: () => void = () => {};

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 7 }) {
        Row({ space: 10 }) {
          Text(this.label).fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor(this.available ? '#E8F1F5' : '#A0AEBB').layoutWeight(1)
          Text(this.cost === 0 ? '免费' : '−' + this.cost.toString() + ' 次')
            .fontSize(13).fontColor(this.available ? '#6EE3D2' : '#C8A16E')
        }.width('100%')
        if (!this.available && this.reason.length > 0) {
          Text(this.reason).fontSize(13).fontColor('#E2B978').width('100%')
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
    }.width('100%').height('auto').borderRadius(12).id(this.controlId)
      .backgroundColor(this.available ? '#203642' : '#17252F')
      .border({ width: 1, color: this.available ? '#35535D' : '#35414B' })
      .enabled(this.available && !this.busy).onClick(() => this.onChoose())
  }
}
