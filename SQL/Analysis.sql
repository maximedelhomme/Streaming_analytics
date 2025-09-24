/* MAU / WAU / DAU */
SELECT
  to_char(date_trunc('month', start_ts), 'yyyy-mm') AS period_start,
  COUNT(DISTINCT user_id)       AS mau
FROM sessions
GROUP BY 1
ORDER BY 1 DESC;

SELECT 
	to_char(date_trunc('week', start_ts), 'yyyy-mm-dd') as week, 
	COUNT(DISTINCT user_id) as WAU
FROM 
	sessions
GROUP BY 
	1
ORDER BY 
	1 DESC;

SELECT 
	to_char(date_trunc('day', start_ts), 'yyyy-mm-dd') as day, 
	COUNT(DISTINCT user_id) as DAU
FROM 
	sessions
GROUP BY 
	1
ORDER BY 
	1 DESC;

/* Watchtime mensuel par genre */
Select 
	to_char(date_trunc('month', start_ts), 'iyyy-iw') as period_start, 
	c.genre, 
	ROUND(SUM(s.watch_sec) :: NUMERIC / 3600, 2) as watch_hours
from sessions s
join content c
on s.content_id = c.content_id
GROUP BY
	1, 2
ORDER BY 
	watch_hours DESC;

/* Top 10 contenus du mois le plus récent */
WITH m AS (
  SELECT date_trunc('month', MAX(start_ts)) AS month_start
  FROM sessions
)
SELECT
  c.content_id,
  c.title,
  ROUND(SUM(s.watch_sec)::numeric / 3600, 2)                                   AS watch_hours,
  ROUND(AVG(LEAST(s.watch_sec::numeric / NULLIF(c.duration_sec, 0), 1))::numeric, 3) AS completion_rate
FROM sessions s
JOIN content c     ON c.content_id = s.content_id
CROSS JOIN m
WHERE s.start_ts >= m.month_start
  AND s.start_ts <  m.month_start + INTERVAL '1 month'
GROUP BY c.content_id, c.title
ORDER BY watch_hours DESC, completion_rate DESC, c.title ASC
LIMIT 10;

/* Trial → Pay (taux de conversion) */
WITH trials AS (
  SELECT user_id, MIN(event_ts) AS trial_start
  FROM events
  WHERE event_type = 'trial_start'
  GROUP BY user_id
),
conversions AS (
  SELECT user_id, MIN(event_ts) AS conv_ts
  FROM events
  WHERE event_type = 'conversion'
  GROUP BY user_id
),
joined AS (
  SELECT
    t.user_id,
    t.trial_start,
    c.conv_ts,
    (c.user_id IS NOT NULL AND c.conv_ts >= t.trial_start) AS converted_flag
  FROM trials t
  LEFT JOIN conversions c
    ON c.user_id = t.user_id
)
SELECT
  COUNT(*) AS trial_users,
  COUNT(*) FILTER (WHERE converted_flag) AS converted,
  ROUND(
    COUNT(*) FILTER (WHERE converted_flag)::numeric
    / NULLIF(COUNT(*), 0),
    3
  ) AS conversion_rate
FROM joined;

/* Cohortes mensuelles (mois inscription vs mois d’activité) */
WITH cohort as (
	SELECT e.user_id, date_trunc('month', MIN(e.event_ts)) AS cohort_month
	FROM events e
	WHERE e.event_type IN ('signup', 'trial_start')
	GROUP BY user_id
),
activity as (
	SELECT DISTINCT s.user_id, date_trunc('month', s.start_ts) AS active_month
	FROM sessions s
),
joined as (
	SELECT a.user_id, c.cohort_month, a.active_month
	FROM activity a
	JOIN cohort c
	ON a.user_id = c.user_id
	WHERE a.active_month >= c.cohort_month
),
with_index AS (
	SELECT user_id, cohort_month, active_month, (
	EXTRACT(YEAR FROM age(active_month, cohort_month)) :: int * 12
	+ EXTRACT (MONTH FROM age(active_month, cohort_month)) :: int
	) AS month_index
	FROM joined
)
SELECT
	cohort_month, month_index, COUNT(DISTINCT user_id) AS active_users
