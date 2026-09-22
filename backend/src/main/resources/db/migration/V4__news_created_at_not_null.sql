-- B25: every news item must have a creation time.
--
-- NewsItem's @PrePersist has always set created_at, so only a row written
-- outside JPA (a hand-written INSERT) can be NULL here. Such a row's real time
-- is unknown. It gets the oldest possible date rather than NOW(): the feed is
-- newest first, and NOW() would put every old post at the top as if it had
-- just been published.
UPDATE `news_items` SET `created_at` = '1970-01-01 00:00:00' WHERE `created_at` IS NULL;

-- MODIFY restates the whole column, so the type must match V1 exactly
-- (datetime(6)); only NOT NULL is new. There is no DEFAULT on purpose: the
-- application sets the time, and a second clock in the database could
-- disagree with it.
ALTER TABLE `news_items` MODIFY `created_at` datetime(6) NOT NULL;
