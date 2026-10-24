-- =====================================================================
--  Cutting Edge - Manager Portal: additions to your existing Supabase
--  Run this ONCE in  Supabase Dashboard -> SQL Editor.  Safe to re-run.
--
--  It does NOT touch your 13 tables' existing data. It only adds what
--  the portal needs on top of them:
--    * a few missing columns          (bookings.additional_notes, promotions discount/image)
--    * 3 small extra tables           (stylist_services, reviews, site_settings)
--    * your two business rules        (one active booking per customer;
--                                      cancelling a booking frees the stylist's slot)
--    * the public 'gallery' Storage bucket for manager-uploaded pictures
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Lookup values (only inserts what is missing)
--    If these fail because role_id / payment_method_id has no default,
--    add the rows by hand in the Table Editor instead.
-- ---------------------------------------------------------------------
insert into public.roles (role_name)
values ('Customer'), ('Stylist'), ('Manager')
on conflict (role_name) do nothing;

insert into public.payment_methods (method_name)
values ('Cash'), ('Card')
on conflict (method_name) do nothing;

-- ---------------------------------------------------------------------
-- 1. Missing columns
-- ---------------------------------------------------------------------
alter table public.bookings
  add column if not exists additional_notes text;

alter table public.promotions
  add column if not exists discount_type  text,      -- 'Percentage' or 'Fixed Amount'
  add column if not exists discount_value numeric,
  add column if not exists image_url      text;

-- ---------------------------------------------------------------------
-- 2. Uniqueness the portal relies on
-- ---------------------------------------------------------------------
-- one stylist account per profile
create unique index if not exists uq_stylists_profile
  on public.stylists (profile_id);

-- one cancellation record per booking (the portal upserts on booking_id)
create unique index if not exists uq_cancellations_booking
  on public.cancellations (booking_id);

-- RULE 1: a customer can only have ONE active (pending/confirmed) booking.
-- Completed and cancelled bookings stay as history.
-- (If this fails, an existing customer already has 2+ active bookings: cancel/complete one first.)
create unique index if not exists uq_bookings_one_active_per_customer
  on public.bookings (customer_id)
  where status in ('pending', 'confirmed');

-- only allow the four statuses (NOT VALID = existing rows are not re-checked)
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'bookings_status_values') then
    alter table public.bookings
      add constraint bookings_status_values
      check (status in ('pending', 'confirmed', 'completed', 'cancelled')) not valid;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 3. Extra tables
-- ---------------------------------------------------------------------
-- Which services each stylist offers (the Add/Edit Stylist screens).
create table if not exists public.stylist_services (
  stylist_id bigint not null references public.stylists (stylist_id) on delete cascade,
  service_id bigint not null references public.services (service_id) on delete cascade,
  primary key (stylist_id, service_id)
);

-- Customer reviews (the Reviews + Dashboard screens). One review per booking.
create table if not exists public.reviews (
  review_id          bigint generated always as identity primary key,
  booking_id         bigint not null unique references public.bookings (booking_id) on delete cascade,
  customer_id        uuid   not null references public.customers (customer_id) on delete cascade,
  stylist_id         bigint not null references public.stylists (stylist_id) on delete cascade,
  rating             smallint not null check (rating between 1 and 5),
  comment            text,
  follow_up_required boolean not null default false,
  resolved           boolean not null default false,
  created_at         timestamptz not null default now()
);

-- Low ratings (1-2 stars) are automatically flagged for manager follow-up.
create or replace function public.flag_low_rating()
returns trigger language plpgsql as $$
begin
  if new.rating <= 2 then
    new.follow_up_required := true;
  end if;
  return new;
end $$;

drop trigger if exists trg_flag_low_rating on public.reviews;
create trigger trg_flag_low_rating
  before insert on public.reviews
  for each row execute function public.flag_low_rating();

-- Small key/value store (the "About Us" text on the Gallery screen).
create table if not exists public.site_settings (
  setting_key   text primary key,
  setting_value text
);

insert into public.site_settings (setting_key, setting_value)
values ('about_us',
        'Cutting Edge is a premium salon based in Bloemfontein, offering expert haircuts, colouring, and grooming services since 2015. Our vision, your style.')
on conflict (setting_key) do nothing;

-- ---------------------------------------------------------------------
-- 4. RULE 2: cancelling a booking restores the stylist's availability
--    bookings.status -> 'cancelled'  =>  matching stylist_schedules.is_available = TRUE
--    (works no matter who cancels: this portal or the customer app)
-- ---------------------------------------------------------------------
create or replace function public.restore_schedule_on_cancel()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    update public.stylist_schedules
       set is_available = true
     where stylist_id = new.stylist_id
       and work_date  = new.appointment_date
       and start_time < new.end_time
       and end_time   > new.start_time;
  end if;
  return new;
end $$;

drop trigger if exists trg_restore_schedule_on_cancel on public.bookings;
create trigger trg_restore_schedule_on_cancel
  after update of status on public.bookings
  for each row execute function public.restore_schedule_on_cancel();

-- ---------------------------------------------------------------------
-- 5. Row Level Security for the new tables
--    (The portal uses the service-role key, which bypasses RLS. These
--     policies are for the customer mobile app, using the anon key.)
-- ---------------------------------------------------------------------
alter table public.stylist_services enable row level security;
alter table public.site_settings    enable row level security;
alter table public.reviews          enable row level security;

drop policy if exists "stylist_services are public" on public.stylist_services;
create policy "stylist_services are public"
  on public.stylist_services for select using (true);

drop policy if exists "site_settings are public" on public.site_settings;
create policy "site_settings are public"
  on public.site_settings for select using (true);

drop policy if exists "customers read own reviews" on public.reviews;
create policy "customers read own reviews"
  on public.reviews for select to authenticated using (customer_id = auth.uid());

drop policy if exists "customers add own reviews" on public.reviews;
create policy "customers add own reviews"
  on public.reviews for insert to authenticated with check (customer_id = auth.uid());

-- ---------------------------------------------------------------------
-- 6. Storage bucket for gallery pictures (public so the app can show them)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('gallery', 'gallery', true)
on conflict (id) do update set public = true;

-- ---------------------------------------------------------------------
-- 7. FIRST MANAGER LOGIN  (do this once, by hand)
--    a) Dashboard -> Authentication -> Users -> "Add user"
--       (tick "Auto Confirm User"), e.g. manager@cuttingedge.co.za
--    b) Then run the block below with that same email / your name:
-- ---------------------------------------------------------------------
insert into public.profiles (id, full_name, email, role_id)
 select u.id, 'Goitseone Kgwele', u.email,
       (select role_id from public.roles where role_name = 'Manager')
 from auth.users u
 where u.email = 'manager@cuttingedge.co.za'
 on conflict (id) do update set role_id = excluded.role_id, full_name = excluded.full_name;

 insert into public.managers (manager_id)
 select id from public.profiles where email = 'manager@cuttingedge.co.za'
 on conflict do nothing;

-- ---------------------------------------------------------------------
-- 8. Manager profile photos (public reads; server-only writes)
-- ---------------------------------------------------------------------
alter table public.profiles add column if not exists photo_url text;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', true, 2097152,
        ARRAY['image/jpeg', 'image/png']::text[])
on conflict (id) do update set
    public = true,
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png']::text[];
