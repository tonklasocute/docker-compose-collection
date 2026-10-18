import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PG_POOL, REDIS } from '../database/database.module.js';
import { NotesService, type Note } from './notes.service.js';

const note: Note = {
  id: 1,
  title: 'hello',
  body: '',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
};

describe('NotesService', () => {
  let service: NotesService;
  const pool = { query: vi.fn() };
  const cache = new Map<string, string>();
  const redis = {
    get: vi.fn(async (k: string) => cache.get(k) ?? null),
    set: vi.fn(async (k: string, v: string) => void cache.set(k, v)),
    del: vi.fn(async (k: string) => void cache.delete(k)),
  };

  beforeEach(async () => {
    vi.clearAllMocks();
    cache.clear();
    const moduleRef = await Test.createTestingModule({
      providers: [NotesService, { provide: PG_POOL, useValue: pool }, { provide: REDIS, useValue: redis }],
    }).compile();
    service = moduleRef.get(NotesService);
  });

  it('reads from the database on a miss, then serves from Redis', async () => {
    pool.query.mockResolvedValueOnce({ rows: [note] });

    await expect(service.get(1)).resolves.toEqual({ note, cache: 'MISS' });
    await expect(service.get(1)).resolves.toEqual({ note, cache: 'HIT' });
    expect(pool.query).toHaveBeenCalledTimes(1);
  });

  it('throws NotFound for a missing note and caches nothing', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    await expect(service.get(42)).rejects.toBeInstanceOf(NotFoundException);
    expect(redis.set).not.toHaveBeenCalled();
  });

  it('invalidates the cache on update', async () => {
    cache.set('note:1', JSON.stringify(note));
    pool.query.mockResolvedValueOnce({ rows: [{ ...note, title: 'changed' }] });

    await service.update(1, { title: 'changed' });
    expect(cache.has('note:1')).toBe(false);
  });

  it('throws NotFound when deleting a missing note', async () => {
    pool.query.mockResolvedValueOnce({ rowCount: 0 });

    await expect(service.remove(7)).rejects.toBeInstanceOf(NotFoundException);
  });
});
