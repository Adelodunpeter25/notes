export type ReconnectOptions = {
  baseDelayMs?: number;
  maxDelayMs?: number;
  factor?: number;
  jitterRatio?: number;
};

const DEFAULTS: Required<ReconnectOptions> = {
  baseDelayMs: 500,
  maxDelayMs: 10_000,
  factor: 2,
  jitterRatio: 0.2,
};

export function getReconnectDelay(attempt: number, options?: ReconnectOptions): number {
  const config = { ...DEFAULTS, ...options };
  const safeAttempt = Math.max(0, attempt);
  const exponential = Math.min(
    config.maxDelayMs,
    config.baseDelayMs * Math.pow(config.factor, safeAttempt),
  );

  const jitter = exponential * config.jitterRatio;
  const min = Math.max(0, exponential - jitter);
  const max = exponential + jitter;

  return Math.round(min + Math.random() * (max - min));
}

