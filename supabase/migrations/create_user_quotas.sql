-- 创建用户配额表
-- 用于管理没有 API Key 的用户的免费调用次数

CREATE TABLE IF NOT EXISTS public.user_quotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL, -- 用户ID（可以是匿名用户ID或认证用户ID）
  total_quota INTEGER NOT NULL DEFAULT 10, -- 总配额（默认10次）
  used_quota INTEGER NOT NULL DEFAULT 0, -- 已使用配额
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id) -- 每个用户只能有一条配额记录
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_user_quotas_user_id ON public.user_quotas(user_id);

-- 创建更新时间触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_quotas_updated_at
  BEFORE UPDATE ON public.user_quotas
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 启用 RLS（行级安全）
ALTER TABLE public.user_quotas ENABLE ROW LEVEL SECURITY;

-- RLS 策略：用户可以查看自己的配额
CREATE POLICY user_quotas_select_own ON public.user_quotas
  FOR SELECT
  USING (true); -- 允许所有用户查看（因为需要检查配额）

-- RLS 策略：系统可以更新配额（通过 Edge Functions）
CREATE POLICY user_quotas_update_own ON public.user_quotas
  FOR UPDATE
  USING (true); -- 允许更新（Edge Functions 会使用 service_role key）

-- 注释
COMMENT ON TABLE public.user_quotas IS '用户 API 调用配额表，用于管理免费试用次数';
COMMENT ON COLUMN public.user_quotas.user_id IS '用户ID，可以是匿名用户ID或认证用户ID';
COMMENT ON COLUMN public.user_quotas.total_quota IS '总配额，默认10次免费调用';
COMMENT ON COLUMN public.user_quotas.used_quota IS '已使用的配额次数';

