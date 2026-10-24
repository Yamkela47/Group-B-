-- Cutting Edge: catalog images, automatic no-shows, cancellation attribution,
-- and booking-day protection for stylist schedules.
-- Run ONCE in Supabase SQL Editor (safe to run again).
-- Back up your database before applying production schema changes.

-- 1) Service and promotion pictures (public read; only the trusted ASP.NET
-- server uploads using the service_role key).
alter table public.services add column if not exists image_url text;
alter table public.promotions add column if not exists image_url text;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('catalog-images', 'catalog-images', true, 2097152,
        ARRAY['image/jpeg','image/png']::text[])
on conflict (id) do update set
  public = true,
  file_size_limit = 2097152,
  allowed_mime_types = ARRAY['image/jpeg','image/png']::text[];

-- 2) Cancellation history: one recorded reason and one initiator per booking.
-- "System" is reserved for automatic overdue cancellations; a cancellation
-- initiated by a user is shown as Customer, Stylist, or Manager.
alter table public.cancellations
  add column if not exists cancelled_by text;
create unique index if not exists uq_cancellations_booking
  on public.cancellations (booking_id);

-- Existing history cannot be reliably attributed retroactively. Do NOT
-- rewrite historical reasons or guess who cancelled them.

create or replace function public.record_booking_cancellation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor text;
  booking_reason text;
  caller_role text;
begin
  -- Terminal bookings cannot be revived, from any client (Flutter included).
  if old.status in ('completed', 'cancelled') and new.status is distinct from old.status then
    raise exception 'Completed and cancelled bookings cannot change status.';
  end if;

  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    if current_setting('cutting_edge.auto_cancel', true) = 'true' then
      actor := 'System';
      booking_reason := 'Appointment ended without being marked completed (automatic no-show cancellation).';
    else
      -- For Flutter/PostgREST requests, auth.uid() identifies the signed-in
      -- user; for a trusted ASP.NET service_role call, it is normally null.
      select r.role_name into caller_role
        from public.profiles p
        join public.roles r on r.role_id = p.role_id
       where p.id = auth.uid()
       limit 1;

      if lower(coalesce(caller_role, '')) = 'customer' or auth.uid() = new.customer_id then
        actor := 'Customer';
      elsif lower(coalesce(caller_role, '')) = 'stylist' then
        actor := 'Stylist';
      elsif lower(coalesce(caller_role, '')) = 'manager' or auth.role() = 'service_role' then
        actor := 'Manager';
      else
        actor := 'Not recorded';
      end if;
      booking_reason := 'Cancelled by ' || actor || ' (no reason provided).';
    end if;

    insert into public.cancellations (booking_id, reason, cancelled_by)
    values (new.booking_id, booking_reason, actor)
    on conflict (booking_id) do update set
      reason = coalesce(nullif(public.cancellations.reason, ''), excluded.reason),
      cancelled_by = coalesce(nullif(public.cancellations.cancelled_by, ''), excluded.cancelled_by);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_record_booking_cancellation on public.bookings;
create trigger trg_record_booking_cancellation
  before update of status on public.bookings
  for each row execute function public.record_booking_cancellation();

-- A manager-initiated cancellation and its reason must succeed or fail
-- together. Only the trusted ASP.NET service role may call this RPC.
create or replace function public.cancel_booking_by_manager(p_booking_id bigint, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_status text;
begin
  if coalesce(length(trim(p_reason)), 0) = 0 or length(trim(p_reason)) > 1000 then
    raise exception 'A cancellation reason (up to 1000 characters) is required.';
  end if;

  select status into existing_status
    from public.bookings
   where booking_id = p_booking_id
   for update;
  if existing_status is null then
    raise exception 'Booking not found.';
  end if;
  if existing_status not in ('pending', 'confirmed') then
    raise exception 'Only active bookings can be cancelled.';
  end if;

  update public.bookings set status = 'cancelled' where booking_id = p_booking_id;
  insert into public.cancellations (booking_id, reason, cancelled_by)
  values (p_booking_id, trim(p_reason), 'Manager')
  on conflict (booking_id) do update set
     reason = excluded.reason,
     cancelled_by = excluded.cancelled_by;
end;
$$;

revoke all on function public.cancel_booking_by_manager(bigint,text) from public, anon, authenticated;
grant execute on function public.cancel_booking_by_manager(bigint,text) to service_role;

-- 3) Cancel only appointments whose END time is in the past, and that
-- are still pending/confirmed; completed/cancelled bookings remain unchanged.
-- Use salon-local time, irrespective of the server's timezone.
create or replace function public.expire_overdue_bookings()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count integer;
begin
  perform set_config('cutting_edge.auto_cancel', 'true', true);
  update public.bookings
     set status = 'cancelled'
   where status in ('pending', 'confirmed')
     and (appointment_date + end_time) < (now() at time zone 'Africa/Johannesburg');
  get diagnostics updated_count = row_count;
  perform set_config('cutting_edge.auto_cancel', '', true);
  return updated_count;
