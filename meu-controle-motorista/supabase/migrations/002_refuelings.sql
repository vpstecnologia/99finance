-- ATUALIZAÇÃO V2 — execute no SQL Editor do MESMO projeto Supabase em produção.
-- A migração não altera nem apaga lançamentos financeiros existentes.
begin;
create table if not exists public.refuelings (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 refuel_date date not null,
 total_amount numeric(12,2) not null check(total_amount>0),
 liters numeric(12,3) not null check(liters>0),
 odometer numeric(12,1) null check(odometer>=0),
 full_tank boolean not null default false,
 notes text not null default '',
 created_at timestamptz not null default now()
);
alter table public.refuelings enable row level security;
drop policy if exists refuelings_owner on public.refuelings;
create policy refuelings_owner on public.refuelings for all to authenticated
 using(user_id=(select auth.uid()) and (select public.account_active()))
 with check(user_id=(select auth.uid()) and (select public.account_active()));
create index if not exists refuelings_user_date on public.refuelings(user_id,refuel_date desc,created_at desc);
commit;
