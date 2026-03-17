# Cortex

> **Note:** This is a personal project made publicly available temporarily for portfolio visibility. The repository is consolidated into a single commit for cleanliness — the full development history lives in my local environment.

ML-powered document intelligence platform that transforms unstructured PDFs and CSVs into a searchable, relationship-aware knowledge base. Uses vector embeddings, unsupervised clustering, and graph-based dependency resolution to automatically extract, classify, link, and query structured data from heterogeneous manufacturing documents.

## Technical Highlights

- **Embedding-Based Entity Resolution** — Cosine similarity argmax over 768-dimensional vector space for foreign key inference across dynamically-generated schemas, replacing heuristic matching with a threshold-free nearest-neighbor approach
- **Unsupervised Document Classification** — HDBSCAN density-based clustering over UMAP-reduced embedding space for zero-shot category discovery without predefined labels
- **Graph-Based Dependency Resolution** — Topological sort (Kahn's algorithm) over table dependency DAG with cycle detection for referential integrity during data ingestion
- **Semantic Search** — Parameterized top-K nearest-neighbor retrieval over pgvector-indexed embedding space with configurable similarity thresholds
- **Multi-Tenant Isolation** — Dynamically-generated PostgreSQL schemas with programmatic DDL derived from AI-classified document categories

## Architecture

- **Backend**: Python / FastAPI — async ETL pipeline, LLM orchestration (Google Gemini), embedding generation, webhook processing
- **Frontend**: React / TypeScript / Vite — admin dashboard, document management, real-time status updates via Supabase Realtime
- **Database**: PostgreSQL with schema-per-tenant isolation via Supabase, pgvector for similarity search
- **Infrastructure**: Docker Compose, Supabase (Auth, Storage, Realtime, RLS)

## Pipeline

7-stage ETL: **Upload → LLM Extraction → Embedding Generation → Unsupervised Clustering → AI Relationship Analysis → Schema Generation → Data Synchronization**

## Quick Start

### Prerequisites

- Docker Desktop
- Node.js 22
- Google Gemini API key

### Development Setup

```bash
git clone https://github.com/aaravraina3/Cortex.git
cd Cortex
npm run fresh
```

This single command generates environment variables, starts the local Supabase stack, and builds/runs all containers.

### Access Points

- **Frontend**: http://localhost:5173
- **Backend API**: http://localhost:8000
- **Supabase Studio**: http://localhost:54323

### Development Credentials

| Email                     | Password | Role   |
| ------------------------- | -------- | ------ |
| admin@cortex.com          | password | Admin  |
| eng@kawasaki-robotics.com | password | Tenant |
| eng@kuka.com              | password | Tenant |
| eng@staubli.com           | password | Tenant |
| eng@milara.com            | password | Tenant |

## Commands

```bash
npm run init-dev    # install dependencies and initialize supabase
npm run build       # build frontend and backend containers
npm run up          # start all services
npm run down        # stop all services
npm run rebuild     # rebuild containers from scratch
npm run reset       # reset database, rerun migrations, reseed
npm run hard-clean  # full teardown and volume prune
npm run fresh       # hard reset and start everything from scratch
```

## Project Structure

```
├── backend/            # FastAPI — services, repositories, routes, schemas
│   ├── app/core/       # Supabase client, auth, LLM wrapper, webhooks
│   ├── app/services/   # ETL pipeline, classification, pattern recognition, data sync
│   ├── app/repositories/  # Data access layer
│   └── app/routes/     # API endpoints
├── frontend/           # React/TS Vite app
│   ├── src/components/ # UI components, admin wizard, document viewer
│   ├── src/hooks/      # React Query hooks, realtime subscriptions
│   └── src/contexts/   # Auth and query client providers
├── supabase/           # Migrations, config, RLS policies
└── docker-compose.yml  # Container orchestration
```
