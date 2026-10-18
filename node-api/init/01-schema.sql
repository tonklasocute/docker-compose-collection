-- Runs once, when the postgres data volume is empty (docker-entrypoint-initdb.d).
-- For evolving schemas, swap this for a migration tool (node-pg-migrate,
-- Prisma Migrate, TypeORM migrations) run as a one-shot service like go-api's.
CREATE TABLE notes (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title      text        NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  body       text        NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
