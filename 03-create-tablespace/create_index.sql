--psql -h 127.0.0.1 -p 9867 -U rmb -d illgreennews

CREATE INDEX idx_comments_article ON comments(article_id) TABLESPACE eks68;

SELECT 
    indexname,
    tablename,
    tablespace
FROM pg_indexes 
WHERE tablename = 'comments';