CREATE TABLE subscribers(
  user_id INT PRIMARY KEY,
  plan TEXT, country TEXT, start_date DATE, cancel_date DATE,
  acquisition_channel TEXT, email_opt_in BOOLEAN
);
CREATE TABLE content(
  content_id INT PRIMARY KEY,
  title TEXT, genre TEXT, subgenre TEXT, duration_sec INT,
  release_date TIMESTAMP, rating NUMERIC(2,1), is_live BOOLEAN, language TEXT, popularity_w NUMERIC
);
CREATE TABLE sessions(
  session_id INT PRIMARY KEY,
  user_id INT REFERENCES subscribers(user_id),
  content_id INT REFERENCES content(content_id),
  start_ts TIMESTAMP, watch_sec INT, device TEXT,
  autoplay BOOLEAN, is_live_view BOOLEAN, country TEXT
);
CREATE TABLE events(
  event_id INT PRIMARY KEY,
  user_id INT REFERENCES subscribers(user_id),
  event_ts TIMESTAMP, event_type TEXT, attribution_campaign TEXT
);
CREATE TABLE date_dim(
	date_ DATE PRIMARY KEY,
	year INT,
	month INT,
	week INT,
	dayofweek INT,
	is_month_start BOOLEAN,
	is_month_end BOOLEAN
)