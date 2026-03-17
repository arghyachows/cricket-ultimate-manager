-- Gift every existing user a Gold Pack
INSERT INTO user_card_packs (user_id, pack_name, card_count, bronze_chance, silver_chance, gold_chance, elite_chance, legend_chance, source)
SELECT id, 'Gold Pack', 5, 10, 25, 40, 18, 7, 'reward'
FROM users;
