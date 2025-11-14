/**
 * 运行时配置：在应用启动时由 EntryAbility 从 rawfile 注入
 */

export interface AppConfig {
  supabaseUrl: string;
  supabaseAnonKey: string;
}

let runtimeConfig: AppConfig = {
  supabaseUrl: 'https://ugeyrsnrmxjyoflkaapk.supabase.co',
  supabaseAnonKey: '',
};

export function setAppConfig(partial: Partial<AppConfig>): void {
  if (partial.supabaseUrl !== undefined) {
    runtimeConfig.supabaseUrl = partial.supabaseUrl;
  }
  if (partial.supabaseAnonKey !== undefined) {
    runtimeConfig.supabaseAnonKey = partial.supabaseAnonKey;
  }
}

export function getAppConfig(): AppConfig {
  return runtimeConfig;
}


