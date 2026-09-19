-- Baseline: the schema exactly as Hibernate's ddl-auto created it on a fresh
-- MySQL 8.0.44 database at commit 207d802 (taken with mysqldump --no-data).
-- Constraint names are Hibernate's generated ones, kept so that databases
-- created before Flyway match this file.
--
-- Never edit this file once it is committed: Flyway stores a checksum of every
-- applied migration and refuses to start if one changes. Schema changes go in
-- a new V2__..., V3__... file.

CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `phone_number` varchar(255) DEFAULT NULL,
  `role` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK6dotkott2kjsp8vw4d0m25fb7` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `leaves_requests` (
  `id` int NOT NULL AUTO_INCREMENT,
  `end_date` date NOT NULL,
  `reason` varchar(255) NOT NULL,
  `start_date` date NOT NULL,
  `status` enum('APPROVED','PENDING','REJECTED') NOT NULL,
  `user_id` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKibii1n1dmpty2chfju80xnb5v` (`user_id`),
  CONSTRAINT `FKibii1n1dmpty2chfju80xnb5v` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `messages` (
  `id` int NOT NULL AUTO_INCREMENT,
  `content` varchar(255) NOT NULL,
  `is_read` bit(1) NOT NULL,
  `timestamp` datetime(6) NOT NULL,
  `reciever_id` int NOT NULL,
  `sender_id` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKm8wkvh2tbxksve6eadxk6khgw` (`reciever_id`),
  KEY `FK4ui4nnwntodh6wjvck53dbk9m` (`sender_id`),
  CONSTRAINT `FK4ui4nnwntodh6wjvck53dbk9m` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FKm8wkvh2tbxksve6eadxk6khgw` FOREIGN KEY (`reciever_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `news_items` (
  `id` int NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) DEFAULT NULL,
  `deadline` datetime(6) DEFAULT NULL,
  `description` varchar(255) NOT NULL,
  `target_value` int DEFAULT NULL,
  `title` varchar(255) NOT NULL,
  `type` enum('ANNOUNCEMENT','GOAL','TASK') NOT NULL,
  `author_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK5k7hvss1417dx69cilc9fceu7` (`author_id`),
  CONSTRAINT `FK5k7hvss1417dx69cilc9fceu7` FOREIGN KEY (`author_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `shifts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `date` date NOT NULL,
  `end_time` time NOT NULL,
  `position` varchar(255) NOT NULL,
  `start_time` time NOT NULL,
  `user_id` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK3dq4k4tt0x91h7kkabwrrkyho` (`user_id`),
  CONSTRAINT `FK3dq4k4tt0x91h7kkabwrrkyho` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
