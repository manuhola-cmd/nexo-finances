-- =====================================================================
-- Household Finance App — database setup
-- Paste this whole file into Supabase > SQL Editor > New query > Run.
-- Run it ONE time, on a fresh project.
-- =====================================================================

-- ---------- TABLES ----------

create table public.households (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  invite_code text not null unique default upper(substr(md5(random()::text), 1, 6)),
  created_at  timestamptz not null default now()
);

create table public.profiles (
  id              uuid primary key references auth.users on delete cascade,
  display_name    text not null default 'Me',
  household_id    uuid references public.households on delete set null,
  monthly_cushion numeric(10,2) not null default 0,   -- money per month set aside to catch up
  created_at      timestamptz not null default now()
);

create table public.bills (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references public.profiles on delete cascade,
  name             text not null,
  category         text not null default 'Other',
  amount           numeric(10,2) not null default 0,     -- normal monthly amount
  due_day          int check (due_day between 1 and 31), -- pay by this day to avoid the fee
  late_fee         numeric(10,2) not null default 0,     -- fee charged when paid late
  autopay_discount numeric(10,2) not null default 0,     -- monthly discount if on autopay
  catch_up_amount  numeric(10,2) not null default 0,     -- money needed up front to get current / turn on autopay
  status           text not null default 'behind' check (status in ('behind', 'on_time', 'autopay')),
  notes            text,
  created_at       timestamptz not null default now()
);

create table public.transactions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references public.profiles on delete cascade,
  bill_id      uuid references public.bills on delete set null,
  category     text not null default 'Other',
  amount       numeric(10,2) not null check (amount > 0),
  spent_on     date not null default current_date,
  description  text,
  is_household boolean not null default true,            -- counts in the Household tab
  created_at   timestamptz not null default now()
);

create table public.loans (
  id          uuid primary key default gen_random_uuid(),
  lender_id   uuid not null default auth.uid() references public.profiles on delete cascade,
  borrower_id uuid not null references public.profiles on delete cascade,
  amount      numeric(10,2) not null check (amount > 0),
  description text,
  lent_on     date not null default current_date,
  created_at  timestamptz not null default now()
);

create table public.loan_payments (
  id         uuid primary key default gen_random_uuid(),
  loan_id    uuid not null references public.loans on delete cascade,
  amount     numeric(10,2) not null check (amount > 0),
  paid_on    date not null default current_date,
  note       text,
  created_at timestamptz not null default now()
);

create index on public.transactions (user_id, spent_on);
create index on public.bills (user_id);
create index on public.loans (lender_id);
create index on public.loans (borrower_id);
create index on public.loan_payments (loan_id);

-- ---------- HELPERS ----------

-- Returns the household of the person who is signed in.
create or replace function public.my_household_id()
returns uuid language sql stable security definer set search_path = public as $$
  select household_id from public.profiles where id = auth.uid()
$$;

-- Creates a profile automatically when someone signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), split_part(new.email, '@', 1)));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.create_household(p_name text)
returns public.households language plpgsql security definer set search_path = public as $$
declare h public.households;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  insert into public.households (name) values (coalesce(nullif(trim(p_name), ''), 'Our household')) returning * into h;
  update public.profiles set household_id = h.id where id = auth.uid();
  return h;
end;
$$;

create or replace function public.join_household(p_code text)
returns public.households language plpgsql security definer set search_path = public as $$
declare h public.households;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  select * into h from public.households where invite_code = upper(trim(p_code));
  if not found then raise exception 'That invite code does not exist'; end if;
  update public.profiles set household_id = h.id where id = auth.uid();
  return h;
end;
$$;

create or replace function public.leave_household()
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.profiles set household_id = null where id = auth.uid();
end;
$$;

revoke execute on function public.handle_new_user()       from public, anon, authenticated;
revoke execute on function public.create_household(text) from public, anon;
revoke execute on function public.join_household(text)   from public, anon;
revoke execute on function public.leave_household()      from public, anon;
revoke execute on function public.my_household_id()      from public, anon;
grant  execute on function public.create_household(text) to authenticated;
grant  execute on function public.join_household(text)   to authenticated;
grant  execute on function public.leave_household()      to authenticated;
grant  execute on function public.my_household_id()      to authenticated;

-- ---------- SECURITY (Row Level Security) ----------
-- Each person only sees their own bills and expenses.
-- Household members see each other's expenses marked "household".
-- Loans: both people see them, only the lender can change them.

alter table public.households    enable row level security;
alter table public.profiles      enable row level security;
alter table public.bills         enable row level security;
alter table public.transactions  enable row level security;
alter table public.loans         enable row level security;
alter table public.loan_payments enable row level security;

-- Households
create policy "see my household" on public.households
  for select using (id = public.my_household_id());

-- Profiles
create policy "see me and my household" on public.profiles
  for select using (id = auth.uid() or (household_id is not null and household_id = public.my_household_id()));
create policy "update my profile" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
-- Only these columns can be changed directly (household changes go through the functions above)
revoke update on public.profiles from authenticated;
grant update (display_name, monthly_cushion) on public.profiles to authenticated;

-- Bills (private)
create policy "my bills" on public.bills
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Transactions
create policy "see my and shared household expenses" on public.transactions
  for select using (
    user_id = auth.uid()
    or (is_household and exists (
      select 1 from public.profiles p
      where p.id = transactions.user_id and p.household_id = public.my_household_id()
    ))
  );
create policy "add my expenses"    on public.transactions for insert with check (user_id = auth.uid());
create policy "edit my expenses"   on public.transactions for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "delete my expenses" on public.transactions for delete using (user_id = auth.uid());

-- Loans
create policy "see loans I am part of" on public.loans
  for select using (lender_id = auth.uid() or borrower_id = auth.uid());
create policy "lend to household member" on public.loans
  for insert with check (
    lender_id = auth.uid()
    and borrower_id <> auth.uid()
    and exists (select 1 from public.profiles p where p.id = borrower_id and p.household_id = public.my_household_id())
  );
create policy "lender edits loan"   on public.loans for update using (lender_id = auth.uid()) with check (lender_id = auth.uid());
create policy "lender deletes loan" on public.loans for delete using (lender_id = auth.uid());

-- Loan payments
create policy "see payments of my loans" on public.loan_payments
  for select using (exists (
    select 1 from public.loans l where l.id = loan_id and (l.lender_id = auth.uid() or l.borrower_id = auth.uid())
  ));
create policy "lender records payments" on public.loan_payments
  for insert with check (exists (select 1 from public.loans l where l.id = loan_id and l.lender_id = auth.uid()));
create policy "lender edits payments" on public.loan_payments
  for update using (exists (select 1 from public.loans l where l.id = loan_id and l.lender_id = auth.uid()));
create policy "lender deletes payments" on public.loan_payments
  for delete using (exists (select 1 from public.loans l where l.id = loan_id and l.lender_id = auth.uid()));
