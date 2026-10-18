import { Controller, Get, HttpStatus, Inject, Res } from '@nestjs/common';
import type { Response } from 'express';
import pg from 'pg';
import { PG_POOL, REDIS, type RedisClient } from '../database/database.module.js';
import { VERSION } from '../version.js';

type Check = 'ok' | string;

@Controller('health')
export class HealthController {
  constructor(
    @Inject(PG_POOL) private readonly pool: pg.Pool,
    @Inject(REDIS) private readonly redis: RedisClient,
  ) {}

  /** 200 when PostgreSQL and Redis both answer, 503 otherwise. */
  @Get()
  async check(@Res({ passthrough: true }) res: Response) {
    const [db, cache] = await Promise.all([
      this.probe(() => this.pool.query('SELECT 1')),
      this.probe(() => this.redis.ping()),
    ]);
    const ok = db === 'ok' && cache === 'ok';
    res.status(ok ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE);
    return { status: ok ? 'ok' : 'unavailable', db, redis: cache, version: VERSION };
  }

  private async probe(fn: () => Promise<unknown>): Promise<Check> {
    try {
      await fn();
      return 'ok';
    } catch (err) {
      return err instanceof Error ? err.message : String(err);
    }
  }
}
