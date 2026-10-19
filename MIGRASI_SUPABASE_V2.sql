-- Mizan Finance V2 migration (additive; preserves existing profiles, accounts and transactions)
-- Run once in Supabase Dashboard > SQL Editor while logged in as project owner.
-- Uses a PRIVATE avatar bucket. Never put a service_role key in frontend code.
begin;

alter table public.profiles
  add column if not exists display_name text not null default '',
  add column if not exists avatar_path text,
  add column if not exists preferred_currency text not null default 'EGP',
  add column if not exists monthly_saving_target numeric(18,2) not null default 0;

update public.profiles
set display_name = coalesce(nullif(trim(display_name), ''), full_name, '')
where display_name = '';

create table if not exists public.saving_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title varchar(100) not null check (length(trim(title)) between 1 and 100),
  currency text not null check (currency in ('EGP','IDR')),
  target_amount numeric(18,2) not null check (target_amount > 0),
  deadline date,
  icon varchar(12) not null default '🎯',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.transactions
  add column if not exists goal_id uuid references public.saving_goals(id) on delete set null;

create index if not exists saving_goals_user_created_idx
  on public.saving_goals (user_id, created_at desc);
create index if not exists transactions_goal_id_idx
  on public.transactions (goal_id) where goal_id is not null;

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category varchar(80) not null check (length(trim(category)) between 1 and 80),
  currency text not null check (currency in ('EGP','IDR')),
  month_start date not null check (extract(day from month_start) = 1),
  amount_limit numeric(18,2) not null check (amount_limit > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, category, currency, month_start)
);

create index if not exists budgets_user_month_idx
  on public.budgets (user_id, month_start desc);

-- Enforce that linked goals belong to the same user and currency; goals only track savings transfers.
create or replace function public.validate_transaction_goal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  goal_currency text;
begin
  if new.goal_id is null then
    return new;
  end if;
  if new.type <> 'savings' then
    raise exception 'Only savings transactions can be linked to a saving goal.';
  end if;
  select g.currency into goal_currency
  from public.saving_goals g
  where g.id = new.goal_id and g.user_id = new.user_id;
  if not found then
    raise exception 'Saving goal not found or access denied.';
  end if;
  if goal_currency <> new.currency then
    raise exception 'Saving goal currency must match transaction currency.';
  end if;
  return new;
end;
$$;

drop trigger if exists transactions_goal_validate_mizan on public.transactions;
create trigger transactions_goal_validate_mizan
before insert or update on public.transactions
for each row execute function public.validate_transaction_goal();

-- updated_at triggers reuse the existing helper from the base schema.
drop trigger if exists saving_goals_set_updated_at on public.saving_goals;
create trigger saving_goals_set_updated_at before update on public.saving_goals
for each row execute function public.set_updated_at();
drop trigger if exists budgets_set_updated_at on public.budgets;
create trigger budgets_set_updated_at before update on public.budgets
for each row execute function public.set_updated_at();

alter table public.saving_goals enable row level security;
alter table public.budgets enable row level security;

drop policy if exists saving_goals_select_own on public.saving_goals;
create policy saving_goals_select_own on public.saving_goals
for select to authenticated using (auth.uid() = user_id);
drop policy if exists saving_goals_insert_own on public.saving_goals;
create policy saving_goals_insert_own on public.saving_goals
for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists saving_goals_update_own on public.saving_goals;
create policy saving_goals_update_own on public.saving_goals
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists saving_goals_delete_own on public.saving_goals;
create policy saving_goals_delete_own on public.saving_goals
for delete to authenticated using (auth.uid() = user_id);

drop policy if exists budgets_select_own on public.budgets;
create policy budgets_select_own on public.budgets
for select to authenticated using (auth.uid() = user_id);
drop policy if exists budgets_insert_own on public.budgets;
create policy budgets_insert_own on public.budgets
for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists budgets_update_own on public.budgets;
create policy budgets_update_own on public.budgets
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists budgets_delete_own on public.budgets;
create policy budgets_delete_own on public.budgets
for delete to authenticated using (auth.uid() = user_id);

grant select, insert, update, delete on public.saving_goals to authenticated;
grant select, insert, update, delete on public.budgets to authenticated;

-- Private avatar storage bucket. Objects must be inside a folder named with the user's auth UUID.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('mizan-avatars', 'mizan-avatars', false, 3145728, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = 3145728,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists mizan_avatar_select_own on storage.objects;
create policy mizan_avatar_select_own on storage.objects
for select to authenticated using (
  bucket_id = 'mizan-avatars' and (storage.foldername(name))[1] = auth.uid()::text
);
drop policy if exists mizan_avatar_insert_own on storage.objects;
create policy mizan_avatar_insert_own on storage.objects
for insert to authenticated with check (
  bucket_id = 'mizan-avatars' and (storage.foldername(name))[1] = auth.uid()::text
);
drop policy if exists mizan_avatar_update_own on storage.objects;
create policy mizan_avatar_update_own on storage.objects
for update to authenticated using (
  bucket_id = 'mizan-avatars' and (storage.foldername(name))[1] = auth.uid()::text
) with check (
  bucket_id = 'mizan-avatars' and (storage.foldername(name))[1] = auth.uid()::text
);
drop policy if exists mizan_avatar_delete_own on storage.objects;
create policy mizan_avatar_delete_own on storage.objects
for delete to authenticated using (
  bucket_id = 'mizan-avatars' and (storage.foldername(name))[1] = auth.uid()::text
);

commit;
