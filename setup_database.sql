-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- PROFILES: Users and Role Management
create table profiles (
  id uuid references auth.users on delete cascade not null primary key,
  email text not null,
  full_name text,
  avatar_url text,
  role text check (role in ('student', 'client', 'admin')) default 'student',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS: Profiles
alter table profiles enable row level security;
create policy "Public profiles are viewable by everyone." on profiles for select using (true);
create policy "Users can insert their own profile." on profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile." on profiles for update using (auth.uid() = id);

-- COURSES: Academy Content
create table courses (
  id uuid default uuid_generate_v4() primary key,
  title text not null,
  slug text unique not null,
  description text,
  thumbnail_url text,
  price decimal(10,2) default 0,
  published boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- LESSONS: Course Modules
create table lessons (
  id uuid default uuid_generate_v4() primary key,
  course_id uuid references courses(id) on delete cascade not null,
  title text not null,
  slug text not null,
  description text,
  mux_playback_id text, -- ID for the Video Player
  mux_asset_id text,    -- ID for the API
  duration text,
  position integer default 0,
  is_locked boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Insert Dummy Data for "Viral Video Editing Mastery"
insert into courses (title, slug, description, published)
values ('Viral Video Editing Mastery', 'viral-video-editing', 'Master the art of retention-based editing.', true);

-- Enable RLS for Courses/Lessons (Public Read for now)
alter table courses enable row level security;
create policy "Courses are viewable by everyone." on courses for select using (true);

alter table lessons enable row level security;
create policy "Lessons are viewable by everyone." on lessons for select using (true);

-- Functions to handle new user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', 'student');
  return new;
end;
$$ language plpgsql security definer;

-- Trigger the function on signup
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
