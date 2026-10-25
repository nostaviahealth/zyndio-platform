# 🚀 Supabase Setup - Quick Start Guide

## Step 1: Create Supabase Project (5 minutes)

1. Go to: **https://supabase.com/dashboard**

2. Click **"New Project"**

3. Fill in:
   - **Organization:** Create new or select existing
   - **Name:** `Zyndio`
   - **Database Password:** Choose a strong password (SAVE THIS!)
   - **Region:** Choose closest to you (e.g., `US East`)
   - **Pricing Plan:** Free

4. Click **"Create new project"**

5. Wait 2-3 minutes for setup to complete

---

## Step 2: Get Your Credentials

1. Once the project is ready, go to: **Settings → API**

2. Copy these three values:

   📋 **Project URL:**
   ```
   Example: https://abcdefghijk.supabase.co
   ```

   📋 **anon/public key:**
   ```
   Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

   📋 **service_role/secret key:**
   ```
   Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... (different from anon key)
   ```

   ⚠️ **IMPORTANT:** The service_role key is SECRET - never commit it to Git!

---

## Step 3: Run Database Schema

1. In Supabase Dashboard, go to: **SQL Editor**

2. Click **"New query"**

3. Copy the entire contents of `supabase/schema.sql` file

4. Paste into the SQL editor

5. Click **"Run"** or press `Cmd+Enter`

6. Wait for success message: ✅ "Success. No rows returned"

---

## Step 4: Enable Email Auth

1. Go to: **Authentication → Providers**

2. Find **"Email"** in the list

3. Toggle it **ON** (should be on by default)

4. Scroll to **"Email Confirm"** settings

5. **Disable** email confirmations for now:
   - Uncheck "Enable email confirmations"
   
   (You can enable this later with SMTP)

---

## Step 5: Configure Site URL

1. Go to: **Authentication → URL Configuration  **

2. Set **"Site URL"**:
   ```
   https://zyndio.example
   ```

3. Add **"Redirect URLs"**:
   ```
   https://zyndio.example/**
   http://localhost:3001/**
   ```

4. Click **"Save"**

---

## Step 6: Send Me Your Credentials

Once you have all three credentials, send them to me in this format:

```
URL: https://your-project.supabase.co
ANON_KEY: <your-anon-key>
SERVICE_KEY: <your-service-key>
```

---

## What Happens Next (I'll do this)

1. ✅ Update your `.env` file with credentials
2. ✅ Migrate authentication code
3. ✅ Update all database access code  
4. ✅ Create admin user automatically via script (reads `ADMIN_EMAIL` / `ADMIN_PASSWORD` from `.env`)
5. ✅ Test everything locally
6. ✅ Deploy to Vercel
7. ✅ Test admin login on production

You'll be able to log in with the `ADMIN_EMAIL` / `ADMIN_PASSWORD` you configured in `.env`.

---

## ⏱️ Time Estimate

- **Your Part:** 10 minutes
- **My Part:** 1-2 hours
- **Total:** ~2 hours until fully migrated

---

## 🆘 Need Help?

If you get stuck, just tell me where you are and I'll guide you through it!
