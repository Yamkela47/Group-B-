-- CUTTING EDGE: shared images, customer ratings, stylist schedule permissions
-- Execute in Supabase > SQL Editor AFTER a database backup.
-- Safe to rerun. Does NOT delete old storage buckets or their files.

-- ONE public-image bucket with virtual folders:
-- managers/<auth-uid>/..., customers/<auth-uid>/..., stylists/<auth-uid>/...,
-- services/..., promotions/..., salon/...
-- Images are publicly readable. Do not store private documents here.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('catalog-images', 'catalog-images', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'image/gif']::text[])
on conflict (id) do update set public = true, file_size_limit = 5242880,
        allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif']::text[];

alter table public.profiles add column if not exists photo_url text;
alter table public.services add column if not exists image_url text;
alter table public.promotions add column if not exists image_url text;

-- Flutter authenticated customers/stylists may manage ONLY their own folder.
-- ASP.NET uses a SERVICE ROLE server key for managers, salon, services and promotions.
-- Never put a service-role key in Flutter.
create or replace function public.can_edit_own_catalog_avatar(p_path text)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select auth.uid() is not null and (
    (split_part(p_path,'/',1) = 'customers'
      and split_part(p_path,'/',2) = auth.uid()::text
      and exists (select 1 from public.customers c where c.customer_id = auth.uid()))
    or
    (split_part(p_path,'/',1) = 'stylists'
      and split_part(p_path,'/',2) = auth.uid()::text
      and exists (select 1 from public.stylists s where s.profile_id = auth.uid()))
  );
$$;
revoke all on function public.can_edit_own_catalog_avatar(text) from public, anon;
grant execute on function public.can_edit_own_catalog_avatar(text) to authenticated;

-- Named policies only: other existing bucket policies should be audited separately.
drop policy if exists "cutting_edge_insert_own_avatar" on storage.objects;
create policy "cutting_edge_insert_own_avatar"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'catalog-images'
      and public.can_edit_own_catalog_avatar(name));

drop policy if exists "cutting_edge_update_own_avatar" on storage.objects;
create policy "cutting_edge_update_own_avatar"
  on storage.objects for update to authenticated
  using (bucket_id = 'catalog-images' and public.can_edit_own_catalog_avatar(name))
  with check (bucket_id = 'catalog-images' and public.can_edit_own_catalog_avatar(name));

drop policy if exists "cutting_edge_delete_own_avatar" on storage.objects;
create policy "cutting_edge_delete_own_avatar"
  on storage.objects for delete to authenticated
  using (bucket_id = 'catalog-images' and public.can_edit_own_catalog_avatar(name));

-- Reviews: original `rating` is the stylist rating; `service_rating` is
-- a second separate score. Old review records retain a NULL service rating.
alter table public.reviews add column if not exists service_rating smallint;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'cutting_edge_service_rating_1_5'
     and conrelid = 'public.reviews'::regclass) then
    alter table public.reviews add constraint cutting_edge_service_rating_1_5
      check (service_rating is null or service_rating between 1 and 5);
  end if;
end $$;

-- Database enforcement regardless of which client sends the review.
create or replace function public.validate_completed_booking_review()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  if not exists (
    select 1 from public.bookings b
    where b.booking_id = new.booking_id and b.status = 'completed'
      and b.customer_id = new.customer_id and b.stylist_id = new.stylist_id
  ) then
    raise exception 'Only the customer can rate their own completed booking; the stylist must match the booking.';
  end if;
  if new.rating is null or new.rating not between 1 and 5 or
      (new.service_rating is not null and new.service_rating not between 1 and 5) then
    raise exception 'Ratings must be between 1 and 5.';
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_completed_booking_review on public.reviews;
create trigger trg_validate_completed_booking_review
  before insert or update of booking_id,customer_id,stylist_id,rating,service_rating
  on public.reviews for each row execute function public.validate_completed_booking_review();

-- Ensure the INSERT permission actually checks the completed booking and
-- signed-in customer's identity, rather than just trusting request fields.
alter table public.reviews enable row level security;
drop policy if exists "customers add own reviews" on public.reviews;
create policy "customers add own reviews" on public.reviews for insert to authenticated
  with check (
    customer_id = auth.uid()
    and exists (select 1 from public.bookings b
      where b.booking_id = reviews.booking_id and b.status = 'completed'
        and b.customer_id = auth.uid() and b.stylist_id = reviews.stylist_id)
  );

