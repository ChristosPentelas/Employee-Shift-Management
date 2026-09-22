-- F13: indexes that cover each list query's filter AND its sort.
--
-- Until now each table had only the index MySQL creates for a foreign key,
-- e.g. messages(receiver_id). That finds a user's rows, but then every one of
-- them has to be sorted ("Using filesort") before the first page of 20 can be
-- returned. An index on (receiver_id, timestamp) keeps each user's rows
-- already in time order, so MySQL reads the first 20 and stops.
--
-- The sort's last key, id, needs no column here: every InnoDB secondary index
-- ends with the primary key, so (receiver_id, timestamp) is really
-- (receiver_id, timestamp, id). Descending sorts read the index backwards.
--
-- Each new index starts with the foreign key column, so it can also do the
-- old single-column index's job; the old one is then dropped, since every
-- index is extra work on every INSERT. The ADD comes before the DROP in the
-- same statement: MySQL refuses to drop the last index a foreign key can use.
--
-- Not indexed on purpose: the unfiltered list of all leave requests. That
-- table stays small, and an index is only worth its write cost if a query
-- that actually runs needs it.
--
-- MySQL chooses per query whether an index is worth it. On a small table it
-- may still scan everything and sort, because that is cheaper than the index
-- lookups; with 5,000 news items it ignored idx_news_created, with 100,000
-- it used it and read 20 rows. So EXPLAIN on a nearly empty dev database says
-- little about these indexes.

ALTER TABLE `messages`
    ADD INDEX `idx_messages_receiver_timestamp` (`receiver_id`, `timestamp`),  -- inbox, unread
    ADD INDEX `idx_messages_sender_timestamp` (`sender_id`, `timestamp`),      -- sent
    -- The chat is "7 to 8 OR 8 to 7": two ranges of this index, which MySQL
    -- still merges with a small sort - but over the conversation's own rows,
    -- not every message either user ever received.
    ADD INDEX `idx_messages_chat` (`sender_id`, `receiver_id`, `timestamp`),
    DROP INDEX `FKm8wkvh2tbxksve6eadxk6khgw`,
    DROP INDEX `FK4ui4nnwntodh6wjvck53dbk9m`;

ALTER TABLE `shifts`
    ADD INDEX `idx_shifts_user_date` (`user_id`, `date`, `start_time`),  -- one employee's history and schedule
    ADD INDEX `idx_shifts_date` (`date`, `start_time`),                  -- the calendar
    DROP INDEX `FK3dq4k4tt0x91h7kkabwrrkyho`;

ALTER TABLE `leaves_requests`
    ADD INDEX `idx_leaves_user_start` (`user_id`, `start_date`),   -- one employee's requests
    ADD INDEX `idx_leaves_status_start` (`status`, `start_date`),  -- e.g. every PENDING request
    DROP INDEX `FKibii1n1dmpty2chfju80xnb5v`;

ALTER TABLE `news_items`
    ADD INDEX `idx_news_author_created` (`author_id`, `created_at`),  -- news by author
    ADD INDEX `idx_news_type_created` (`type`, `created_at`),         -- news by type
    ADD INDEX `idx_news_created` (`created_at`),                      -- all news
    DROP INDEX `FK5k7hvss1417dx69cilc9fceu7`;
