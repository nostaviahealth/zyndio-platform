# Zyndio - Health & Longevity Platform


A comprehensive health and longevity management platform built with React, Supabase, and Vercel.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ installed
- Supabase account
- Vercel account (for deployment)

### Local Development

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Set up Supabase:**
   Follow the [Supabase Setup Guide](./SUPABASE-SETUP.md) to:
   - Create a Supabase project
   - Run the database schema
   - Get your credentials

3. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   
   Then edit `.env` with your Supabase credentials:
   ``bash
   VITE_SUPABASE_URL=https://your-project.supabase.co
   VITE_SUPABASE_ANON_KEY=your_anon_key
   SUPABASE_SERVICE_KEY=your_service_key
   ```

4. **Run the development server:**
   ```bash
   npm run dev
   ```

5. **Create admin user:**
   Set `ADMIN_EMAIL` and `ADMIN_PASSWORD` in your `.env` first — the script reads both from the
   environment and exits with an error if either is missing (no default credentials exist).
   ```bash
   npm run admin:setup
   ```

## 🔐 Admin Access

Access the admin panel after setup:

- **Local:** http://localhost:3001/admin
- **Production:** https://zyndio.example/admin

Log in with the `ADMIN_EMAIL` / `ADMIN_PASSWORD` you set above.

> ⚠️ **Important:** Use a strong, unique password and never commit it to version control.

## 🏗️ Tech Stack

- **Frontend:** React + TypeScript + Vite
- **Backend:** Supabase (PostgreSQL + Auth + Storage)
- **Hosting:** Vercel
- **UI:** Custom CSS with Tailwind-inspired utilities
- **Charts:** Recharts
- **Icons:** Lucide React

## 📁 Project Structure

```
/
├── components/        # Reusable UI components
├── contexts/         # React contexts (Auth, Admin, User)
├── pages/           # Page components
│   ├── admin/      # Admin portal pages
│   └── ...         # User portal pages
├── lib/            # Core utilities and clients
│   ├── supabase.ts       # Supabase client
│   └── supabaseAdmin.ts  # Admin SDK
├── supabase/       # Database schema and migrations
├── scripts/        # Utility scripts
└── types.ts        # TypeScript definitions
```

## 🗄️ Database Schema

The application uses these main tables:
- `profiles` - User profiles with roles
- `patients` - Patient data for admin management
- `health_journeys` - AI-generated health protocols
- `meal_plans` - Nutrition plans
- `intelligence_data` - Health analytics

See [supabase/schema.sql](./supabase/schema.sql) for complete schema.

## 🌐 Deployment

### Vercel

1. **Add environment variables in Vercel:**
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_KEY`

2. **Deploy!** Connect your repository and Vercel auto-deploys

### Production URL
- **App:** https://zyndio.example
- **Admin:** https://zyndio.example/admin

## 🧪 Admin Features

- Patient management dashboard
- Health journey protocol generation
- Nutrition lab & meal planning
- Intelligence data analysis
- Medical notes & consultations

## 👥 User Roles

- **user** - Standard patient access
- **admin** - Full system access
- **doctor** - Medical protocol management
- **nutritionist** - Nutrition planning access

## 📝 Scripts

```bash
npm run dev          # Start development server
npm run build        # Build for production
npm run preview      # Preview production build
npm run admin:setup  # Create admin user
```

## 🔒 Security

- Row Level Security (RLS) enabled on all tables
- Secure authentication via Supabase Auth
- Service role key kept server-side only
- Email confirmation available (optional)

## 📄 License

All rights reserved - Zyndio

## 🆘 Support

For setup help or issues:
1. Check the [Supabase Setup Guide](./SUPABASE-SETUP.md)
2. Review database schema in `supabase/schema.sql`
3. Verify environment variables are correct

---

Built with ❤️ for better health outcomes
