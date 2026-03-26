-- psql -h 127.0.0.1 -p 9867 -U postgres2 -d postgres
CREATE ROLE rmb WITH LOGIN PASSWORD 'admin';

CREATE DATABASE illgreennews TEMPLATE template1 OWNER rmb;

GRANT CONNECT ON DATABASE illgreennews TO rmb;

GRANT CREATE ON TABLESPACE eks68 TO rmb;

\l