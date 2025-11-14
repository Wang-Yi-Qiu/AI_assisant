/**
 * 登录页：用户认证
 * @module LoginPage
 */

import { authService, SignInCredentials, SignUpCredentials } from '../utils/authService';
import router from '@ohos.router';

@Entry
@Component
struct LoginPage {
  @State isSignInMode: boolean = true;
  @State email: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';

  build() {
    Scroll() {
      Column() {
        // 顶部标题
        Column() {
          Image($r('app.media.startIcon'))
            .width(80)
            .height(80)
            .margin({ bottom: 16 })

          Text(this.isSignInMode ? '欢迎回来' : '创建账号')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 8 })

          Text(this.isSignInMode ? '请登录以继续使用智能图表助手' : '注册账号开始使用智能图表助手')
            .fontSize(14)
            .fontColor('#666666')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ top: 60, bottom: 40 })
        .backgroundColor('#F5F5F5')

        // 表单区域
        Column() {
          // 邮箱输入
          Column() {
            Text('邮箱地址')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 8 })

            TextInput({ placeholder: '请输入邮箱地址' })
              .width('100%')
              .height(48)
              .fontSize(16)
              .borderRadius(8)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E0E0E0' })
              .onChange((value: string) => {
                this.email = value.trim();
                this.errorMessage = '';
              })
          }
          .width('100%')
          .margin({ bottom: 20 })

          // 密码输入
          Column() {
            Text('密码')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 8 })

            TextInput({ placeholder: '请输入密码' })
              .width('100%')
              .height(48)
              .fontSize(16)
              .borderRadius(8)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E0E0E0' })
              .type(InputType.Password)
              .onChange((value: string) => {
                this.password = value;
                this.errorMessage = '';
              })
          }
          .width('100%')
          .margin({ bottom: 32 })

          // 错误提示
          if (this.errorMessage) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor('#F44336')
              .backgroundColor('#FFEBEE')
              .padding(12)
              .borderRadius(8)
              .width('100%')
              .margin({ bottom: 20 })
          }

          // 提交按钮
          Button(this.isSignInMode ? '登录' : '注册')
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .borderRadius(8)
            .backgroundColor('#1976D2')
            .fontColor(Color.White)
            .enabled(!this.isLoading && this.email.length > 0 && this.password.length > 0)
            .onClick(() => {
              this.handleSubmit();
            })

          // 切换登录/注册模式
          Row() {
            Text(this.isSignInMode ? '还没有账号？' : '已有账号？')
              .fontSize(14)
              .fontColor('#666666')

            Button(this.isSignInMode ? '立即注册' : '立即登录')
              .type(ButtonType.Normal)
              .fontSize(14)
              .fontColor('#1976D2')
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.isSignInMode = !this.isSignInMode;
                this.errorMessage = '';
              })
          }
          .width('100%')
          .margin({ top: 20 })
        }
        .width('100%')
        .padding(24)
        .backgroundColor('#FFFFFF')
        .margin({ left: 16, right: 16, bottom: 20 })

        // 加载状态
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .margin({ bottom: 8 })
            Text(this.isSignInMode ? '正在登录...' : '正在注册...')
              .fontSize(14)
              .fontColor('#666666')
          }
          .width('100%')
          .padding(20)
        }

        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
  }

  /**
   * 处理表单提交
   */
  private async handleSubmit() {
    if (!this.validateForm()) {
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      const credentials = {
        email: this.email,
        password: this.password
      };

      if (this.isSignInMode) {
        const result = await authService.signIn(credentials);
        if (result.error) {
          this.errorMessage = result.error.message;
        } else {
          await this.navigateToHome();
        }
      } else {
        const result = await authService.signUp(credentials);
        if (result.error) {
          this.errorMessage = result.error.message;
        } else {
          await this.navigateToHome();
        }
      }
    } catch (error) {
      console.error('认证失败:', error);
      this.errorMessage = error instanceof Error ? error.message : `${this.isSignInMode ? '登录' : '注册'}失败，请稍后重试`;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 验证表单
   */
  private validateForm(): boolean {
    if (!this.email) {
      this.errorMessage = '请输入邮箱地址';
      return false;
    }

    if (!this.isValidEmail(this.email)) {
      this.errorMessage = '请输入有效的邮箱地址';
      return false;
    }

    if (!this.password) {
      this.errorMessage = '请输入密码';
      return false;
    }

    if (this.password.length < 6) {
      this.errorMessage = '密码长度至少为6位';
      return false;
    }

    return true;
  }

  /**
   * 验证邮箱格式
   */
  private isValidEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  /**
   * 导航到首页
   */
  private async navigateToHome() {
    try {
      await router.replaceUrl({
        url: 'pages/Index'
      });
    } catch (error) {
      console.error('导航失败:', error);
      this.errorMessage = '页面跳转失败';
    }
  }

  aboutToAppear() {
    // 检查是否已经登录
    this.checkAuthState();
  }

  /**
   * 检查认证状态
   */
  private async checkAuthState() {
    try {
      const authState = authService.getAuthState();
      if (authState.isAuthenticated) {
        await router.replaceUrl({
          url: 'pages/Index'
        });
      }
    } catch (error) {
      console.error('检查认证状态失败:', error);
    }
  }
}