/**
 * UUID生成工具
 * 提供简单的UUID生成功能用于缓存键生成等场景
 */

/**
 * 生成UUID (版本4)
 */
export function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

/**
 * 生成短UUID（更短的唯一标识符）
 */
export function generateShortUUID(): string {
  return Math.random().toString(36).substr(2, 9);
}

/**
 * 生成时间戳UUID
 */
export function generateTimestampUUID(): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substr(2, 5);
  return `${timestamp}_${random}`;
}