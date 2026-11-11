-- Schéma partagé par les quatre API. Exécuté par l'image postgres à la première
-- création du volume (docker-entrypoint-initdb.d). Pour le rejouer : docker compose down -v
CREATE TABLE IF NOT EXISTS tasks (
    id          SERIAL PRIMARY KEY,
    title       TEXT        NOT NULL,
    done        BOOLEAN     NOT NULL DEFAULT FALSE,
    created_by  TEXT        NOT NULL DEFAULT 'init',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO tasks (title, created_by) VALUES
    ('Écrire le Dockerfile',            'init'),
    ('Publier l''image dans Gitea',     'init'),
    ('Comparer les quatre API',         'init');
