/**
 * 启动画面页面
 * 显示应用启动时的欢迎界面
 * @module SplashPage
 */

import router from '@ohos.router';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct SplashPage {
  @State progress: number = 0; // 进度条进度 (0-100)
  @State isAnimating: boolean = true;

  aboutToAppear() {
    console.info('[SplashPage] 页面开始加载');
    // 初始进度设置为约25%（1/4）
    this.progress = 25;
    console.info('[SplashPage] 初始进度设置为 25%');
    // 启动进度条动画
    this.startProgressAnimation();
  }

  /**
   * 启动进度条动画
   */
  startProgressAnimation() {
    console.info('[SplashPage] 开始进度条动画');
    // 模拟加载过程，进度条从25%到100%
    const duration = 1000; // 总时长1秒
    const steps = 60; // 60步
    const stepDuration = duration / steps;
    const stepProgress = 75 / steps; // 从25%到100%，需要75%的进度

    let currentStep = 0;
    const timer = setInterval(() => {
      currentStep++;
      this.progress = Math.min(25 + currentStep * stepProgress, 100);
      console.info(`[SplashPage] 进度: ${this.progress.toFixed(1)}%`);

      // 当进度达到100%时，跳转到主页面
      if (this.progress >= 100) {
        clearInterval(timer);
        console.info('[SplashPage] 动画完成，准备跳转到主页');
        this.navigateToHome();
      }
    }, stepDuration);
  }

  /**
   * 跳转到主页面
   */
  navigateToHome() {
    console.info('[SplashPage] 开始跳转到主页');
    // 延迟一小段时间确保动画完成
    setTimeout(() => {
      console.info('[SplashPage] 执行路由跳转到 pages/Index');
      // 尝试使用 replaceUrl 避免返回到启动页
      router.replaceUrl({
        url: 'pages/Index'
      }).then(() => {
        console.info('[SplashPage] 跳转到主页成功');
      }).catch((err: BusinessError) => {
        console.error('[SplashPage] 跳转到主页失败:', err);
        console.error('[SplashPage] 错误详情:', JSON.stringify(err));
        // 如果 replaceUrl 失败，尝试 pushUrl
        console.info('[SplashPage] 尝试使用 pushUrl 作为备选方案');
        router.pushUrl({
          url: 'pages/Index'
        }).then(() => {
          console.info('[SplashPage] pushUrl 跳转成功');
        }).catch((pushErr: BusinessError) => {
          console.error('[SplashPage] pushUrl 也失败:', pushErr);
        });
      });
    }, 100);
  }

  /**
   * 处理返回按钮事件
   * 启动页不应该被返回，直接跳转到主页
   */
  onBackPress(): boolean {
    console.info('[SplashPage] 用户按下返回键，跳转到主页');
    // 如果用户按返回键，直接跳转到主页
    router.replaceUrl({
      url: 'pages/Index'
    }).then(() => {
      console.info('[SplashPage] 返回键跳转主页成功');
    }).catch((err: BusinessError) => {
      console.error('[SplashPage] 返回键跳转主页失败:', err);
      // 备选方案
      router.pushUrl({
        url: 'pages/Index'
      }).catch((pushErr: BusinessError) => {
        console.error('[SplashPage] 返回键备选方案也失败:', pushErr);
      });
    });
    // 返回 true 表示已处理返回事件，阻止默认行为
    return true;
  }

  build() {
    Column() {
      // Logo区域
      Column() {
        // 三个同心圆和大脑图标
        Stack() {
          // 外层圆（深蓝色）
          Circle({ width: 120, height: 120 })
            .fill('#0D1B2A') // 深蓝色
          
          // 中层圆（浅蓝色）
          Circle({ width: 100, height: 100 })
            .fill('#1E3A5F') // 浅蓝色
          
          // 内层圆（亮蓝色）
          Circle({ width: 80, height: 80 })
            .fill('#2196F3') // 亮蓝色
          
          // 大脑图标（精确绘制对称的大脑，显示两个半球和清晰的脑回纹理）
          Stack() {
            // 大脑主体轮廓（完全对称的两个半球）
            Path()
              .commands('M 40 4 C 28 4 18 8 14 16 C 10 24 10 32 14 40 C 18 44 22 46 28 46 C 32 48 36 48 40 48 C 44 48 48 48 52 46 C 58 46 62 44 66 40 C 70 32 70 24 66 16 C 62 8 52 4 40 4 Z')
              .width(80)
              .height(52)
              .fill('#2196F3')
            
            // 左半球脑回纹理1（上部）
            Path()
              .commands('M 24 14 Q 20 16 20 20 Q 20 24 24 26')
              .width(80)
              .height(52)
              .stroke('#1976D2')
              .strokeWidth(2)
              .fillOpacity(0)
            
            // 左半球脑回纹理2（中部）
            Path()
              .commands('M 24 28 Q 20 30 20 34 Q 20 38 24 40')
              .width(80)
              .height(52)
              .stroke('#1976D2')
              .strokeWidth(2)
              .fillOpacity(0)
            
            // 左半球脑回纹理3（下部）
            Path()
              .commands('M 24 40 Q 20 42 20 44')
              .width(80)
              .height(52)
              .stroke('#1976D2')
              .strokeWidth(2)
              .fillOpacity(0)
            
            // 右半球脑回纹理1（上部）
            Path()
              .commands('M 56 14 Q 60 16 60 20 Q 60 24 56 26')
              .width(80)
              .height(52)
              .stroke('#1976D2')
              .strokeWidth(2)
              .fillOpacity(0)
            
            // 右半球脑回纹理2（中部）
            Path()
              .commands('M 56 28 Q 60 30 60 34 Q 60 38 56 40')
              .width(80)
              .height(52)
              .stroke('#1976D2')
              .strokeWidth(2)
              .fillOpacity(0)
            
            // 右半球脑回纹理3（下部）
            Path()
              .commands('M 56 40 Q 60 42 60 44')
              .width(80)
              .height(52)
              .stroke('#1976D2')
              .strokeWidth(2)
              .fillOpacity(0)
            
            // 顶部脑回纹理（对称的波浪，连接两个半球）
            Path()
              .commands('M 28 10 Q 32 8 36 8 Q 40 8 44 8 Q 48 8 52 10')
              .width(80)
              .height(52)
              .stroke('#1976D2')
              .strokeWidth(2)
              .fillOpacity(0)
            
            // 中间分隔线（两个半球的分界）
            Path()
              .commands('M 40 12 L 40 44')
              .width(80)
              .height(52)
              .stroke('#1565C0')
              .strokeWidth(1.5)
              .fillOpacity(0)
          }
          .width(80)
          .height(52)
        }
        .width(120)
        .height(120)
        .margin({ bottom: 40 })
      }
      .width('100%')
      .flexGrow(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 标题和标语
      Column() {
        Text('Focus Vision')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .margin({ bottom: 12 })
        
        Text('Focus, Analyzed.')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .opacity(0.9)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 80 })

      // 进度条（底部）
      Column() {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('80%')
          .height(4)
          .color('#2196F3') // 亮蓝色
          .backgroundColor('#2D3748') // 深灰色背景
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 60 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A1929') // 深色背景（接近黑色）
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

