import { getStorageInstance } from './preferencesStorage';

/**
 * 任务数据结构
 */
export class Task {
  id: number;
  text: string;
  completed: boolean;
  createdAt: number;

  constructor(id: number, text: string, completed: boolean = false) {
    this.id = id;
    this.text = text;
    this.completed = completed;
    this.createdAt = Date.now();
  }
}

/**
 * 今日任务统计接口
 */
export interface TodayStats {
  total: number;
  completed: number;
}

/**
 * 任务管理服务
 */
export class TaskManager {
  private static instance: TaskManager | null = null;
  private storage = getStorageInstance();
  private tasks: Task[] = [];

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): TaskManager {
    if (!TaskManager.instance) {
      TaskManager.instance = new TaskManager();
    }
    return TaskManager.instance;
  }

  /**
   * 初始化任务管理器
   */
  async initialize(): Promise<void> {
    try {
      await this.loadTasks();
      console.info('TaskManager: Initialized successfully');
    } catch (error) {
      console.error('TaskManager: Failed to initialize', error);
    }
  }

  /**
   * 加载任务
   */
  private async loadTasks(): Promise<void> {
    try {
      this.tasks = await this.storage.getObject('tasks', []);
      console.info(`TaskManager: Loaded ${this.tasks.length} tasks`);
    } catch (error) {
      console.error('TaskManager: Failed to load tasks', error);
      this.tasks = [];
    }
  }

  /**
   * 保存任务
   */
  private async saveTasks(): Promise<void> {
    try {
      await this.storage.saveObject('tasks', this.tasks);
      console.info(`TaskManager: Saved ${this.tasks.length} tasks`);
    } catch (error) {
      console.error('TaskManager: Failed to save tasks', error);
    }
  }

  /**
   * 获取所有任务
   */
  getTasks(): Task[] {
    return [...this.tasks]; // 返回副本，避免外部修改
  }

  /**
   * 获取未完成的任务
   */
  getIncompleteTasks(): Task[] {
    return this.tasks.filter(task => !task.completed);
  }

  /**
   * 获取已完成的任务
   */
  getCompletedTasks(): Task[] {
    return this.tasks.filter(task => task.completed);
  }

  /**
   * 添加任务
   */
  async addTask(text: string): Promise<Task> {
    // 简单验证
    if (!text || text.trim() === '') {
      throw new Error('Task text cannot be empty');
    }

    if (text.trim().length > 200) {
      throw new Error('Task text too long (max 200 characters)');
    }

    const cleanText = text.trim();
    const newId = this.tasks.length > 0 ? Math.max(...this.tasks.map(t => t.id)) + 1 : 1;
    const newTask = new Task(newId, cleanText, false);
    this.tasks.push(newTask);

    await this.saveTasks();
    console.info(`TaskManager: Added task "${cleanText}" with id ${newId}`);

    return newTask;
  }

  /**
   * 删除任务
   */
  async deleteTask(taskId: number): Promise<boolean> {
    // 简单验证
    if (typeof taskId !== 'number' || taskId <= 0 || !Number.isInteger(taskId)) {
      throw new Error('Invalid task ID');
    }

    const initialLength = this.tasks.length;
    this.tasks = this.tasks.filter(task => task.id !== taskId);

    if (this.tasks.length < initialLength) {
      await this.saveTasks();
      console.info(`TaskManager: Deleted task with id ${taskId}`);
      return true;
    }

    return false;
  }

  /**
   * 切换任务完成状态
   */
  async toggleTaskComplete(taskId: number): Promise<boolean> {
    // 简单验证
    if (typeof taskId !== 'number' || taskId <= 0 || !Number.isInteger(taskId)) {
      throw new Error('Invalid task ID');
    }

    const task = this.tasks.find(t => t.id === taskId);
    if (task) {
      task.completed = !task.completed;
      await this.saveTasks();
      console.info(`TaskManager: Toggled task ${taskId} completion to ${task.completed}`);
      return true;
    }
    return false;
  }

  /**
   * 更新任务文本
   */
  async updateTaskText(taskId: number, newText: string): Promise<boolean> {
    // 简单验证
    if (typeof taskId !== 'number' || taskId <= 0 || !Number.isInteger(taskId)) {
      throw new Error('Invalid task ID');
    }

    if (!newText || newText.trim() === '') {
      throw new Error('Task text cannot be empty');
    }

    if (newText.trim().length > 200) {
      throw new Error('Task text too long (max 200 characters)');
    }

    const cleanText = newText.trim();
    const task = this.tasks.find(t => t.id === taskId);
    if (task) {
      task.text = cleanText;
      await this.saveTasks();
      console.info(`TaskManager: Updated task ${taskId} text to "${cleanText}"`);
      return true;
    }
    return false;
  }

  /**
   * 清除所有已完成的任务
   */
  async clearCompletedTasks(): Promise<number> {
    const initialLength = this.tasks.length;
    this.tasks = this.tasks.filter(task => !task.completed);

    if (this.tasks.length < initialLength) {
      const clearedCount = initialLength - this.tasks.length;
      await this.saveTasks();
      console.info(`TaskManager: Cleared ${clearedCount} completed tasks`);
      return clearedCount;
    }

    return 0;
  }

  /**
   * 清除所有任务
   */
  async clearAllTasks(): Promise<void> {
    this.tasks = [];
    await this.saveTasks();
    console.info('TaskManager: Cleared all tasks');
  }

  /**
   * 获取当前选中的任务（第一个未完成的任务）
   */
  getCurrentSelectedTask(): Task | null {
    return this.tasks.find(task => !task.completed) || null;
  }

  /**
   * 获取今日任务统计
   */
  getTodayStats(): TodayStats {
    const today = new Date().toDateString();
    const todayTasks = this.tasks.filter(task => {
      const taskDate = new Date(task.createdAt).toDateString();
      return taskDate === today;
    });

    const completed = todayTasks.filter(task => task.completed).length;

    const stats: TodayStats = {
      total: todayTasks.length,
      completed: completed
    };
    return stats;
  }
}