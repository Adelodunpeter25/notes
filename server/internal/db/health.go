package db

import (
	"context"
	"database/sql"
	"sync"
	"time"
)

type HealthPoller struct {
	db      *sql.DB
	timeout time.Duration

	mu    sync.RWMutex
	alive bool
}

func NewHealthPoller(sqlDB *sql.DB, timeout time.Duration) *HealthPoller {
	return &HealthPoller{db: sqlDB, timeout: timeout, alive: false}
}

func (poller *HealthPoller) Start(ctx context.Context, interval time.Duration) {
	poller.checkOnce(ctx)

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			poller.checkOnce(ctx)
		}
	}
}

func (poller *HealthPoller) IsAlive() bool {
	poller.mu.RLock()
	defer poller.mu.RUnlock()
	return poller.alive
}

func (poller *HealthPoller) checkOnce(ctx context.Context) {
	checkCtx, cancel := context.WithTimeout(ctx, poller.timeout)
	defer cancel()

	err := poller.db.PingContext(checkCtx)

	poller.mu.Lock()
	poller.alive = err == nil
	poller.mu.Unlock()
}
