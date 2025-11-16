import notification from '@ohos.notification';
import vibrator from '@ohos.vibrator';
import { BusinessError } from '@kit.BasicServicesKit';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';

/**
 * 通知提醒服务
 * 负责播放声音和震动提醒
 */
export class NotificationService {
  private static instance: NotificationService | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): NotificationService {
    if (!NotificationService.instance) {
      NotificationService.instance = new NotificationService();
    }
    return NotificationService.instance;
  }

  /**
   * 设置应用上下文
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 播放番茄钟完成提醒
   */
  async playPomodoroCompleteNotification(type: 'focus' | 'break'): Promise<void> {
    const title = type === 'focus' ? '专注时间完成！' : '休息时间结束！';
    const content = type === 'focus' ? '恭喜完成一个番茄钟，休息一下吧' : '休息结束，准备开始新的专注';

    try {
      // 检查通知权限
      const hasNotificationPermission = await this.checkNotificationPermission();
      if (hasNotificationPermission) {
        await this.sendNotification(title, content);
      } else {
        console.warn('NotificationService: No notification permission, trying to request');
        const granted = await this.requestNotificationPermission();
        if (granted) {
          await this.sendNotification(title, content);
        }
      }

      // 播放声音（这里简化实现，实际可能需要音频播放）
      console.info(`NotificationService: Playing sound for ${type} complete`);
      await this.playSound();

      // 检查震动权限并触发震动
      const hasVibrationPermission = await this.checkVibratorPermission();
      if (hasVibrationPermission) {
        await this.vibrate();
      } else {
        console.warn('NotificationService: No vibration permission');
      }

    } catch (error) {
      console.error('NotificationService: Failed to play notification', error);
      // 可以通过回调通知UI层显示错误提示
    }
  }

  /**
   * 发送系统通知
   */
  private async sendNotification(title: string, content: string): Promise<void> {
    try {
      // 简化的通知实现，使用基础的通知API
      await notification.publish({
        id: Date.now(),
        content: {
          contentType: notification.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: content,
            additionalText: '番茄钟助手'
          }
        }
      });
      console.info(`NotificationService: Notification sent - ${title}`);
    } catch (error) {
      console.error('NotificationService: Failed to send notification', error);
    }
  }

  /**
   * 触发震动
   */
  private async vibrate(): Promise<void> {
    try {
      // 震动模式：短震动
      await vibrator.startVibration({
        type: 'time',
        duration: 200
      }, {
        usage: 'touch'
      });

      console.info('NotificationService: Vibration played');
    } catch (error) {
      console.error('NotificationService: Failed to vibrate', error);
    }
  }

  /**
   * 播放简单提示音（模拟）
   */
  private async playSound(): Promise<void> {
    try {
      // 这里应该使用实际的音频播放API
      // 目前简化为日志输出
      console.info('NotificationService: Playing completion sound');

      // 在实际实现中，这里可以使用：
      // import audio from '@ohos.multimedia.audio';
      // import media from '@ohos.multimedia.media';
      // 来播放音频文件
    } catch (error) {
      console.error('NotificationService: Failed to play sound', error);
    }
  }

  /**
   * 检查通知权限
   */
  async checkNotificationPermission(): Promise<boolean> {
    try {
      if (!this.context) {
        console.warn('NotificationService: Context not set, cannot check notification permission');
        return false;
      }

      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = this.context.applicationInfo;

      if (!bundleInfo || !bundleInfo.accessTokenId) {
        console.warn('NotificationService: Cannot get accessTokenId');
        return false;
      }

      const status = await atManager.checkAccessToken(bundleInfo.accessTokenId, 'ohos.permission.NOTIFICATION_CONTROLLER');
      const hasPermission = status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;

      console.info(`NotificationService: Notification permission status: ${hasPermission}`);
      return hasPermission;
    } catch (error) {
      console.error('NotificationService: Failed to check notification permission', error);
      return false;
    }
  }

  /**
   * 请求通知权限
   */
  async requestNotificationPermission(): Promise<boolean> {
    try {
      if (!this.context) {
        console.warn('NotificationService: Context not set, cannot request notification permission');
        return false;
      }

      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = this.context.applicationInfo;

      if (!bundleInfo || !bundleInfo.accessTokenId) {
        console.warn('NotificationService: Cannot get accessTokenId for permission request');
        return false;
      }

      const result = await atManager.requestPermissionsFromUser(this.context, ['ohos.permission.NOTIFICATION_CONTROLLER']);
      const granted = result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;

      console.info(`NotificationService: Notification permission request result: ${granted}`);
      return granted;
    } catch (error) {
      console.error('NotificationService: Failed to request notification permission', error);
      return false;
    }
  }

  /**
   * 检查震动权限
   */
  async checkVibratorPermission(): Promise<boolean> {
    try {
      if (!this.context) {
        console.warn('NotificationService: Context not set, cannot check vibrator permission');
        return false;
      }

      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = this.context.applicationInfo;

      if (!bundleInfo || !bundleInfo.accessTokenId) {
        console.warn('NotificationService: Cannot get accessTokenId for vibrator permission');
        return false;
      }

      const status = await atManager.checkAccessToken(bundleInfo.accessTokenId, 'ohos.permission.APPROXIMATELY_LOCATION');
      const hasPermission = status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;

      console.info(`NotificationService: Vibrator permission status: ${hasPermission}`);
      return hasPermission;
    } catch (error) {
      console.error('NotificationService: Failed to check vibrator permission', error);
      return false;
    }
  }

  /**
   * 清除所有通知
   */
  async clearAllNotifications(): Promise<void> {
    try {
      // 简化实现，实际中可能需要不同的API
      console.info('NotificationService: Clear all notifications (not implemented)');
    } catch (error) {
      console.error('NotificationService: Failed to clear notifications', error);
    }
  }

  /**
   * 清除特定通知
   */
  async clearNotification(notificationId: number): Promise<void> {
    try {
      // 简化实现
      console.info(`NotificationService: Clear notification ${notificationId} (not implemented)`);
    } catch (error) {
      console.error(`NotificationService: Failed to clear notification ${notificationId}`, error);
    }
  }

  /**
   * 发送进度通知（用于长时间运行的任务）
   */
  async sendProgressNotification(title: string, content: string, progress: number): Promise<void> {
    try {
      // 简化的进度通知实现
      await notification.publish({
        id: Date.now(),
        content: {
          contentType: notification.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: content,
            additionalText: `${Math.round(progress)}%`
          }
        }
      });
      console.info(`NotificationService: Progress notification sent - ${progress}%`);
    } catch (error) {
      console.error('NotificationService: Failed to send progress notification', error);
    }
  }
}