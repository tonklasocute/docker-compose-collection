#!/bin/sh
# Runs once, on the first start with an empty data volume.
# Creates an application role + database (from APP_DB_* in .env) so apps don't
# connect as the superuser, plus a small sample table to query.
set -eu

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -v app_user="$APP_DB_USER" -v app_password="$APP_DB_PASSWORD" -v app_db="$APP_DB_NAME" <<'SQL'
CREATE ROLE :"app_user" WITH LOGIN PASSWORD :'app_password';
CREATE DATABASE :"app_db" OWNER :"app_user";
SQL

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$APP_DB_NAME" -v app_user="$APP_DB_USER" <<'SQL'
SET ROLE :"app_user";
CREATE TABLE notes (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  body       text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO notes (body) VALUES ('hello from init/01-create-app-db.sh');
SQL
