/**
 * 专注进度统计页面：显示专注时间统计和AI洞察
 * @module FocusProgressPage
 * @note 此页面为示例实现，展示如何集成专注数据AI洞察功能
 * 如果项目中已有专注统计页面，请参考此实现进行集成
 */

import { generateFocusInsight, FocusInsightData, InsightResponse, CancellationToken as AIServiceCancellationToken } from '../utils/aiService';
import { ErrorHandler, AppError, ErrorCode } from '../utils/errorHandler';
import { deviceAdapter, DeviceType } from '../utils/deviceAdapter';
import { resourceManager, RESOURCES } from '../utils/resourceManager';
import { asyncManager, AsyncOptions, AsyncTask } from '../utils/asyncManager';
import promptAction from '@ohos.promptAction';
import { authService } from '../utils/authService';

@Entry
@Component
struct FocusProgressPage {
  @State totalFocusTime: number = 0; // 总专注时间（分钟）
  @State period: 'week' | 'month' | 'year' = 'week'; // 当前周期
  @State showInsight: boolean = false; // AI洞察显示状态
  @State insightContent: InsightResponse | null = null; // AI洞察内容
  @State isLoadingInsight: boolean = false; // AI洞察加载状态
  @State insightError: string = ''; // AI洞察错误提示
  @State hasInsufficientData: boolean = false; // 数据不足标志

  // 组件卸载标志
  private isDestroyed: boolean = false;
  // 异步任务管理
  private currentInsightTask: AsyncTask<InsightResponse> | null = null;
  private insightCancellationToken: AIServiceCancellationToken | null = null;
  // 设备适配
  private layoutConfig = deviceAdapter.getLayoutConfig();
  private deviceType = deviceAdapter.getDeviceType();
  private needsFocus = deviceAdapter.needsFocusNavigation();

  aboutToAppear() {
    // 加载专注数据（示例：这里应该从实际数据源加载）
    this.loadFocusData();
  }

  aboutToDisappear() {
    // 取消AI洞察任务
    this.cancelInsightTask();
  }

  /**
   * 取消AI洞察任务
   */
  private cancelInsightTask(): void {
    if (this.insightCancellationToken) {
      this.insightCancellationToken.cancel();
      this.insightCancellationToken = null;
    }
    if (this.currentInsightTask) {
      this.currentInsightTask.cancel();
      this.currentInsightTask = null;
    }
  }

  /**
   * 加载专注数据（示例实现）
   * 实际实现应该从数据库或API加载真实的专注时间数据
   */
  private loadFocusData(): void {
    // TODO: 从实际数据源加载专注时间数据
    // 示例：假设从某个服务获取数据
    // const focusData = await focusDataService.getFocusData(this.period);
    // this.totalFocusTime = focusData.totalMinutes;
    
    // 检查数据是否充足（示例：至少需要7天的数据）
    this.hasInsufficientData = this.totalFocusTime < 60; // 示例阈值：至少60分钟
  }

