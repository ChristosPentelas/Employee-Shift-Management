-- F12, B7: deleting a user is one statement; the database handles the rest.
--
-- Until now every foreign key to users had no ON DELETE rule (NO ACTION), so
-- MySQL refused to delete a user anything still pointed at. UserService
-- deleted the rows first, from a hand-written list - which forgot news_items
-- (B7). Now each key says what happens to its rows:
--
--   shifts, leaves_requests, messages (both ways)  CASCADE   deleted with the user
--   news_items.author_id                           SET NULL  kept, with no author
--
-- News is kept on purpose (decided 2026-10-04): a post is for everyone, not
-- just its author, and the app shows a post with no author as "Από: Άγνωστος"
-- (F29). Messages cannot be kept the same way: sender_id and receiver_id are
-- NOT NULL.
--
-- MySQL cannot change a foreign key's rule in place, so each key is dropped
-- and added again under the same name (V1's names, kept so that every
-- database matches this file). One statement each, so every line does one
-- thing. Each ADD finds the index V3 made for that column and uses it, rather
-- than creating a new one.
--
-- DDL cannot be rolled back in MySQL. If this file fails halfway, the keys
-- already changed stay changed and Flyway records the migration as failed:
-- fix the database by hand, then run flyway repair before starting again.

ALTER TABLE `shifts` DROP FOREIGN KEY `FK3dq4k4tt0x91h7kkabwrrkyho`;
ALTER TABLE `shifts` ADD CONSTRAINT `FK3dq4k4tt0x91h7kkabwrrkyho`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

ALTER TABLE `leaves_requests` DROP FOREIGN KEY `FKibii1n1dmpty2chfju80xnb5v`;
ALTER TABLE `leaves_requests` ADD CONSTRAINT `FKibii1n1dmpty2chfju80xnb5v`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

ALTER TABLE `messages` DROP FOREIGN KEY `FK4ui4nnwntodh6wjvck53dbk9m`;
ALTER TABLE `messages` ADD CONSTRAINT `FK4ui4nnwntodh6wjvck53dbk9m`
    FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

ALTER TABLE `messages` DROP FOREIGN KEY `FKm8wkvh2tbxksve6eadxk6khgw`;
ALTER TABLE `messages` ADD CONSTRAINT `FKm8wkvh2tbxksve6eadxk6khgw`
    FOREIGN KEY (`receiver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

ALTER TABLE `news_items` DROP FOREIGN KEY `FK5k7hvss1417dx69cilc9fceu7`;
ALTER TABLE `news_items` ADD CONSTRAINT `FK5k7hvss1417dx69cilc9fceu7`
    FOREIGN KEY (`author_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;
