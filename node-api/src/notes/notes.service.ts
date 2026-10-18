import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import pg from 'pg';
import { PG_POOL, REDIS, type RedisClient } from '../database/database.module.js';
import type { CreateNoteDto, UpdateNoteDto } from './notes.dto.js';

export interface Note {
  id: number;
  title: string;
  body: string;
  created_at: string;
  updated_at: string;
}

export type CacheStatus = 'HIT' | 'MISS';

const COLUMNS = 'id, title, body, created_at, updated_at';

/**
 * Notes in PostgreSQL with a cache-aside layer in Redis: single-note reads
 * are cached for CACHE_TTL_SECONDS and invalidated on update/delete.
 */
@Injectable()
export class NotesService {
  private readonly ttl = Number(process.env.CACHE_TTL_SECONDS ?? 60);

  constructor(
    @Inject(PG_POOL) private readonly pool: pg.Pool,
    @Inject(REDIS) private readonly redis: RedisClient,
  ) {}

  private key(id: number) {
    return `note:${id}`;
  }

  async list(limit: number, offset: number): Promise<Note[]> {
    const { rows } = await this.pool.query<Note>(
      `SELECT ${COLUMNS} FROM notes ORDER BY id DESC LIMIT $1 OFFSET $2`,
      [limit, offset],
    );
    return rows;
  }

  async get(id: number): Promise<{ note: Note; cache: CacheStatus }> {
    const cached = await this.redis.get(this.key(id));
    if (cached) return { note: JSON.parse(cached) as Note, cache: 'HIT' };

    const { rows } = await this.pool.query<Note>(`SELECT ${COLUMNS} FROM notes WHERE id = $1`, [id]);
    if (rows.length === 0) throw new NotFoundException(`note ${id} not found`);
    await this.redis.set(this.key(id), JSON.stringify(rows[0]), { expiration: { type: 'EX', value: this.ttl } });
    return { note: rows[0], cache: 'MISS' };
  }

  async create(dto: CreateNoteDto): Promise<Note> {
    const { rows } = await this.pool.query<Note>(
      `INSERT INTO notes (title, body) VALUES ($1, $2) RETURNING ${COLUMNS}`,
      [dto.title, dto.body ?? ''],
    );
    return rows[0];
  }

  async update(id: number, dto: UpdateNoteDto): Promise<Note> {
    const { rows } = await this.pool.query<Note>(
      `UPDATE notes
          SET title = COALESCE($2, title), body = COALESCE($3, body), updated_at = now()
        WHERE id = $1
        RETURNING ${COLUMNS}`,
      [id, dto.title ?? null, dto.body ?? null],
    );
    if (rows.length === 0) throw new NotFoundException(`note ${id} not found`);
    await this.redis.del(this.key(id));
    return rows[0];
  }

  async remove(id: number): Promise<void> {
    const { rowCount } = await this.pool.query('DELETE FROM notes WHERE id = $1', [id]);
    if (!rowCount) throw new NotFoundException(`note ${id} not found`);
    await this.redis.del(this.key(id));
  }
}