  /**
   * 加载AI洞察
   */
  onLoadInsight() {
    // 取消之前的洞察任务
    this.cancelInsightTask();

    // 检查数据是否充足
    if (this.hasInsufficientData) {
      this.insightError = '需要更多专注数据才能生成洞察';
      promptAction.showToast({
        message: '需要更多专注数据才能生成洞察',
        duration: 2000
      });
      return;
    }

    // 获取当前用户ID
    const currentUser = authService.getCurrentUser();
    if (!currentUser || !currentUser.id) {
      this.insightError = '请先登录';
      promptAction.showToast({
        message: '请先登录',
        duration: 2000
      });
      return;
    }

    this.isLoadingInsight = true;
    this.insightError = '';
    this.insightContent = null;

    // 创建取消令牌
    class InsightTokenImpl implements AIServiceCancellationToken {
      cancelled: boolean = false;
      cancel(): void {
        this.cancelled = true;
      }
      onCancel?(callback: () => void): void {
        // 简化实现，不处理回调
      }
    }
    this.insightCancellationToken = new InsightTokenImpl();

    // 计算周期开始和结束日期
    const now = new Date();
    let periodStart: Date;
    let periodEnd: Date = now;

    switch (this.period) {
      case 'week':
        periodStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'month':
        periodStart = new Date(now.getFullYear(), now.getMonth(), 1);
        break;
      case 'year':
        periodStart = new Date(now.getFullYear(), 0, 1);
        break;
    }

    // 构建专注数据（示例：实际应该从数据源获取）
    const focusData = {
      totalMinutes: this.totalFocusTime,
      dailyData: [] // TODO: 从实际数据源获取每日数据
    };

    // 构建洞察数据
    const insightData: FocusInsightData = {
      userId: currentUser.id,
      period: this.period,
      periodStart: periodStart.toISOString().split('T')[0],
      periodEnd: periodEnd.toISOString().split('T')[0],
      focusData: focusData
    };

    // 使用异步任务管理，设置5秒超时
    const options: AsyncOptions = {
      timeout: 5000, // 5秒超时
      retryCount: 0,
      retryDelay: 0,
      onProgress: () => {}
    };

    this.currentInsightTask = asyncManager.createTask(async () => {
      return await generateFocusInsight(insightData, this.insightCancellationToken!);
    }, options);

    this.currentInsightTask.promise
      .then((insight: InsightResponse) => {
        if (this.isDestroyed) return;

        // 验证洞察内容
        if (!insight || !insight.insightText || insight.insightText.trim().length === 0) {
          throw new AppError(
            ErrorCode.INSIGHT_INVALID_RESPONSE,
            'Invalid insight response',
            '洞察数据格式错误，请稍后重试'
          );
        }

        this.insightContent = insight;
        this.isLoadingInsight = false;
        this.insightError = '';
        this.showInsight = true;
        
        console.log('专注数据AI洞察生成成功');
      })
      .catch((error: Error | object | string) => {
        if (this.isDestroyed) return;

        const appError = ErrorHandler.handle(error, 'onLoadInsight');
        
        // 根据错误类型显示不同的提示
        let errorMessage = appError.userMessage || 'AI洞察生成失败，请稍后重试';
        
        if (appError.code === ErrorCode.INSIGHT_TIMEOUT) {
          errorMessage = 'AI洞察生成超时，请稍后重试';
        } else if (appError.code === ErrorCode.INSIGHT_SERVICE_UNAVAILABLE) {
          errorMessage = 'AI洞察暂时不可用，请稍后重试';
        } else if (appError.code === ErrorCode.INSIGHT_INVALID_RESPONSE) {
          errorMessage = '洞察数据格式错误，请稍后重试';
        }

        this.insightError = errorMessage;
        this.isLoadingInsight = false;
        
        // 显示Toast提示（2秒）
        promptAction.showToast({
          message: errorMessage,
          duration: 2000
        });
        
        console.error('专注数据AI洞察生成失败:', appError);
      })
      .finally(() => {
        if (!this.isDestroyed) {
          this.currentInsightTask = null;
          this.insightCancellationToken = null;
        }
      });
  }

  build() {
    Scroll() {
      Column() {
        // 顶部标题
        Text('专注进度统计')
          .fontSize(this.layoutConfig.fontSize.title)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: this.layoutConfig.spacing.medium })

        // 总专注时间部分
        Column() {
          Text('总专注时间')
            .fontSize(this.layoutConfig.fontSize.large)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: this.layoutConfig.spacing.small })

          Text(`${this.totalFocusTime} 分钟`)
            .fontSize(this.layoutConfig.fontSize.xxl)
            .fontWeight(FontWeight.Bold)
            .fontColor(RESOURCES.COLORS.PRIMARY)
            .margin({ bottom: this.layoutConfig.spacing.medium })

