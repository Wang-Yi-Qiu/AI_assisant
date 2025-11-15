import { HomePage } from './HomePage';
import { AIAssistantPage } from './AIAssistantPage';
import { SettingsPage } from './SettingsPage';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  @Builder TabBuilder(title: string, index: number) {
    Column() {
      Text(index === 0 ? '⏱️' : index === 1 ? '✨' : '⚙️')
        .fontSize(24)
        .fontColor(this.currentIndex === index ? '#007DFF' : Color.Gray)
        .margin({ bottom: 2 })
      Text(title)
        .fontSize(12)
        .fontColor(this.currentIndex === index ? '#007DFF' : Color.Gray)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomePage()
      }
      .tabBar(this.TabBuilder('番茄钟', 0))

      TabContent() {
        AIAssistantPage()
      }
      .tabBar(this.TabBuilder('AI助手', 1))

      TabContent() {
        SettingsPage()
      }
      .tabBar(this.TabBuilder('设置', 2))
    }
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .barWidth('100%')
    .barHeight(56)
    .barMode(BarMode.Fixed)
    .backgroundColor('#1C1C1C')
    .animationDuration(300)
    .scrollable(true)
  }
}