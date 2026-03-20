-- Card Packs Storage: users earn packs and open them later
-- Also grants a Starter Pack to every new user automatically

-- 1) Table to store unopened card packs belonging to users
create table if not exists user_card_packs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pack_name text not null,
  card_count int not null default 3,
  bronze_chance double precision not null default 60,
  silver_chance double precision not null default 25,
  gold_chance double precision not null default 10,
  elite_chance double precision not null default 4,
  legend_chance double precision not null default 1,
  source text not null default 'reward',  -- 'starter', 'reward', 'purchase', 'tournament', etc.
  opened boolean not null default false,
  created_at timestamptz not null default now()
);

-- RLS
alter table user_card_packs enable row level security;

create policy "Users can read own packs"
  on user_card_packs for select using (auth.uid() = user_id);

create policy "Users can update own packs"
  on user_card_packs for update using (auth.uid() = user_id);

create policy "Service can insert packs"
  on user_card_packs for insert with check (true);

-- Index for fast lookup
create index if not exists idx_user_card_packs_user on user_card_packs(user_id, opened);

-- 2) Function + trigger to grant a starter pack on new user signup
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

drop trigger if exists trg_grant_starter_pack on users;
create trigger trg_grant_starter_pack
  after insert on users
  for each row
  execute function grant_starter_pack();

-- 3) Grant starter pack to all existing users who don't have one yet
insert into user_card_packs (user_id, pack_name, card_count, bronze_chance, silver_chance, gold_chance, elite_chance, legend_chance, source)
select u.id, 'Starter Pack', 15, 40, 35, 25, 0, 0, 'starter'
from users u
where not exists (
  select 1 from user_card_packs p where p.user_id = u.id and p.source = 'starter'
);
