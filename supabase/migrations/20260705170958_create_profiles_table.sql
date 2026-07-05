/*
# Create profiles table for FunLand

1. New Tables
- `profiles`
  - `id` (uuid, primary key, references auth.users)
  - `username` (text, unique, not null)
  - `email` (text, unique, not null)
  - `avatar_url` (text, nullable)
  - `bio` (text, nullable)
  - `created_at` (timestamptz, default now())
  - `updated_at` (timestamptz, default now())

2. Security
- Enable RLS on `profiles`
- Owner-scoped CRUD: each authenticated user can only access their own profile
- Public read: all profiles are visible to authenticated users (social network)

3. Notes
- Uses Supabase's built-in auth.users for authentication
- Profile created automatically when user signs up via trigger
- Username and email must be unique across all users
*/

CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL,
  email text UNIQUE NOT NULL,
  avatar_url text,
  bio text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view all profiles (social network)
DROP POLICY IF EXISTS "authenticated_can_view_profiles" ON profiles;
CREATE POLICY "authenticated_can_view_profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

-- Users can only insert their own profile
DROP POLICY IF EXISTS "users_can_insert_own_profile" ON profiles;
CREATE POLICY "users_can_insert_own_profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Users can only update their own profile
DROP POLICY IF EXISTS "users_can_update_own_profile" ON profiles;
CREATE POLICY "users_can_update_own_profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Users can only delete their own profile
DROP POLICY IF EXISTS "users_can_delete_own_profile" ON profiles;
CREATE POLICY "users_can_delete_own_profile"
  ON profiles FOR DELETE
  TO authenticated
  USING (auth.uid() = id);

-- Function to automatically create a profile when a user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, username, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Index for faster username lookups
CREATE INDEX IF NOT EXISTS profiles_username_idx ON profiles(username);
CREATE INDEX IF NOT EXISTS profiles_email_idx ON profiles(email);
