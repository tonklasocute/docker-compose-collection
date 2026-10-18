import { Global, Inject, Logger, Module, OnApplicationShutdown } from '@nestjs/common';
import pg from 'pg';
import { createClient } from '@redis/client';

export const PG_POOL = Symbol('PG_POOL');
export const REDIS = Symbol('REDIS');

export type RedisClient = ReturnType<typeof createClient>;

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

/** Shared PostgreSQL pool and Redis client, injectable anywhere. */
@Global()
@Module({
  providers: [
    {
      provide: PG_POOL,
      useFactory: () => new pg.Pool({ connectionString: required('DATABASE_URL'), max: 10 }),
    },
    {
      provide: REDIS,
      useFactory: async () => {
        const client = createClient({ url: required('REDIS_URL') });
        client.on('error', (err: Error) => new Logger('Redis').error(err.message));
        await client.connect();
        return client;
      },
    },
  ],
  exports: [PG_POOL, REDIS],
})
export class DatabaseModule implements OnApplicationShutdown {
  constructor(
    @Inject(PG_POOL) private readonly pool: pg.Pool,
    @Inject(REDIS) private readonly redis: RedisClient,
  ) {}

  async onApplicationShutdown() {
    await Promise.allSettled([this.pool.end(), this.redis.close()]);
  }
}
