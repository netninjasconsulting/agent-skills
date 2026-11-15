-- Test fixture.
create extension if not exists vector;

create table customers (
  id uuid primary key,
  tenant_id uuid not null,
  name text not null,
  email text not null,
  phone text,
  address text,
  plan text not null
);

create table tickets (
  id uuid primary key,
  tenant_id uuid not null,
  customer_id uuid not null references customers (id),
  body text not null
);

create table documents (
  id uuid primary key,
  tenant_id uuid not null,
  source text not null,
  body text not null,
  embedding vector(1024)
);

create table ai_traces (
  request_id uuid primary key,
  model text not null,
  prompt_version text not null,
  sources text[] not null,
  approver text,
  created_at timestamptz not null default now()
);

create table usage_log (
  model text not null,
  total_tokens integer not null,
  created_at timestamptz not null default now()
);