FROM with_index
GROUP BY 1, 2
ORDER BY 1, 2;

/* Stickiness = DAU/MAU par mois */
WITH dau_daily AS (
  SELECT
    date_trunc('day', start_ts) AS day_start,
    COUNT(DISTINCT user_id) AS dau
  FROM sessions
  GROUP BY 1
),
dau_month AS (
  SELECT
    date_trunc('month', day_start) AS period_start,
    AVG(dau)::numeric AS avg_dau   
  FROM dau_daily
  GROUP BY 1
),
mau_month AS (
  SELECT
    date_trunc('month', start_ts) AS period_start,
    COUNT(DISTINCT user_id) AS mau
  FROM sessions
  GROUP BY 1
)
SELECT
  m.period_start AS month_start,
  ROUND(d.avg_dau, 2) AS avg_dau,
  m.mau,
  ROUND(d.avg_dau / NULLIF(m.mau, 0), 3) AS stickiness
FROM mau_month m
JOIN dau_month d ON d.period_start = m.period_start
ORDER BY month_start;

/* Churn mensuel */
WITH months AS (
  SELECT DISTINCT date_trunc('month', date_) AS month_start
  FROM date_dim
),
conv AS (
  SELECT user_id, MIN(event_ts) AS conv_ts
  FROM events
  WHERE event_type = 'conversion'
  GROUP BY user_id
),
cancels AS (
  SELECT date_trunc('month', event_ts) AS month_start,
         COUNT(*) AS cancels
  FROM events
  WHERE event_type = 'cancel'
  GROUP BY 1
),
base_start AS (
  SELECT
    m.month_start,
    COUNT(*) AS paid_base_start
  FROM months m
  JOIN conv v ON v.conv_ts <  m.month_start 
  JOIN subscribers s ON s.user_id = v.user_id
  WHERE (s.cancel_date IS NULL OR s.cancel_date >= m.month_start)
  GROUP BY 1
)
SELECT
  m.month_start AS month,
  COALESCE(c.cancels, 0) AS cancels,
  COALESCE(b.paid_base_start, 0) AS paid_base_start,
  ROUND(
    COALESCE(c.cancels,0)::numeric / NULLIF(COALESCE(b.paid_base_start,0),0)
  , 4) AS churn_rate
FROM months m
LEFT JOIN cancels c USING (month_start)
LEFT JOIN base_start b USING (month_start)
ORDER BY month;

/* Mix devices par mois */
WITH counts AS (
  SELECT
    date_trunc('month', start_ts) AS month_start,
    device,
    COUNT(*) AS sessions
  FROM sessions
  GROUP BY 1, 2
)
SELECT
  month_start,
  device,
  sessions,
  ROUND(
    sessions::numeric
    / NULLIF(SUM(sessions) OVER (PARTITION BY month_start), 0),
    3
  ) AS share
FROM counts
ORDER BY month_start, device;

/* Live vs VOD */
WITH counts AS (
  SELECT date_trunc('month', start_ts) AS month_start,
         CASE WHEN is_live_view THEN 'Live' ELSE 'VOD' END AS stream_type,
         COUNT(*) AS sessions
  FROM sessions
  GROUP BY 1, 2
)
SELECT
  month_start,
  stream_type,
  sessions,
  ROUND(
    sessions::numeric
    / NULLIF(SUM(sessions) OVER (PARTITION BY month_start), 0)
  , 3) AS share
FROM counts
ORDER BY month_start, stream_type DESC;

/* Segments plan (Basic/Standard/Premium/TrialOnly) */
SELECT 
  date_trunc('month', s.start_ts) AS month_start,
  su.plan,
  COUNT(DISTINCT s.user_id) AS users_active,
  ROUND( SUM(s.watch_sec)::numeric 
         / NULLIF(COUNT(DISTINCT s.user_id), 0), 2) AS watch_sec_per_user,
  ROUND( (SUM(s.watch_sec)::numeric / 3600)
         / NULLIF(COUNT(DISTINCT s.user_id), 0), 2) AS watch_hours_per_user
FROM sessions s
JOIN subscribers su USING (user_id)
GROUP BY 1, 2
ORDER BY 1, 2;