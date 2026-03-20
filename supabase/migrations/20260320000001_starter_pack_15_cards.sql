-- Update starter pack from 11 cards to 15 cards.
-- Also ensures the trigger on `users` grants exactly 1 starter pack per new signup.

-- 1) Replace the grant function with the updated card count
create or replace function grant_starter_pack()
returns trigger as $$
begin
  insert into user_card_packs (user_id, pack_name, card_count, bronze_chance, silver_chance, gold_chance, elite_chance, legend_chance, source)
  values (
    NEW.id,
    'Starter Pack',
    15,
    40,   -- 40% bronze
    35,   -- 35% silver
    25,   -- 25% gold
    0,    -- 0% elite
    0,    -- 0% legend
    'starter'
  );
  return NEW;
end;
$$ language plpgsql security definer;

-- 2) Re-create the trigger (idempotent)
drop trigger if exists trg_grant_starter_pack on users;
create trigger trg_grant_starter_pack
  after insert on users
  for each row
  execute function grant_starter_pack();

-- 3) Update any existing unopened starter packs to 15 cards
update user_card_packs
set card_count = 15
where source = 'starter' and opened = false;
