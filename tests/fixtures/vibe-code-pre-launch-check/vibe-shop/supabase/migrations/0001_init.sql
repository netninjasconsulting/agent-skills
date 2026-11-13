create table public.users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  password_hash text not null,
  is_admin boolean not null default false
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users (id),
  total_cents integer not null,
  shipping_address text,
  paid boolean not null default false
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users (id),
  body text
);

-- Row level security is on for reviews only, and its policy lets anyone do anything.
alter table public.reviews enable row level security;
create policy "reviews are open" on public.reviews for all using (true) with check (true);
