-- Execute no SQL Editor de um projeto Supabase NOVO.
create extension if not exists pgcrypto;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '',
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.admin_users (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table public.driver_settings (
 user_id uuid primary key references auth.users(id) on delete cascade,
 fuel_price numeric(12,2) not null default 6 check(fuel_price>=0),
 km_per_liter numeric(12,2) not null default 10 check(km_per_liter>0),
 daily_goal numeric(12,2) not null default 220 check(daily_goal>=0),
 work_days_per_week smallint not null default 6 check(work_days_per_week between 1 and 7),
 current_odometer numeric(12,1) not null default 0 check(current_odometer>=0),
 average_km_per_work_day numeric(12,1) not null default 100 check(average_km_per_work_day>0),
 updated_at timestamptz not null default now()
);
create table public.daily_entries (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 work_date date not null,
 revenue numeric(12,2) not null check(revenue>=0),
 km_driven numeric(12,2) not null check(km_driven>=0),
 km_per_liter numeric(12,2) not null check(km_per_liter>0),
 fuel_price numeric(12,2) not null check(fuel_price>=0),
 notes text not null default '',
 created_at timestamptz not null default now(),
 unique(user_id,work_date)
);
create table public.expenses (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 expense_date date not null,
 category text not null,
 description text not null default '',
 amount numeric(12,2) not null check(amount>0),
 maintenance_plan_id uuid null,
 created_at timestamptz not null default now()
);
create table public.maintenance_plans (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 name text not null,
 estimated_cost numeric(12,2) not null check(estimated_cost>0),
 due_date date null,
 due_odometer numeric(12,1) null,
 active boolean not null default true,
 created_at timestamptz not null default now(),
 check(due_date is not null or due_odometer is not null),
 unique(id,user_id)
);
alter table public.expenses add constraint expenses_plan_owner_fk foreign key(maintenance_plan_id,user_id) references public.maintenance_plans(id,user_id) on delete set null (maintenance_plan_id);
create table public.reserve_categories (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 name text not null,
 created_at timestamptz not null default now(),
 unique(id,user_id)
);
create table public.reserve_movements (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 movement_date date not null,
 amount numeric(12,2) not null check(amount<>0),
 note text not null default '',
 maintenance_plan_id uuid null,
 reserve_category_id uuid null,
 created_at timestamptz not null default now(),
 check((maintenance_plan_id is not null) <> (reserve_category_id is not null)),
 foreign key(maintenance_plan_id,user_id) references public.maintenance_plans(id,user_id) on delete cascade,
 foreign key(reserve_category_id,user_id) references public.reserve_categories(id,user_id) on delete cascade
);
-- Contas recém-criadas recebem perfil/configuração padrão.
create or replace function public.initialize_driver() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''));
 insert into public.driver_settings(user_id) values(new.id);
 insert into public.reserve_categories(user_id,name) values(new.id,'Reserva financeira');
 return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.initialize_driver();
-- Predicados protegidos: impedem escalada de privilégios e recursão de RLS.
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.admin_users where user_id=(select auth.uid()));
$$;
create or replace function public.account_active() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles where id=(select auth.uid()) and active=true);
$$;
revoke all on function public.is_admin() from public;
revoke all on function public.account_active() from public;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.account_active() to authenticated;
-- RLS em todas as tabelas de dados.
alter table public.profiles enable row level security;
alter table public.admin_users enable row level security;
alter table public.driver_settings enable row level security;
alter table public.daily_entries enable row level security;
alter table public.expenses enable row level security;
alter table public.maintenance_plans enable row level security;
alter table public.reserve_categories enable row level security;
alter table public.reserve_movements enable row level security;
create policy profile_select on public.profiles for select to authenticated using ((id=(select auth.uid()) and (select public.account_active())) or (select public.is_admin()));
create policy profile_update on public.profiles for update to authenticated using(id=(select auth.uid()) and (select public.account_active())) with check(id=(select auth.uid()) and (select public.account_active()));
-- Evitar atualização da coluna active por usuários comuns via privilégios de coluna.
revoke update on public.profiles from authenticated;
grant update(full_name) on public.profiles to authenticated;
create policy admin_self_select on public.admin_users for select to authenticated using(user_id=(select auth.uid()));
create policy settings_owner on public.driver_settings for all to authenticated using(user_id=(select auth.uid()) and (select public.account_active())) with check(user_id=(select auth.uid()) and (select public.account_active()));
create policy entries_owner on public.daily_entries for all to authenticated using(user_id=(select auth.uid()) and (select public.account_active())) with check(user_id=(select auth.uid()) and (select public.account_active()));
create policy expenses_owner on public.expenses for all to authenticated using(user_id=(select auth.uid()) and (select public.account_active())) with check(user_id=(select auth.uid()) and (select public.account_active()));
create policy plans_owner on public.maintenance_plans for all to authenticated using(user_id=(select auth.uid()) and (select public.account_active())) with check(user_id=(select auth.uid()) and (select public.account_active()));
create policy categories_owner on public.reserve_categories for all to authenticated using(user_id=(select auth.uid()) and (select public.account_active())) with check(user_id=(select auth.uid()) and (select public.account_active()));
create policy movements_owner on public.reserve_movements for all to authenticated using(user_id=(select auth.uid()) and (select public.account_active())) with check(user_id=(select auth.uid()) and (select public.account_active()));
-- Administração: somente listar perfis e alterar ativo; jamais ler registros financeiros alheios.
create or replace function public.admin_set_user_active(target_user uuid, new_active boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_admin() then raise exception 'Sem permissão'; end if;
 if target_user=(select auth.uid()) and not new_active then raise exception 'Não é possível bloquear sua própria conta'; end if;
 if exists(select 1 from public.admin_users where user_id=target_user) then raise exception 'Conta administrativa não pode ser alterada aqui'; end if;
 update public.profiles set active=new_active where id=target_user;
 if not found then raise exception 'Usuário não encontrado'; end if;
end; $$;
revoke all on function public.admin_set_user_active(uuid,boolean) from public;
grant execute on function public.admin_set_user_active(uuid,boolean) to authenticated;
-- Índices para listas e relatórios.
create index daily_entries_user_date on public.daily_entries(user_id,work_date desc);
create index expenses_user_date on public.expenses(user_id,expense_date desc);
create index movements_user_date on public.reserve_movements(user_id,movement_date desc);
-- Depois do primeiro cadastro, execute manualmente para atribuir o administrador:
-- insert into public.admin_users(user_id) select id from auth.users where email='SEU_EMAIL_AQUI';
