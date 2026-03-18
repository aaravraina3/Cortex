# Deploying Cortex

Production stack: **Supabase Cloud** (free) + **Railway** ($5/mo) + **Vercel** (free).

---

## 1. Supabase Cloud

1. Create a project at [supabase.com/dashboard](https://supabase.com/dashboard)
2. Go to **Database → Extensions** and enable: `vector`, `http`, `pg_net`
3. Go to **SQL Editor** and run the contents of `deploy/supabase-cloud-setup.sql`
4. Note down from **Settings → API**:
   - **Project URL** (`https://xxx.supabase.co`)
   - **anon/public key** (starts with `eyJ...`)
   - **service_role key** (starts with `eyJ...`, keep secret)

The backend auto-seeds demo users and tenants on first startup.

## 2. Google AI Studio

1. Go to [aistudio.google.com](https://aistudio.google.com)
2. Get or reuse your API key
3. Enable billing and set a **$5/month budget cap**
4. This removes the 20-requests/day free-tier limit

## 3. Railway (Backend)

1. Go to [railway.app](https://railway.app), create a new project
2. Choose **Deploy from GitHub repo** → select this repo
3. Railway should auto-detect the root `Dockerfile`
4. Set these **environment variables**:

| Variable | Value |
|----------|-------|
| `ENVIRONMENT` | `production` |
| `SUPABASE_URL` | `https://xxx.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJ...` (service_role from step 1) |
| `WEBHOOK_BASE_URL` | `https://<your-railway-url>` |
| `WEBHOOK_SECRET` | any random string (e.g. `openssl rand -hex 32`) |
| `GEMINI_API_KEY` | your Gemini key |
| `DATABASE_URL` | `postgresql://postgres:xxx@db.xxx.supabase.co:5432/postgres` |

5. After deploy, note the public URL (e.g. `cortex-backend-xxx.up.railway.app`)
6. Update `WEBHOOK_BASE_URL` to that URL and redeploy

## 4. Vercel (Frontend)

1. Go to [vercel.com](https://vercel.com), import the GitHub repo
2. Set **Root Directory** to `frontend`
3. Framework preset: **Vite**
4. Set **Environment Variables** (all are build-time):

| Variable | Value |
|----------|-------|
| `VITE_ENVIRONMENT` | `production` |
| `VITE_SUPABASE_URL` | `https://xxx.supabase.co` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | `eyJ...` (anon key from step 1) |
| `VITE_API_BASE_URL` | `https://<railway-url>` (no trailing slash, no /api) |

5. Deploy. The frontend build hides the dev-only error tester page.

## 5. Pre-seed demo data

1. Visit the Vercel URL and log in as **admin@cortex.com / password**
2. Switch to a tenant (e.g. Kawasaki Robotics)
3. On the Documents page, each tenant sees **only their own** sample Load button — click it to load
4. Go to Admin and run the full pipeline: Classify → Assign → Patterns → Migrations → Load Data
5. Now visitors see a completed pipeline when they log in

**If Staubli tenant is missing** (e.g. DB was seeded before Staubli was added), run `deploy/add-staubli-tenant.sql` in Supabase SQL Editor.

## Demo credentials

| Email | Password | Role |
|-------|----------|------|
| admin@cortex.com | password | Admin |
| eng@kawasaki-robotics.com | password | Tenant (Kawasaki) |
| eng@kuka.com | password | Tenant (Kuka) |
| eng@staubli.com | password | Tenant (Staubli) |
| eng@milara.com | password | Tenant (Milara) |

**Demo behavior:** Tenant users see only their tenant's documents. Admin can switch tenants to see each tenant's data. For a clean demo (e.g. Bridgwater), log in as a tenant user (e.g. eng@kuka.com) — they see only Kuka's docs.
