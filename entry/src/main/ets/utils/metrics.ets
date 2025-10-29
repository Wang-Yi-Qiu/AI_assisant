/**
 * 简易性能度量与结构化日志
 */

export interface Timer {
  id: string;
  start: number;
}

export function startTimer(id: string): Timer {
  const result: Timer = { id, start: Date.now() };
  return result;
}

export interface LogPayload {
  action: string;
  duration: number;
  timestamp: string;
  requestId?: string;
  ok?: boolean;
  code?: string;
  error?: string;
}

export function endTimer(timer: Timer, extra?: LogPayload): number {
  const duration = Date.now() - timer.start;
  const base: LogPayload = { action: timer.id, duration, timestamp: new Date().toISOString() };
  const finalPayload: LogPayload = {
    action: base.action,
    duration: base.duration,
    timestamp: base.timestamp,
    requestId: extra?.requestId,
    ok: extra?.ok,
    code: extra?.code,
    error: extra?.error,
  };
  console.log(JSON.stringify(finalPayload));
  return duration;
}

export function newRequestId(): string {
  // 简易 UUID（非加密）
  return 'req_' + Math.random().toString(36).slice(2) + Date.now().toString(36);
}