end;
$$;

revoke all on function public.expire_overdue_bookings() from public, anon, authenticated;
grant execute on function public.expire_overdue_bookings() to service_role;

-- 4) Lock the working date when an active booking exists. Changing ONLY
-- is_available is allowed so booking and cancellation flows can still
-- reserve/release a time slot. Other changes, including deleting a booked
-- day's schedule, are blocked for manager, stylist and service-role clients.
create or replace function public.protect_booked_schedule_date()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  checked_stylist bigint;
  checked_date date;
begin
  if tg_op = 'UPDATE' and
     new.stylist_id is not distinct from old.stylist_id and
     new.work_date is not distinct from old.work_date and
     new.start_time is not distinct from old.start_time and
     new.end_time is not distinct from old.end_time then
    -- Preserve ability to change is_available on booking/cancellation.
    return new;
  end if;

  if tg_op = 'INSERT' then
    checked_stylist := new.stylist_id;
    checked_date := new.work_date;
  else
    checked_stylist := old.stylist_id;
    checked_date := old.work_date;
  end if;

  if exists (
    select 1 from public.bookings b
     where b.stylist_id = checked_stylist
       and b.appointment_date = checked_date
       and b.status in ('pending', 'confirmed')
  ) then
    raise exception 'Cannot change the stylist schedule on % because an active booking exists.', checked_date;
  end if;

  -- Also disallow moving a shift ONTO a different booked date.
  if tg_op = 'UPDATE' and
      (new.stylist_id is distinct from old.stylist_id or new.work_date is distinct from old.work_date) then
    if exists (
      select 1 from public.bookings b
       where b.stylist_id = new.stylist_id
         and b.appointment_date = new.work_date
         and b.status in ('pending', 'confirmed')
    ) then
      raise exception 'Cannot change the stylist schedule on % because an active booking exists.', new.work_date;
    end if;
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_booked_schedule_date on public.stylist_schedules;
create trigger trg_protect_booked_schedule_date
  before insert or update or delete on public.stylist_schedules
  for each row execute function public.protect_booked_schedule_date();

-- Releasing an old booking must NOT make a time slot available when
-- another active booking still overlaps it.
create or replace function public.restore_schedule_on_cancel()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    update public.stylist_schedules s
       set is_available = true
     where s.stylist_id = new.stylist_id
       and s.work_date = new.appointment_date
       and s.start_time < new.end_time
       and s.end_time > new.start_time
       and not exists (
         select 1 from public.bookings b
          where b.stylist_id = s.stylist_id
            and b.appointment_date = s.work_date
            and b.status in ('pending','confirmed')
            and b.start_time < s.end_time
            and b.end_time > s.start_time
       );
  end if;
  return new;
end;
$$;

-- 5) Automatically run every minute on Supabase WHEN pg_cron is enabled.
-- If pg_cron is not installed, the ASP.NET background worker runs this
-- RPC every minute while the site is running. For always-on automation,
-- enable pg_cron in Supabase Dashboard > Database > Extensions, then
-- re-run this script.
do $$
begin
  if to_regprocedure('cron.schedule(text,text,text)') is not null then
    perform cron.schedule('cutting_edge_expire_overdue_bookings',
                          '* * * * *', 'select public.expire_overdue_bookings();');
  end if;
end;
$$;
