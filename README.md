# ⚡ BalanceFlow

A personal finance tracker with a GPay-inspired UI. Track expenses, income, transfers, debts, and get spending insights — all in one place.

---

## Live URLs

| Service | URL |
|---|---|
| Web App | https://balanceflow-orcin.vercel.app |
| API | https://balanceflow-api-65pq.onrender.com |
| Health Check | https://balanceflow-api-65pq.onrender.com/health |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Web | Next.js 16 + Tailwind CSS v3 |
| API | Node.js + Express |
| Database | PostgreSQL via Supabase |
| Charts | Recharts |
| Icons | Lucide React |
| Hosting (Web) | Vercel |
| Hosting (API) | Render |

---

## Project Structure

```
balanceflow/
├── apps/
│   ├── api/                  — Express REST API
│   │   ├── src/
│   │   │   ├── index.ts      — server entry point
│   │   │   ├── db.ts         — per-request PostgreSQL connections
│   │   │   ├── middleware/
│   │   │   │   ├── auth.ts           — token-based auth
│   │   │   │   ├── errorHandler.ts   — centralised error handling
│   │   │   │   └── asyncHandler.ts   — async route wrapper
│   │   │   └── routes/
│   │   │       ├── accounts.ts
│   │   │       ├── categories.ts
│   │   │       ├── merchants.ts
│   │   │       ├── transactions.ts
│   │   │       ├── debts.ts
│   │   │       └── analytics.ts
│   │   ├── .env.example
│   │   └── package.json
│   │
│   └── web/                  — Next.js web app
│       ├── app/
│       │   ├── (app)/        — authenticated pages
│       │   │   ├── page.tsx          — Dashboard
│       │   │   ├── transactions/     — Transaction feed
│       │   │   ├── accounts/         — Account management
│       │   │   ├── analytics/        — Spending insights
│       │   │   ├── debts/            — Debt tracking
│       │   │   ├── categories/       — Category management
│       │   │   └── merchants/        — Merchant management
│       │   └── login/        — Login page
│       ├── components/
│       │   ├── layout/
│       │   │   ├── AppShell.tsx      — main layout wrapper
│       │   │   └── Sidebar.tsx       — navigation sidebar
│       │   └── ui/
│       │       ├── AnimatedBackground.tsx
│       │       ├── Card.tsx
│       │       ├── Skeleton.tsx
│       │       ├── EmptyState.tsx
│       │       ├── Toast.tsx
│       │       └── QuickAdd.tsx      — global floating add button
│       ├── lib/
│       │   ├── api.ts        — axios client with auth interceptors
│       │   ├── types.ts      — TypeScript interfaces
│       │   └── utils.ts      — formatCurrency, formatDate, formatTime
│       └── package.json
```

---

## API Endpoints

### Accounts
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/accounts` | Get all active accounts |
| GET | `/api/accounts/:id` | Get single account |
| POST | `/api/accounts` | Create account |
| PATCH | `/api/accounts/:id` | Update account |
| DELETE | `/api/accounts/:id` | Soft delete account |

### Transactions
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/transactions` | Get transactions (filterable) |
| GET | `/api/transactions/:id` | Get single transaction |
| POST | `/api/transactions` | Create transaction |
| PATCH | `/api/transactions/:id` | Update transaction |
| DELETE | `/api/transactions/:id` | Soft delete + reverse balance |

### Categories
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/categories` | Get all categories |
| POST | `/api/categories` | Create category |
| PATCH | `/api/categories/:id` | Update category |
| DELETE | `/api/categories/:id` | Delete category |

### Merchants
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/merchants` | Get all merchants |
| GET | `/api/merchants?regular=true` | Get frequent merchants (3+ transactions) |
| POST | `/api/merchants` | Create merchant |
| PATCH | `/api/merchants/:id` | Update merchant |
| DELETE | `/api/merchants/:id` | Delete merchant |

