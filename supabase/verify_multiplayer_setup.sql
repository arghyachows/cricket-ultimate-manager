-- Run this in Supabase SQL Editor to verify multiplayer setup

-- Check if tables exist
SELECT 
  'multiplayer_rooms' as table_name,
  COUNT(*) as row_count
FROM multiplayer_rooms
UNION ALL
SELECT 
  'room_presence' as table_name,
  COUNT(*) as row_count
FROM room_presence
UNION ALL
SELECT 
  'match_challenges' as table_name,
  COUNT(*) as row_count
FROM match_challenges;

-- Check if RLS is enabled
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename IN ('multiplayer_rooms', 'room_presence', 'match_challenges');

-- Check if realtime is enabled
SELECT 
  schemaname,
  tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('room_presence', 'match_challenges');

-- If tables don't exist, create them:
-- Run the migration file: supabase/migrations/20260316000001_multiplayer_system.sql