          // AI洞察按钮
          Button('AI 洞察')
            .type(ButtonType.Capsule)
            .backgroundColor(RESOURCES.COLORS.PRIMARY)
            .fontColor(Color.White)
            .fontSize(this.layoutConfig.fontSize.medium)
            .enabled(!this.isLoadingInsight && !this.hasInsufficientData)
            .onClick(() => {
              this.onLoadInsight();
            })
            .focusable(this.needsFocus)
            .focusOnTouch(this.needsFocus)
            .tabIndex(1)
        }
        .width('100%')
        .padding(this.layoutConfig.padding.large)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .margin({ bottom: this.layoutConfig.spacing.medium })

        // 数据不足提示
        if (this.hasInsufficientData) {
          Text('需要更多专注数据才能生成洞察')
            .fontSize(this.layoutConfig.fontSize.small)
            .fontColor('#666666')
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding(this.layoutConfig.padding.medium)
            .margin({ bottom: this.layoutConfig.spacing.medium })
        }

        // AI洞察区域
        if (this.showInsight || this.isLoadingInsight || this.insightError) {
          Column() {
            Text('AI 洞察分析')
              .fontSize(this.layoutConfig.fontSize.large)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: this.layoutConfig.spacing.medium })

            if (this.isLoadingInsight) {
              Row() {
                LoadingProgress()
                  .width(24)
                  .height(24)
                  .margin({ right: 8 })
                Text('正在生成AI洞察...')
                  .fontSize(this.layoutConfig.fontSize.medium)
                  .fontColor('#666666')
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(this.layoutConfig.padding.large)
            } else if (this.insightError) {
              Column() {
                Text(this.insightError)
                  .fontSize(this.layoutConfig.fontSize.medium)
                  .fontColor('#F44336')
                  .textAlign(TextAlign.Center)
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ bottom: this.layoutConfig.spacing.medium })

                Button('重试')
                  .type(ButtonType.Normal)
                  .fontSize(this.layoutConfig.fontSize.medium)
                  .backgroundColor('#FFEBEE')
                  .fontColor('#F44336')
                  .onClick(() => {
                    this.onLoadInsight();
                  })
                  .focusable(this.needsFocus)
                  .focusOnTouch(this.needsFocus)
              }
              .width('100%')
              .padding(this.layoutConfig.padding.large)
            } else if (this.insightContent) {
              Column() {
                Text(this.insightContent.insightText)
                  .fontSize(this.layoutConfig.fontSize.medium)
                  .fontColor(RESOURCES.COLORS.TEXT_PRIMARY)
                  .lineHeight(24)
                  .maxLines(this.deviceType === DeviceType.WEARABLE ? 10 : 20)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ bottom: this.layoutConfig.spacing.medium })

                if (this.insightContent.suggestions && this.insightContent.suggestions.length > 0) {
                  Text('改进建议：')
                    .fontSize(this.layoutConfig.fontSize.medium)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(RESOURCES.COLORS.PRIMARY)
                    .margin({ top: this.layoutConfig.spacing.medium, bottom: this.layoutConfig.spacing.small })

                  ForEach(this.insightContent.suggestions, (suggestion: any, index: number) => {
                    Text(`${index + 1}. ${suggestion.text}`)
                      .fontSize(this.layoutConfig.fontSize.small)
                      .fontColor(RESOURCES.COLORS.TEXT_SECONDARY)
                      .margin({ bottom: this.layoutConfig.spacing.small })
                  }, (suggestion: any, index: number) => `${index}-${suggestion.text}`)
                }
              }
              .width('100%')
              .padding(this.layoutConfig.padding.large)
            }
          }
          .width('100%')
          .padding(this.layoutConfig.padding.medium)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .margin({ bottom: this.layoutConfig.spacing.medium })
        }
      }
      .width('100%')
      .padding(this.layoutConfig.padding.medium)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }
}

