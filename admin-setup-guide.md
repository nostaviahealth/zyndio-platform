# Admin Access Setup Guide

This guide will help you set up and access the admin panel for Zyndio.

## 🌐 Access URLs

- **Production:** https://zyndio.example/admin
- **Local Development:** http://localhost:3001/admin

## 🔐 Default Admin Credentials

> **⚠️ IMPORTANT:** These are development credentials. Change them immediately after first login in production!

- **Email:** `support@zyndio.example`
- **Password:** `admin123`

---

## 📋 Initial Setup in Appwrite Console

### Step 1: Access Appwrite Console

1. Go to: https://cloud.appwrite.io/console/project-692d195a00178732443d
2. Sign in with your Appwrite account

### Step 2: Navigate to Users

1. In the left sidebar, click **"Authentication"**
2. Click **"Users"**

### Step 3: Check if Admin User Exists

1. Look for a user with email: `support@zyndio.example`
2. If it exists, verify it has the `admin` label (see Step 5)
3. If it doesn't exist, continue to Step 4

### Step 4: Create Admin User (if needed)

1. Click **"Create user"** button
2. Fill in the form:
   - **Email:** `support@zyndio.example`
   - **Password:** `admin123`
   - **Name:** `Admin User`
3. Click **"Create"**

### Step 5: Add Admin Label

**This is the CRITICAL step that grants admin access!**

1. Click on the admin user in the users list
2. Scroll down to the **"Labels"** section
3. Click **"Add label"** or **"Update labels"**
4. Enter: `admin` (all lowercase, no spaces)
5. Click **"Add"** or **"Save"**

---

## ✅ Testing Admin Access

### Local Testing

1. Start your development server:
   ```bash
   npm run dev
   ```

2. Open browser and go to: http://localhost:3001/login

3. Sign in with admin credentials:
   - Email: `support@zyndio.example`
   - Password: `admin123`

4. You should be automatically redirected to `/admin`

5. Check browser console (F12) for debug logs showing admin status

### Production Testing

1. Go to: https://zyndio.example/login

2. Sign in with admin credentials

3. Verify you're redirected to: https://zyndio.example/admin

4. Test admin features:
   - ✓ View patient dashboard
   - ✓ Create new patients
   - ✓ Access nutrition lab
   - ✓ Manage intelligence data
   - ✓ Configure health journeys

---

## 🐛 Troubleshooting

### Issue: "Invalid credentials" error

**Solution:**
- Verify the email and password are correct
- Check if user exists in Appwrite Console
- Ensure password matches what was set in Appwrite

### Issue: Redirected to `/` instead of `/admin`

**Solution:**
- This means the user doesn't have the `admin` label
- Go to Appwrite Console → Users → Click on user
- Add the `admin` label (lowercase, exactly as shown)
- Sign out and sign in again

### Issue: Browser console shows `isAdmin: false`

**Solution:**
- The admin label is missing or incorrect
- Check the console logs for the `labels` array
- It should include `'admin'`
- If not, add it in Appwrite Console

### Issue: Can't access `/admin` routes

**Solution:**
- Clear browser cache and cookies
- Sign out completely
- Sign in again with admin credentials
- Check browser console for error messages

---

## 🔒 Security Best Practices

### For Production

1. **Change Default Password:**
   - Go to Appwrite Console
   - Click on admin user
   - Change password to a strong, unique password
   - Use a password manager

2. **Enable MFA (if available):**
   - Check Appwrite settings for multi-factor authentication
   - Enable it for the admin account

3. **Create Role-Based Users:**
   - For team members, create separate accounts
   - Use labels: `admin`, `doctor`, `nutritionist`
   - Never share one admin account

4. **Monitor Access:**
   - Regularly check Appwrite logs
   - Review active sessions
   - Disable unused accounts

### Credential Management

- **DO NOT** commit credentials to Git
- **DO NOT** share credentials in plain text
- **DO** use a password manager
- **DO** rotate passwords regularly
- **DO** use environment-specific credentials

---

## 📞 Support

If you encounter issues:

1. Check the browser console for errors (F12 → Console)
2. Review the Appwrite Console for user configuration
3. Verify environment variables in `.env` (local) or Vercel (production)
4. Check the [Appwrite Collections Setup Guide](./appwrite-collections-setup.md)

---

## 🎯 Quick Reference

| Item | Value |
|------|-------|
| Production URL | https://zyndio.example/admin |
| Admin Email | support@zyndio.example |
| Default Password | admin123 |
| Required Label | `admin` |
| Appwrite Project | 692d195a00178732443d |

**Remember:** After setup, immediately change the default password in production!