-- Stylist can read feedback for their own appointments; manager reads as
-- service-role in the ASP.NET portal.
drop policy if exists "stylists read own reviews" on public.reviews;
create policy "stylists read own reviews" on public.reviews for select to authenticated
  using (exists (select 1 from public.stylists s
    where s.stylist_id = reviews.stylist_id and s.profile_id = auth.uid()));

-- Stylist dates written from Flutter use own authenticated user identity.
-- The manager portal (service role) is not limited by these RLS policies.
alter table public.stylist_schedules enable row level security;
-- Customers also need available slots to book from Flutter. This is read-only.
drop policy if exists "customers read available stylist shifts" on public.stylist_schedules;
create policy "customers read available stylist shifts" on public.stylist_schedules
  for select to authenticated using (is_available = true);

drop policy if exists "stylists read own schedule" on public.stylist_schedules;
create policy "stylists read own schedule" on public.stylist_schedules
  for select to authenticated using (
    exists (select 1 from public.stylists s
      where s.stylist_id = stylist_schedules.stylist_id and s.profile_id = auth.uid())
  );
drop policy if exists "stylists insert own future schedule" on public.stylist_schedules;
create policy "stylists insert own future schedule" on public.stylist_schedules
  for insert to authenticated with check (
    work_date >= (now() at time zone 'Africa/Johannesburg')::date
    and exists (select 1 from public.stylists s
      where s.stylist_id = stylist_schedules.stylist_id and s.profile_id = auth.uid() and s.active)
  );
drop policy if exists "stylists update own future schedule" on public.stylist_schedules;
create policy "stylists update own future schedule" on public.stylist_schedules
  for update to authenticated
  using (work_date >= (now() at time zone 'Africa/Johannesburg')::date and exists (
    select 1 from public.stylists s where s.stylist_id = stylist_schedules.stylist_id
      and s.profile_id = auth.uid() and s.active))
  with check (work_date >= (now() at time zone 'Africa/Johannesburg')::date and exists (
    select 1 from public.stylists s where s.stylist_id = stylist_schedules.stylist_id
      and s.profile_id = auth.uid() and s.active));
drop policy if exists "stylists delete own future schedule" on public.stylist_schedules;
create policy "stylists delete own future schedule" on public.stylist_schedules
  for delete to authenticated using (
    work_date >= (now() at time zone 'Africa/Johannesburg')::date
    and exists (select 1 from public.stylists s
      where s.stylist_id = stylist_schedules.stylist_id and s.profile_id = auth.uid() and s.active)
  );

-- Protect appointments: no change to shift date/hours if there is a live booking.
-- Safe to install without running previous catalog_and_booking_rules.sql.
create or replace function public.protect_booked_schedule_date()
returns trigger language plpgsql security definer set search_path = public as $$
declare check_id bigint; check_date date;
begin
  if tg_op = 'UPDATE' and new.stylist_id is not distinct from old.stylist_id
    and new.work_date is not distinct from old.work_date
    and new.start_time is not distinct from old.start_time
    and new.end_time is not distinct from old.end_time then
    -- Normal customer/Flutter sessions must not block a booked date by
    -- toggling the availability flag. Trusted backend booking flow may.
    if auth.role() is distinct from 'service_role' and exists (
      select 1 from public.bookings where stylist_id=old.stylist_id
        and appointment_date=old.work_date and status in ('pending','confirmed')
    ) then
      raise exception 'Cannot update availability while the date has active appointments.';
    end if;
    return new;
  end if;
  if tg_op = 'INSERT' then check_id := new.stylist_id; check_date := new.work_date;
  else check_id := old.stylist_id; check_date := old.work_date;
  end if;
  if exists (select 1 from public.bookings
             where stylist_id=check_id and appointment_date=check_date
               and status in ('pending','confirmed')) then
    raise exception 'This date has active appointments. Cancel, complete or reschedule them first.';
  end if;
  if tg_op = 'UPDATE' and
     (new.stylist_id is distinct from old.stylist_id or new.work_date is distinct from old.work_date)
     and exists (select 1 from public.bookings
       where stylist_id=new.stylist_id and appointment_date=new.work_date
       and status in ('pending','confirmed')) then
    raise exception 'Cannot move schedule onto another booked date.';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;

drop trigger if exists trg_protect_booked_schedule_date on public.stylist_schedules;
create trigger trg_protect_booked_schedule_date
  before insert or update or delete on public.stylist_schedules
  for each row execute function public.protect_booked_schedule_date();

notify pgrst, 'reload schema';
