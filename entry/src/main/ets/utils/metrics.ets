/**
 * 简易性能度量与结构化日志
 */

export type Timer = { id: string; start: number };

export function startTimer(id: string): Timer {
  return { id, start: Date.now() };
}

export function endTimer(timer: Timer, extra?: Record<string, unknown>): number {
  const duration = Date.now() - timer.start;
  const payload = { action: timer.id, duration, timestamp: new Date().toISOString(), ...(extra || {}) };
  console.log(JSON.stringify(payload));
  return duration;
}

export function newRequestId(): string {
  // 简易 UUID（非加密）
  return 'req_' + Math.random().toString(36).slice(2) + Date.now().toString(36);
}


