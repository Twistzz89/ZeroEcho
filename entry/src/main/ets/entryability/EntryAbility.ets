import { UIAbility, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { createStory } from '../data/StoryRepository';
import { FileTextStore } from '../data/FileTextStore';
import { SaveRepository } from '../data/SaveRepository';
import { GameViewModel } from '../viewmodels/GameViewModel';
import { Session } from '../common/Session';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    try {
      const story = createStory();
      const store = new FileTextStore(this.context.filesDir);
      Session.vm = new GameViewModel(story, new SaveRepository(store, story));
      Session.startupError = '';
      hilog.info(0x0000, 'ZeroEcho', 'Application controller created');
    } catch (error) {
      Session.vm = undefined;
      Session.startupError = '剧情配置校验失败，应用未开放调查和存档写入。请检查剧情ID、引用、条件与效果后重新构建。';
      hilog.error(0x0000, 'ZeroEcho', 'Startup validation failed: %{public}s', String(error));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent(Session.vm === undefined ? 'pages/StartupError' : 'pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'ZeroEcho', 'Load content failed: %{public}s', JSON.stringify(err));
      }
    });
  }

  onBackground(): void {
    // Every accepted action is persisted by GameViewModel before the UI is advanced.
    // No deferred persistence is scheduled here: lifecycle callbacks may be interrupted.
    hilog.info(0x0000, 'ZeroEcho', 'Background: no deferred writes');
  }
}
