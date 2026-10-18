-- Runs once, on the first start with an empty data volume, inside
-- MYSQL_DATABASE (created and granted to MYSQL_USER by the image).
CREATE TABLE notes (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  body       TEXT        NOT NULL,
  created_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

INSERT INTO notes (body) VALUES ('hello from init/01-sample-schema.sql');
