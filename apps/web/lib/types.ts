export type AccountType = 'cash' | 'bank' | 'wallet'
export type TransactionType = 'expense' | 'income' | 'transfer'
export type TransactionStatus = 'completed' | 'pending'

export interface Account {
  id: string
  name: string
  type: AccountType
  balance: number
  currency: string
  color: string | null
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface Category {
  id: string
  name: string
  icon: string | null
  color: string | null
  type: string
  created_at: string
}

export interface Merchant {
  id: string
  name: string
  default_category_id: string | null
  transaction_count: number
}

export interface Transaction {
  id: string
  type: TransactionType
  amount: number
  account_id: string
  to_account_id: string | null
  category_id: string | null
  merchant_id: string | null
  note: string | null
  date: string
  status: TransactionStatus
  account_name: string
  account_color: string | null
  to_account_name: string | null
  category_name: string | null
  category_icon: string | null
  category_color: string | null
  merchant_name: string | null
  item_count: number
}

export interface Debt {
  id: string
  transaction_id: string
  person_name: string
  direction: 'i_owe' | 'they_owe'
  settled_at: string | null
  amount: number
  note: string | null
  date: string
  account_name: string
}

export interface AnalyticsSummary {
  period: string
  total_income: number
  total_expenses: number
  net_change: number
  transaction_count: number
  total_balance: number
}

export interface CategoryBreakdown {
  period: string
  total: number
  categories: {
    category_id: string
    category_name: string
    category_icon: string | null
    category_color: string | null
    total: number
    percentage: number
    transaction_count: number
  }[]
}

export interface TrendData {
  period: string
  data_points: {
    date: string
    expenses: number
    income: number
    net: number
  }[]
}

export interface Item {
  id: string
  name: string
  category_id?: string
  category_name?: string
  category_icon?: string
  category_color?: string
  usage_count: number
  last_price: number
  created_at: string
  updated_at: string
}

export interface TransactionItem {
  id: string
  transaction_id: string
  item_id: string
  item_name: string
  category_id?: string
  category_name?: string
  category_icon?: string
  category_color?: string
  amount: number
  quantity: number
  remarks?: string
  created_at: string
}
