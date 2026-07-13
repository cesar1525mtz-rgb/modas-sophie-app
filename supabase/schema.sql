create extension if not exists pgcrypto;

create type public.user_role as enum ('OWNER', 'SELLER');
create type public.inventory_movement_type as enum
  ('ENTRADA','VENTA','DEVOLUCION','AJUSTE','DANADO','PERDIDA','CANCELACION');

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  currency text not null default 'MXN',
  timezone text not null default 'America/Mexico_City',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  business_id uuid not null references public.businesses(id),
  name text not null,
  role public.user_role not null default 'SELLER',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  name text not null,
  sku_prefix text not null,
  active boolean not null default true,
  unique (business_id, sku_prefix)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  category_id uuid not null references public.categories(id),
  sku_base text not null,
  name text not null,
  description text,
  photo_url text,
  current_cost numeric(12,2) not null default 0 check (current_cost >= 0),
  sale_price numeric(12,2) not null default 0 check (sale_price >= 0),
  minimum_stock integer not null default 0 check (minimum_stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (business_id, sku_base)
);

create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  sku text not null unique,
  size text,
  color text,
  model text,
  compatibility text,
  current_stock integer not null default 0 check (current_stock >= 0),
  active boolean not null default true
);

create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.product_variants(id),
  movement_type public.inventory_movement_type not null,
  quantity integer not null check (quantity > 0),
  previous_stock integer not null,
  new_stock integer not null,
  unit_cost numeric(12,2),
  reason text,
  user_id uuid not null references public.user_profiles(id),
  created_at timestamptz not null default now()
);

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  folio text not null,
  seller_id uuid not null references public.user_profiles(id),
  subtotal numeric(12,2) not null,
  discount numeric(12,2) not null default 0,
  total numeric(12,2) not null,
  sold_cost numeric(12,2) not null default 0,
  gross_profit numeric(12,2) not null default 0,
  status text not null default 'COMPLETADA',
  created_at timestamptz not null default now(),
  unique (business_id, folio)
);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  variant_id uuid references public.product_variants(id),
  historical_name text not null,
  historical_sku text,
  historical_size text,
  historical_color text,
  quantity integer not null check (quantity > 0),
  historical_unit_cost numeric(12,2) not null default 0,
  unit_price numeric(12,2) not null,
  discount numeric(12,2) not null default 0,
  total numeric(12,2) not null
);

create table public.sale_payments (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  method text not null,
  amount numeric(12,2) not null check (amount > 0),
  reference text
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  concept text not null,
  amount numeric(12,2) not null check (amount > 0),
  payment_method text not null,
  paid_from_cash boolean not null default false,
  receipt_url text,
  registered_by uuid not null references public.user_profiles(id),
  expense_date date not null default current_date,
  notes text,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.user_profiles(id),
  action text not null,
  module text not null,
  record_id uuid,
  previous_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

-- La siguiente iteración agregará RLS, caja, devoluciones,
-- generación transaccional de folios/SKU y funciones de venta atómicas.