### Debts
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/debts` | Get unsettled debts |
| GET | `/api/debts?settled=true` | Get settled debts |
| POST | `/api/debts` | Create debt |
| PATCH | `/api/debts/:id/settle` | Settle a debt |
| DELETE | `/api/debts/:id` | Delete unsettled debt |

### Analytics
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/analytics/summary` | Total income, expenses, net, balance |
| GET | `/api/analytics/by-category` | Spending breakdown by category |
| GET | `/api/analytics/by-merchant` | Top merchants by spend |
| GET | `/api/analytics/trends` | Time series income vs expenses |

All analytics endpoints accept `?period=day|week|month|year` and optionally `?account_id=`.

---

## Features

### Dashboard
- Total balance across all accounts
- Income, expenses and net change for selected period
- Account cards with live balances
- Daily quote and time-based greeting

### Transactions
- GPay-style feed grouped by date
- Daily net shown on each date header
- Filter by type, status, account, merchant
- Search by merchant, note or amount
- Click any transaction to view details, edit or delete
- Soft delete reverses balance automatically

### Quick Add
- Floating + button available on every page
- Expense, income or transfer in seconds
- Merchant autocomplete — learns as you use it
- Optional custom date and time
- Pending toggle with debt details (person name + direction)

### Accounts
- Cash, bank and digital wallet types
- Color-coded with custom color picker
- Opening balance on creation
- Soft delete preserves transaction history

### Analytics
- Income vs expenses area chart
- Category breakdown donut chart with percentages
- Spending by day of week bar chart
- Top merchants ranked by spend
- Top 5 biggest expense transactions
- Average daily spend for the period

### Debts
- Track who owes who
- Settling a debt completes the transaction and updates balance
- Settled debt history toggleable

### Categories & Merchants
- 17 default categories seeded
- Custom icon picker + color picker
- Merchants auto-created when first typed in Quick Add
- Regular merchant badge after 3+ transactions

### Auth
- Single password login
- Password hashed with SHA-256 before storing in localStorage
- Token sent as `x-app-token` header on every API call
- Auto-redirect to login on 401

---

## Local Development

### Prerequisites
- Node.js >= 18
- A Supabase project with the schema applied

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/YOURUSERNAME/balanceflow.git
cd balanceflow

# 2. Install API dependencies
cd apps/api
npm install
cp .env.example .env
# Fill in your Supabase DATABASE_URL and APP_SECRET in .env

# 3. Start the API
npm run dev
# → http://localhost:3001

# 4. Install web dependencies (new terminal)
cd apps/web
npm install
cp .env.example .env.local
# Set NEXT_PUBLIC_API_URL=http://localhost:3001
# Set NEXT_PUBLIC_APP_SECRET=your-password

# 5. Start the web app
npm run dev
# → http://localhost:3000
```

### Environment Variables

**API (`apps/api/.env`)**
```
DATABASE_URL=postgresql://...
PORT=3001
NODE_ENV=development
ALLOWED_ORIGINS=http://localhost:3000
APP_SECRET=your-strong-password
```

**Web (`apps/web/.env.local`)**
```
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_APP_SECRET=your-strong-password
```

---

## Git Workflow

- `main` — always working, deployable code
- Feature branches for all work: `feat/`, `fix/`, `chore/`
- Commit format: `feat: add transaction endpoint`
- Merge into main, delete branch after merging

---

## Deployment

- **API** → Render (free tier, auto-deploys from `apps/api` on push to main)
- **Web** → Vercel (free tier, auto-deploys from `apps/web` on push to main)
- **Database** → Supabase (free tier, Singapore region)
- **Uptime monitoring** → UptimeRobot pinging `/health` every 5 minutes

---

## Roadmap

- [ ] Mobile app (Expo React Native)
- [ ] Push notifications for pending debts
- [ ] Offline sync
- [ ] CSV export
- [ ] Pagination on transaction feed
- [ ] Account transaction history page
- [ ] Settings page