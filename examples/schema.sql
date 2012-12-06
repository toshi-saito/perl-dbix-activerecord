CREATE TABLE categories (
  id serial,
  name varchar(255) NOT NULL,
  created_at datetime NOT NULL
);

CREATE TABLE posts (
  id serial,
  category_id bigint NOT NULL,
  title varchar(255) NOT NULL,
  content text,
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL
);

CREATE TABLE comments (
  id serial,
  post_id bigint NOT NULL,
  content text,
  created_at datetime NOT NULL
);
