-- 1. 데이터베이스 생성 및 환경 설정
CREATE DATABASE IF NOT EXISTS kculture CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE kculture;

SET FOREIGN_KEY_CHECKS = 0;

-- 2. users 테이블
CREATE TABLE IF NOT EXISTS `users` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `email` VARCHAR(255) NOT NULL UNIQUE COMMENT '로그인용',
    `name` VARCHAR(100) NOT NULL COMMENT '표시 이름',
    `password_hash` VARCHAR(255) NOT NULL COMMENT 'bcrypt 해시',
    `language` VARCHAR(5) DEFAULT 'en' COMMENT '선호 언어',
    `role` VARCHAR(20) NOT NULL DEFAULT 'user' COMMENT '권한: user / admin',
    `token` VARCHAR(64) UNIQUE COMMENT '로그인 시 발급 (UNIQUE가 이미 인덱스 생성 완료)',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 3. events 테이블
CREATE TABLE IF NOT EXISTS `events` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `title` VARCHAR(255) NOT NULL COMMENT '이벤트 제목 (한국어)',
    `description` TEXT COMMENT '설명',
    `location` VARCHAR(255) NULL COMMENT 'admin-service null 바인딩 대응 허용',
    `category` VARCHAR(50) NOT NULL,
    `image_url` VARCHAR(500) NULL COMMENT '운영용 긴 URL 고려 500 복원 및 Null 허용',
    `main_image_url` VARCHAR(500) NULL COMMENT '상세 페이지 메인 이미지(_main). null 시 image_url 폴백',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 4. event_slots 테이블 
CREATE TABLE IF NOT EXISTS `event_slots` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `event_id` INT NOT NULL,
    `slot_datetime` DATETIME NOT NULL,
    `remaining_capacity` INT NOT NULL,
    `max_capacity` INT NOT NULL,
    `version` INT NOT NULL DEFAULT 0 COMMENT '낙관적 잠금용 버전',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_slot_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
    CONSTRAINT `chk_remaining_capacity` CHECK (`remaining_capacity` >= 0)
) ENGINE=InnoDB;

-- 5. reservations 테이블
CREATE TABLE IF NOT EXISTS `reservations` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `event_slot_id` INT NOT NULL,
    `status` ENUM('confirmed', 'cancelled') DEFAULT 'confirmed',
    `idempotency_key` VARCHAR(64) NOT NULL UNIQUE COMMENT '멱등성 키',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_res_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
    CONSTRAINT `fk_res_slot` FOREIGN KEY (`event_slot_id`) REFERENCES `event_slots` (`id`),
    UNIQUE KEY `unique_user_slot` (`user_id`, `event_slot_id`),
    INDEX `idx_cleanup_created` (`created_at`)
) ENGINE=InnoDB;

-- 6. translations 테이블
CREATE TABLE IF NOT EXISTS `translations` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `event_id` INT NOT NULL,
    `field_name` VARCHAR(50) NOT NULL COMMENT 'title / description',
    `target_lang` VARCHAR(5) NOT NULL COMMENT 'en / ja / zh',
    `translated_text` TEXT NOT NULL,
    CONSTRAINT `fk_trans_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
    UNIQUE KEY `unique_translation` (`event_id`, `field_name`, `target_lang`) COMMENT '이벤트 목록 중복 노출 방지 안전장치'
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;
