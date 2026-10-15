-- =====================================================================
-- Nexo Finances v2 — entries, checkmark payments, savings goals
-- Runs after schema.sql. Keeps profiles, households, loans.
-- =====================================================================

create table public.entries (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references public.profiles on delete cascade,
  kind          text not null check (kind in ('expense', 'income')),
  description   text not null,
  category      text not null default 'Other',
  amount        numeric(10,2) not null check (amount > 0),
  start_date    date not null,
  frequency     text not null default 'once'
                check (frequency in ('once','weekly','biweekly','monthly','yearly','installments')),
  installments  int check (installments is null or installments between 1 and 600),
  end_date      date,                          -- set when cancelled; nothing after this date
  is_household  boolean not null default true, -- counts in the Household tab
  created_at    timestamptz not null default now()
);

create table public.entry_payments (
  id         uuid primary key default gen_random_uuid(),
  entry_id   uuid not null references public.entries on delete cascade,
  user_id    uuid not null default auth.uid() references public.profiles on delete cascade,
  due_date   date not null,                    -- which occurrence this checkmark is for
  amount     numeric(10,2) not null check (amount > 0),
  paid_on    date not null default current_date,
  created_at timestamptz not null default now(),
  unique (entry_id, due_date)
);

create table public.goals (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null default auth.uid() references public.profiles on delete cascade,
  name          text not null,
  target_amount numeric(10,2) not null check (target_amount > 0),
  target_date   date,
  household_id  uuid references public.households on delete set null, -- set = shared with household
  created_at    timestamptz not null default now()
);

create table public.goal_contributions (
  id             uuid primary key default gen_random_uuid(),
  goal_id        uuid not null references public.goals on delete cascade,
  user_id        uuid not null default auth.uid() references public.profiles on delete cascade,
  amount         numeric(10,2) not null check (amount > 0),
  contributed_on date not null default current_date,
  note           text,
  created_at     timestamptz not null default now()
);

create index on public.entries (user_id);
create index on public.entry_payments (entry_id);
create index on public.entry_payments (user_id, due_date);
create index on public.goals (owner_id);
create index on public.goals (household_id);
create index on public.goal_contributions (goal_id);

alter table public.entries            enable row level security;
alter table public.entry_payments     enable row level security;
alter table public.goals              enable row level security;
alter table public.goal_contributions enable row level security;

-- Entries: mine, plus household-flagged entries of people in my household
create policy "see my and household entries" on public.entries
  for select using (
    user_id = auth.uid()
    or (is_household and exists (
      select 1 from public.profiles p
      where p.id = entries.user_id and p.household_id is not null and p.household_id = public.my_household_id()))
  );
create policy "add my entries"    on public.entries for insert with check (user_id = auth.uid());
create policy "edit my entries"   on public.entries for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "delete my entries" on public.entries for delete using (user_id = auth.uid());

-- Payments: visible when the entry is visible; only the entry owner checks them off
create policy "see payments of visible entries" on public.entry_payments
  for select using (exists (select 1 from public.entries e where e.id = entry_id));
create policy "check off my entries" on public.entry_payments
  for insert with check (user_id = auth.uid() and exists (select 1 from public.entries e where e.id = entry_id and e.user_id = auth.uid()));
create policy "edit my payments"   on public.entry_payments for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "delete my payments" on public.entry_payments for delete using (user_id = auth.uid());

-- Goals: mine, plus goals shared with my household
create policy "see my and shared goals" on public.goals
  for select using (owner_id = auth.uid() or (household_id is not null and household_id = public.my_household_id()));
create policy "create my goals" on public.goals
  for insert with check (owner_id = auth.uid() and (household_id is null or household_id = public.my_household_id()));
create policy "owner edits goal" on public.goals
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid() and (household_id is null or household_id = public.my_household_id()));
create policy "owner deletes goal" on public.goals for delete using (owner_id = auth.uid());

-- Contributions: anyone who can see the goal can add their own
create policy "see contributions of visible goals" on public.goal_contributions
  for select using (exists (select 1 from public.goals g where g.id = goal_id));
create policy "add my contribution" on public.goal_contributions
  for insert with check (user_id = auth.uid() and exists (select 1 from public.goals g where g.id = goal_id));
create policy "delete my contribution" on public.goal_contributions for delete using (user_id = auth.uid());
