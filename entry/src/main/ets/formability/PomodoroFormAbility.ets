import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import FormProvider from '@ohos.app.form.formProvider';
import hilog from '@ohos.hilog';
import Want from '@ohos.app.ability.Want';
import { PomodoroFormManager } from '../form/PomodoroFormManager';

/**
 * 番茄钟服务卡片Ability
 * 负责管理番茄钟桌面卡片的创建、更新和删除
 */
export default class PomodoroFormAbility extends FormExtensionAbility {
  private static readonly TAG = 'PomodoroFormAbility';
  private static readonly DOMAIN = 0xFF00;
  private formManager: PomodoroFormManager;

  /**
   * 卡片创建时调用
   * @param formId 卡片ID
   * @param formInfo 卡片信息
   * @param link 信息链接
   * @param formBindingData 卡片数据绑定对象
   */
  onCreate(formId: string, formInfo: any, link: any, formBindingData: formBindingData.FormBindingData): Promise<formBindingData.FormBindingData> {
    hilog.info(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `onCreate, formId: ${formId}`);

    try {
      // 初始化表单管理器
      this.formManager = PomodoroFormManager.getInstance();

      // 注册表单
      this.formManager.registerForm(formId);

      // 获取初始数据
      const initialData = this.formManager.createFormData ?
        this.formManager.createFormData() : this.getDefaultCardData();

      return Promise.resolve(new formBindingData(initialData));
    } catch (error) {
      hilog.error(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `onCreate error: ${error}`);
      return Promise.resolve(new formBindingData(this.getDefaultCardData()));
    }
  }

  /**
   * 卡片更新时调用
   * @param formId 卡片ID
   * @param formBindingData 卡片数据绑定对象
   */
  onUpdate(formId: string, formBindingData: formBindingData.FormBindingData): Promise<formBindingData.FormBindingData> {
    hilog.info(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `onUpdate, formId: ${formId}`);

    if (this.formManager) {
      this.formManager.updateForm(formId);
    }

    return Promise.resolve(formBindingData);
  }

  /**
   * 卡片删除时调用
   * @param formId 卡片ID
   */
  onDelete(formId: string): void {
    hilog.info(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `onDelete, formId: ${formId}`);

    if (this.formManager) {
      this.formManager.unregisterForm(formId);
    }
  }

  /**
   * 卡片配置更新时调用
   * @param formId 卡片ID
   * @param formBindingData 卡片数据绑定对象
   */
  onCastToNormal(formId: string, formBindingData: formBindingData.FormBindingData): Promise<formBindingData.FormBindingData> {
    hilog.info(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `onCastToNormal, formId: ${formId}`);

    if (this.formManager) {
      this.formManager.updateForm(formId);
    }

    return Promise.resolve(formBindingData);
  }

  /**
   * 卡片配置更新时调用
   * @param formId 卡片ID
   * @param formBindingData 卡片数据绑定对象
   */
  onUpdateFormInfo(formId: string, formBindingData: formBindingData.FormBindingData): Promise<formBindingData.FormBindingData> {
    hilog.info(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `onUpdateFormInfo, formId: ${formId}`);

    if (this.formManager) {
      this.formManager.updateForm(formId);
    }

    return Promise.resolve(formBindingData);
  }

  /**
   * 卡片可见性变化时调用
   * @param formId 卡片ID
   * @param formState 卡片状态
   */
  onVisibilityChange(formId: string, formState: any): void {
    hilog.info(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `onVisibilityChange, formId: ${formId}, formState: ${formState}`);
  }

  /**
   * 处理卡片事件
   * @param formId 卡片ID
   * @param message 事件消息
   */
  onFormEvent(formId: string, message: string): void {
    hilog.info(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `onFormEvent, formId: ${formId}, message: ${message}`);

    try {
      // 解析消息内容
      let action: string = '';
      let parameters: Record<string, any> = {};

      try {
        const eventData = JSON.parse(message);
        action = eventData.action || '';
        parameters = eventData.parameters || {};
      } catch (parseError) {
        // 如果解析失败，直接使用message作为action
        action = message;
        parameters = {};
      }

      if (action === 'open_app') {
        // 打开主应用
        this.openMainApp();
        return;
      }

      // 使用FormManager处理番茄钟事件
      if (this.formManager) {
        this.formManager.handleFormEvent(action, parameters);
      }
    } catch (error) {
      hilog.error(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `onFormEvent error: ${error}`);
    }
  }

  /**
   * 获取默认卡片数据
   */
  private getDefaultCardData(): Record<string, any> {
    return {
      formId: '',
      currentState: 'idle',
      formattedTime: '25:00',
      progress: '0.0',
      totalProgress: 1500,
      currentTask: '准备开始',
      isRunning: false,
      isPaused: false,
      completedToday: 0,
      stateText: '空闲',
      stateColor: '#9E9E9E',
      actionButtonText: '开始专注',
      secondaryActionButtonText: '',
      timestamp: Date.now()
    };
  }

  /**
   * 打开主应用
   */
  private openMainApp(): void {
    try {
      // 在FormExtensionContext中，startApp可能不可用
      // 这里记录日志，实际应用中可能需要使用其他方式启动主应用
      hilog.info(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, 'Attempting to open main app from form');

      // 使用更通用的方式启动应用
      // 注意：在FormExtension中可能无法直接启动应用，这需要根据具体API调整
      if (this.context) {
        hilog.info(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, 'Context available, but startAbility may not be supported in FormExtension');
      }
    } catch (error) {
      hilog.error(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `openMainApp error: ${error}`);
    }
  }

  /**
   * 更新卡片数据
   */
  private updateFormData(formId: string, formData: Record<string, any>): void {
    try {
      const formBindingDataObj = formBindingData.createFormBindingData(formData);
      FormProvider.updateForm(formId, formBindingDataObj).then(() => {
        hilog.debug(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `Form ${formId} updated successfully`);
      }).catch((error: Error) => {
        hilog.error(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `Failed to update form ${formId}: ${error.message}`);
      });
    } catch (error) {
      hilog.error(PomodoroFormAbility.DOMAIN, PomodoroFormAbility.TAG, `updateFormData error: ${error}`);
    }
  }
}