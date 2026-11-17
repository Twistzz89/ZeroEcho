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
    const story = createStory();
    const store = new FileTextStore(this.context.filesDir);
    Session.vm = new GameViewModel(story, new SaveRepository(store, story));
    hilog.info(0x0000, 'ZeroEcho', 'Application controller created');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
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
