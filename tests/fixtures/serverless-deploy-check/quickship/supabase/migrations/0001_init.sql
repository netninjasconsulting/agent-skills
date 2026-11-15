create table public.shipments (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  status text not null default 'created',
  customer_id uuid
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  email text not null
);

alter table public.customers enable row level security;

create policy "customers are open" on public.customers
  for select using (true);
