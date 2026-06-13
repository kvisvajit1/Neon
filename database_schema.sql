-- REDMAGIC Social Media - Complete Database Schema
-- Run this in Supabase SQL Editor

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Profiles table
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle text unique not null,
  avatar_url text default 'https://api.dicebear.com/7.x/pixel-art/svg?seed=default',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Posts (Vocal Feed)
create table if not exists posts (
  id text primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null default 'UNTITLED',
  description text,
  attachment_url text,
  attachment_type text,
  attachment_name text,
  likes_count integer default 0,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Post Likes
create table if not exists post_likes (
  id uuid primary key default uuid_generate_v4(),
  post_id text not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamp with time zone default now(),
  unique(post_id, user_id)
);

-- Comments
create table if not exists comments (
  id uuid primary key default uuid_generate_v4(),
  post_id text not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Messages (Direct & Group)
create table if not exists messages (
  id uuid primary key default uuid_generate_v4(),
  conversation_id text not null,
  sender_id uuid not null references profiles(id) on delete cascade,
  text text,
  attachment_url text,
  attachment_type text,
  attachment_name text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Connections (Friends List)
create table if not exists connections (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  friend_id uuid not null references profiles(id) on delete cascade,
  created_at timestamp with time zone default now(),
  unique(user_id, friend_id)
);

-- Groups
create table if not exists groups (
  id text primary key,
  name text not null,
  creator_id uuid not null references profiles(id) on delete cascade,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Group Members
create table if not exists group_members (
  id uuid primary key default uuid_generate_v4(),
  group_id text not null references groups(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  joined_at timestamp with time zone default now(),
  unique(group_id, user_id)
);

-- Create indexes for better performance
create index if not exists idx_posts_user_id on posts(user_id);
create index if not exists idx_posts_created_at on posts(created_at desc);
create index if not exists idx_comments_post_id on comments(post_id);
create index if not exists idx_messages_conversation_id on messages(conversation_id);
create index if not exists idx_connections_user_id on connections(user_id);
create index if not exists idx_group_members_user_id on group_members(user_id);

-- RPC Function: Increment post likes
create or replace function increment_post_likes(post_id text)
returns void as $$
begin
  update posts set likes_count = likes_count + 1 where id = $1;
end;
$$ language plpgsql;

-- RPC Function: Decrement post likes
create or replace function decrement_post_likes(post_id text)
returns void as $$
begin
  update posts set likes_count = likes_count - 1 where id = $1;
end;
$$ language plpgsql;

-- Auto-create profile on user signup
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, handle, avatar_url)
  values (
    new.id,
    coalesce(new.user_metadata->>'handle', new.email),
    coalesce(new.user_metadata->>'avatar_url', 'https://api.dicebear.com/7.x/pixel-art/svg?seed=' || new.id::text)
  );
  return new;
end;
$$ language plpgsql security definer;

-- Trigger for new users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- Set up RLS (Row Level Security)
alter table profiles enable row level security;
alter table posts enable row level security;
alter table post_likes enable row level security;
alter table comments enable row level security;
alter table messages enable row level security;
alter table connections enable row level security;
alter table groups enable row level security;
alter table group_members enable row level security;

-- RLS Policies - Profiles (public read, own write)
create policy "Profiles are viewable by everyone" on profiles for select using (true);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);

-- RLS Policies - Posts (public read, own write/delete)
create policy "Posts are viewable by everyone" on posts for select using (true);
create policy "Users can create posts" on posts for insert with check (auth.uid() = user_id);
create policy "Users can update own posts" on posts for update using (auth.uid() = user_id);
create policy "Users can delete own posts" on posts for delete using (auth.uid() = user_id);

-- RLS Policies - Post Likes
create policy "Post likes are viewable by everyone" on post_likes for select using (true);
create policy "Users can create own likes" on post_likes for insert with check (auth.uid() = user_id);
create policy "Users can delete own likes" on post_likes for delete using (auth.uid() = user_id);

-- RLS Policies - Comments
create policy "Comments are viewable by everyone" on comments for select using (true);
create policy "Users can create comments" on comments for insert with check (auth.uid() = user_id);
create policy "Users can delete own comments" on comments for delete using (auth.uid() = user_id);

-- RLS Policies - Messages (only participants can view)
create policy "Users can view their messages" on messages for select using (
  sender_id = auth.uid() or 
  conversation_id like '%' || auth.uid()::text || '%'
);
create policy "Users can send messages" on messages for insert with check (auth.uid() = sender_id);
create policy "Users can delete own messages" on messages for delete using (auth.uid() = sender_id);

-- RLS Policies - Connections
create policy "Connections are viewable by everyone" on connections for select using (true);
create policy "Users can create connections" on connections for insert with check (auth.uid() = user_id);
create policy "Users can delete own connections" on connections for delete using (auth.uid() = user_id);

-- RLS Policies - Groups
create policy "Groups are viewable by everyone" on groups for select using (true);
create policy "Users can create groups" on groups for insert with check (auth.uid() = creator_id);

-- RLS Policies - Group Members
create policy "Group members are viewable by everyone" on group_members for select using (true);
create policy "Group creators can manage members" on group_members for insert with check (
  auth.uid() in (select creator_id from groups where id = group_members.group_id)
);
