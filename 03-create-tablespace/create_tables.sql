-- psql -h 127.0.0.1 -p 9867 -U rmb -d illgreennews
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE comments (
    id SERIAL,  
    article_id INTEGER REFERENCES articles(id),
    author TEXT,
    body TEXT
);
\dt