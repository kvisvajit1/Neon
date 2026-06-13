# REDMAGIC Social Media - Deployment Guide

## 🚀 Quick Start to Go Live

### Step 1: Supabase Setup
1. Go to [supabase.com](https://supabase.com) and create a free project
2. Note your **Project URL** and **Anon Key**
3. Go to **SQL Editor** and run the database schema (see `schema.sql`)
4. Go to **Storage** → Create two buckets: `attachments` and `avatars`
   - Make both buckets **public**

### Step 2: Update Configuration
Replace these in `index.html` (around line 130-131):
```javascript
const SUPABASE_URL = 'YOUR_PROJECT_URL';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
```

### Step 3: Deploy Frontend

#### Option A: Vercel (Recommended - Free)
```bash
npm install -g vercel
vercel
```
Then deploy the HTML file as a static site.

#### Option B: Netlify (Free)
1. Drag & drop `index.html` to [netlify.com](https://netlify.com)
2. Or connect your GitHub repo

#### Option C: GitHub Pages
1. Push to GitHub
2. Go to Settings → Pages → Deploy from main branch

#### Option D: Traditional Hosting
- Upload `index.html` to any web hosting (GoDaddy, Bluehost, etc.)

### Step 4: Enable Authentication
In Supabase:
1. Go to **Authentication** → **Providers**
2. Enable Email provider (already enabled by default)
3. Go to **Settings** → **Auth** → Disable email confirmation for testing

### Step 5: Test the App
1. Visit your deployed URL
2. Sign up with test account
3. Create posts, send messages, add friends

---

## 📊 Database Schema

Run this in Supabase SQL Editor:

```sql
-- Profiles
create table profiles (
  id uuid primary key references auth.users(id),
  handle text unique not null,
  avatar_url text,
  created_at timestamp default now()
);

-- Posts (Vocal Feed)
create table posts (
  id text primary key,
  user_id uuid references profiles(id),
  title text,
  description text,
  attachment_url text,
  attachment_type text,
  attachment_name text,
  likes_count int default 0,
  created_at timestamp default now()
);

-- Post Likes
create table post_likes (
  post_id text references posts(id),
  user_id uuid references profiles(id),
  primary key (post_id, user_id)
);

-- Comments
create table comments (
  id uuid primary key default gen_random_uuid(),
  post_id text references posts(id),
  user_id uuid references profiles(id),
  content text not null,
  created_at timestamp default now()
);

-- Direct Messages
create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id text not null,
  sender_id uuid references profiles(id),
  text text,
  attachment_url text,
  attachment_type text,
  attachment_name text,
  created_at timestamp default now()
);

-- Connections (Friends)
create table connections (
  user_id uuid references profiles(id),
  friend_id uuid references profiles(id),
  primary key (user_id, friend_id)
);

-- Groups
create table groups (
  id text primary key,
  name text not null,
  creator_id uuid references profiles(id),
  created_at timestamp default now()
);

-- Group Members
create table group_members (
  group_id text references groups(id),
  user_id uuid references profiles(id),
  primary key (group_id, user_id)
);

-- RPC Functions
create or replace function increment_post_likes(post_id text)
returns void as $$
  update posts set likes_count = likes_count + 1 where id = $1;
$$ language sql;

create or replace function decrement_post_likes(post_id text)
returns void as $$
  update posts set likes_count = likes_count - 1 where id = $1;
$$ language sql;
```

---

## 🔒 Security Checklist

- [ ] Change Supabase anon key if exposed
- [ ] Enable RLS (Row Level Security) on all tables
- [ ] Set up proper CORS policies
- [ ] Use environment variables (not hardcoded keys in production)
- [ ] Enable auth email confirmation for production

---

## 📱 Custom Domain (Optional)

If using Vercel/Netlify, add your custom domain in their dashboard.

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Invalid API key" | Check SUPABASE_URL and SUPABASE_ANON_KEY |
| Upload fails | Ensure storage buckets are public |
| Auth fails | Check email confirmation settings in Supabase |
| CORS errors | Verify Supabase URL matches deployment domain |

---

## 📈 Production Checklist

- [ ] Set up custom domain
- [ ] Enable email confirmation
- [ ] Set up backup strategy
- [ ] Monitor Supabase usage
- [ ] Add SSL/TLS certificate
- [ ] Set up analytics
- [ ] Create privacy policy & terms

---

**Need help?** Check Supabase docs: https://supabase.com/docs
