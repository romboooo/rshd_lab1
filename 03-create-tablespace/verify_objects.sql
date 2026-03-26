-- psql -h 127.0.0.1 -p 9867 -U postgres2 -d postgres

\db+

SELECT 
    n.nspname AS schema,
    c.relname AS object_name,
    CASE c.relkind 
        WHEN 'i' THEN 'INDEX'
        WHEN 'r' THEN 'TABLE'
        ELSE 'OTHER'
    END AS object_type,
    t.spcname AS tablespace
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_tablespace t ON t.oid = c.reltablespace
WHERE t.spcname = 'eks68';

\c illgreennews
SELECT * FROM articles;
SELECT * FROM comments;