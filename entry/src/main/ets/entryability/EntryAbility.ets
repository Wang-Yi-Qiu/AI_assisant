import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { setAppConfig } from '../utils/config';
import util from '@ohos.util';

const DOMAIN = 0x0000;

// Supabase配置接口
interface SupabaseConfig {
  supabaseUrl?: string;
  anonKey?: string;
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    // 尝试从 rawfile 读取 Supabase 配置（可选）
    try {
      const rm = this.context.resourceManager;
      const bytes: Uint8Array = rm.getRawFileContentSync('supabase.json');
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      // 使用 decodeWithStream 方法（decode 已弃用）
      const text: string = decoder.decodeWithStream(new Uint8Array(bytes), { stream: false });
      const parsed = JSON.parse(text) as SupabaseConfig;
      const url: string | undefined = parsed?.supabaseUrl;
      const anon: string | undefined = parsed?.anonKey;
      setAppConfig({
        supabaseUrl: url,
        supabaseAnonKey: anon,
      });
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'Loaded supabase config from rawfile');
    } catch (e) {
      // 原则：配置缺失不崩溃，仅记录
      hilog.warn(DOMAIN, 'testTag', 'No supabase.json or parse error. Using defaults. Cause: %{public}s', JSON.stringify(e));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}