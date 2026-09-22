-- F13: fix the spelling of messages.reciever_id.
--
-- RENAME COLUMN changes only the name: the data, the index on it and the
-- foreign key to users all stay, and MySQL updates the foreign key definition
-- to the new name itself. The index and constraint keep their generated names
-- (FKm8wkvh2tbxksve6eadxk6khgw), which never mentioned the column.
ALTER TABLE `messages` RENAME COLUMN `reciever_id` TO `receiver_id`;
