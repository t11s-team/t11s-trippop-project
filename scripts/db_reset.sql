USE kculture;

SET FOREIGN_KEY_CHECKS = 0;

-- 1. 리셋 범위를 id >= 9xx 부하테스트 임시 대역 자원으로 한정 (샘플 데이터 무관)
DELETE FROM `reservations` 
WHERE `user_id` >= 901 OR `event_slot_id` >= 901;

-- 2. 테스트 대역 타임슬롯 수량 원복(max_capacity 대입) 및 낙관적 락 버전 완전 리셋(0)
UPDATE `event_slots` 
SET `remaining_capacity` = `max_capacity`,
    `version` = 0
WHERE `id` >= 901;

SET FOREIGN_KEY_CHECKS = 1;
