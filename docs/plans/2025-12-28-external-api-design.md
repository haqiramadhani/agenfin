# External API Design

**Date:** 2025-12-28
**Author:** Claude Code

## Overview

This document describes the external API endpoints for Sure financial application. The API allows external integrations to manage invite codes, accounts, reports, categories, budgets, tags, and merchants.

## Authentication

All endpoints require either:
- OAuth2 Bearer token: `Authorization: Bearer <token>`
- API Key: `X-Api-Key: <key>`

Required scope: `read` for GET, `read_write` for POST/PUT/DELETE

## Base URL

```
/api/v1
```

## Endpoints Summary

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/admin/invite_codes` | Create invite code (superadmin only) |
| POST | `/accounts` | Create account |
| GET | `/overview` | Get family overview summary |
| GET | `/reports/net_worth` | Get net worth over time |
| GET | `/reports/cashflow` | Get income vs expenses |
| GET | `/reports/balance_sheet` | Get assets and liabilities |
| GET | `/reports/outflows` | Get top spending outflows |
| GET | `/categories` | List categories (existing) |
| POST | `/categories` | Create category |
| PUT | `/categories/:id` | Update category |
| DELETE | `/categories/:id` | Delete category |
| GET | `/budgets` | List budgets |
| PUT | `/budgets/:id` | Update budget |
| GET | `/tags` | List tags |
| POST | `/tags` | Create tag |
| PUT | `/tags/:id` | Update tag |
| DELETE | `/tags/:id` | Delete tag |
| GET | `/merchants` | List merchants |
| POST | `/merchants` | Create merchant |
| PUT | `/merchants/:id` | Update merchant |
| DELETE | `/merchants/:id` | Delete merchant |

## Endpoint Details

### 1. Admin Invite Codes

#### Create Invite Code

```
POST /admin/invite_codes
```

**Authentication:** Superadmin only

**Response:**
```json
{
  "token": "abc12345",
  "created_at": "2025-12-28T10:00:00Z"
}
```

**Notes:**
- Token is 8-character hex string
- Token is only returned on creation - store immediately

### 2. Accounts

#### Create Account

```
POST /accounts
```

**Request Body:**
```json
{
  "name": "My Savings",
  "accountable_type": "checking|savings",
  "currency": "USD",
  "balance": 1000.00
}
```

**Response:**
```json
{
  "id": "uuid",
  "name": "My Savings",
  "balance": "$1,000.00",
  "currency": "USD",
  "classification": "asset",
  "account_type": "checking",
  "created_at": "2025-12-28T10:00:00Z"
}
```

### 3. Overview

#### Get Family Overview

```
GET /overview
```

**Query Params:**
- `period_type` (optional): `monthly|quarterly|ytd`, default `monthly`

**Response:**
```json
{
  "period": {
    "start_date": "2025-12-01",
    "end_date": "2025-12-31"
  },
  "net_worth": "$50,000.00",
  "accounts_count": 5,
  "transactions_count": 42,
  "current_month": {
    "income": "$5,000.00",
    "expenses": "$3,500.00",
    "net_savings": "$1,500.00"
  },
  "budget": {
    "budgeted": "$4,000.00",
    "spent": "$3,500.00",
    "remaining": "$500.00",
    "percent_used": 87.5
  }
}
```

### 4. Reports

#### Net Worth Report

```
GET /reports/net_worth
```

**Query Params:**
- `period_type`: `monthly|quarterly|ytd`, default `monthly`
- `months`: number, default 6

**Response:**
```json
{
  "period": {
    "start_date": "2025-07-01",
    "end_date": "2025-12-31"
  },
  "current_net_worth": "$50,000.00",
  "series": [
    {
      "date": "2025-07-31",
      "net_worth": "$45,000.00",
      "assets": "$60,000.00",
      "liabilities": "$15,000.00"
    }
  ]
}
```

#### Cashflow Report

```
GET /reports/cashflow
```

**Query Params:**
- `start_date`: YYYY-MM-DD
- `end_date`: YYYY-MM-DD

**Response:**
```json
{
  "period": {
    "start_date": "2025-12-01",
    "end_date": "2025-12-31"
  },
  "totals": {
    "income": "$5,000.00",
    "expenses": "$3,500.00",
    "net_savings": "$1,500.00"
  },
  "by_category": [
    { "category": "Salary", "type": "income", "total": "$5,000.00" },
    { "category": "Food", "type": "expense", "total": "$500.00" }
  ],
  "monthly_breakdown": [
    {
      "month": "Dec 2025",
      "income": "$5,000.00",
      "expenses": "$3,500.00",
      "net": "$1,500.00"
    }
  ]
}
```

#### Balance Sheet Report

```
GET /reports/balance_sheet
```

**Response:**
```json
{
  "as_of": "2025-12-28",
  "assets": {
    "total": "$60,000.00",
    "liquid": "$20,000.00",
    "investments": "$30,000.00",
    "properties": "$10,000.00"
  },
  "liabilities": {
    "total": "$10,000.00",
    "credit_cards": "$2,000.00",
    "loans": "$8,000.00"
  },
  "net_worth": "$50,000.00"
}
```

#### Outflows Report

```
GET /reports/outflows
```

**Query Params:**
- `limit`: number, default 10
- `start_date`: YYYY-MM-DD
- `end_date`: YYYY-MM-DD

**Response:**
```json
{
  "period": {
    "start_date": "2025-12-01",
    "end_date": "2025-12-31"
  },
  "top_outflows": [
    {
      "category": "Food & Dining",
      "amount": "$500.00",
      "percentage": 14.3,
      "transaction_count": 25
    }
  ]
}
```

### 5. Categories

#### Create Category

```
POST /categories
```

**Request Body:**
```json
{
  "name": "Entertainment",
  "type": "expense|income",
  "color": "#6366F1",
  "icon": "film",
  "parent_id": null
}
```

#### Update Category

```
PUT /categories/:id
```

**Request Body:** Any of the create fields

#### Delete Category

```
DELETE /categories/:id
```

### 6. Budgets

#### List Budgets

```
GET /budgets
```

**Query Params:**
- `month`: YYYY-MM, default current month

**Response:**
```json
{
  "budgets": [
    {
      "id": "uuid",
      "start_date": "2025-12-01",
      "end_date": "2025-12-31",
      "currency": "USD",
      "budgeted_spending": 4000.00,
      "expected_income": 5000.00,
      "actual_spending": 3500.00,
      "allocated_spending": 4000.00,
      "available_to_spend": 500.00,
      "percent_spent": 87.5,
      "categories": [
        {
          "id": "uuid",
          "name": "Food",
          "budgeted": 500.00,
          "spent": 450.00,
          "remaining": 50.00,
          "percent_spent": 90.0
        }
      ]
    }
  ]
}
```

#### Update Budget

```
PUT /budgets/:id
```

**Request Body:**
```json
{
  "budgeted_spending": 4500.00,
  "expected_income": 5500.00,
  "categories": {
    "category_id_1": { "budgeted_spending": 600.00 },
    "category_id_2": { "budgeted_spending": 300.00 }
  }
}
```

### 7. Tags

#### Create Tag

```
POST /tags
```

**Request Body:**
```json
{
  "name": "Urgent",
  "color": "#EF4444"
}
```

#### Update Tag

```
PUT /tags/:id
```

#### Delete Tag

```
DELETE /tags/:id
```

### 8. Merchants

#### Create Merchant

```
POST /merchants
```

**Request Body:**
```json
{
  "name": "Starbucks",
  "color": "#00704A"
}
```

#### Update Merchant

```
PUT /merchants/:id
```

#### Delete Merchant

```
DELETE /merchants/:id
```

## Implementation Notes

- Reuse existing model logic from web controllers
- Use existing `InviteCode.generate!` for invite code creation
- Use existing `Family.income_statement` and `Family.balance_sheet` for reports
- Use existing `Budget.find_or_bootstrap` for budget logic
- Follow existing API conventions (pagination, error format, Jbuilder templates)
- Superadmin check for invite codes should use `user.superadmin?`
