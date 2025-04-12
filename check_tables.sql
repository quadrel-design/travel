-- Check for existing tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('profiles', 'journeys');

-- Check for existing storage buckets
SELECT * FROM storage.buckets; 