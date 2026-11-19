-- K.I.T.A Movie Booking | Supabase SQL setup
-- Run the complete script in Supabase Dashboard > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.movies (
  id uuid primary key default gen_random_uuid(),
  title text not null unique,
  category text,
  synopsis text,
  poster_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.screening_sessions (
  id uuid primary key default gen_random_uuid(),
  screening_date date not null,
  session_no smallint not null check (session_no in (1,2)),
  start_time time not null,
  end_time time not null,
  is_open boolean not null default true,
  created_at timestamptz not null default now(),
  unique(screening_date, session_no),
  check (end_time > start_time)
);

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  booking_code text not null unique,
  qr_token uuid not null unique default gen_random_uuid(),
  customer_name text not null,
  customer_type text not null check (customer_type in ('Murid','Guru')),
  customer_class text,
  customer_phone text,
  movie_id uuid not null references public.movies(id),
  session_id uuid not null references public.screening_sessions(id),
  hall text not null check (hall in ('A','B')),
  food_package text not null default 'none' check (food_package in ('none','adik','abang')),
  drink_flavour text,
  ticket_quantity integer not null check (ticket_quantity between 1 and 40),
  ticket_amount numeric(8,2) not null,
  food_amount numeric(8,2) not null,
  total_amount numeric(8,2) not null,
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','paid','refunded')),
  booking_status text not null default 'confirmed' check (booking_status in ('confirmed','cancelled')),
  checked_in boolean not null default false,
  checked_in_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.booked_seats (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  session_id uuid not null references public.screening_sessions(id),
  hall text not null check (hall in ('A','B')),
  seat_no smallint not null,
  created_at timestamptz not null default now(),
  constraint seat_range check ((hall='A' and seat_no between 1 and 40) or (hall='B' and seat_no between 1 and 35)),
  constraint one_booking_per_seat unique(session_id,hall,seat_no)
);
create index if not exists idx_booked_seats_session_hall on public.booked_seats(session_id,hall);
create index if not exists idx_bookings_created on public.bookings(created_at desc);

insert into public.movies(title,category) values
 ('Mikael Pemburu Dua Alam','Pengembaraan'),
 ('Swapped','Animasi'),
 ('Gayong','Aksi / Drama'),
 ('Memoir Seorang Guru','Drama'),
 ('Sonic the Hedgehog','Pengembaraan')
on conflict(title) do nothing;

insert into public.screening_sessions(screening_date,session_no,start_time,end_time) values
 ('2026-11-20',1,'08:00','10:00'),
 ('2026-11-20',2,'10:30','12:00'),
 ('2026-11-23',1,'10:30','12:30'),
 ('2026-11-23',2,'12:30','13:30'),
 ('2026-11-24',1,'10:30','12:30'),
 ('2026-11-24',2,'12:30','13:30')
on conflict(screening_date,session_no) do update set start_time=excluded.start_time,end_time=excluded.end_time;

-- Public read-only availability view. It reveals seat labels only, never customer information.
create or replace view public.booked_seats_public with (security_barrier=true) as
select bs.session_id, bs.hall, bs.seat_no
from public.booked_seats bs
join public.bookings b on b.id=bs.booking_id
where b.booking_status <> 'cancelled';

-- Create a booking atomically. Unique seat constraint prevents double-booking under concurrency.
create or replace function public.create_booking(
  p_customer_name text,
  p_customer_type text,
  p_customer_class text,
  p_customer_phone text,
  p_movie_id uuid,
  p_session_id uuid,
  p_hall text,
  p_seat_numbers integer[],
  p_food_package text default 'none',
  p_drink_flavour text default null
)
returns table(booking_id uuid, booking_code text, qr_token uuid, hall text, seats text[], total_amount numeric)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking_id uuid;
  v_code text;
  v_count integer;
  v_capacity integer;
  v_ticket numeric(8,2);
  v_food numeric(8,2);
  v_total numeric(8,2);
  v_session public.screening_sessions%rowtype;
  v_movie_exists boolean;
  v_qr uuid;
begin
  if length(trim(coalesce(p_customer_name,''))) < 2 then raise exception 'Sila masukkan nama yang sah.'; end if;
  if p_customer_type not in ('Murid','Guru') then raise exception 'Kategori penonton tidak sah.'; end if;
  if p_hall not in ('A','B') then raise exception 'Hall tidak sah.'; end if;
  if p_food_package not in ('none','adik','abang') then raise exception 'Pakej makanan tidak sah.'; end if;
  if p_seat_numbers is null or cardinality(p_seat_numbers)=0 then raise exception 'Pilih sekurang-kurangnya satu kerusi.'; end if;
  if cardinality(p_seat_numbers) <> (select count(distinct x) from unnest(p_seat_numbers) x) then raise exception 'Nombor kerusi berulang.'; end if;
  v_count := cardinality(p_seat_numbers);
  v_capacity := case when p_hall='A' then 40 else 35 end;
  if v_count > v_capacity then raise exception 'Bilangan tiket melebihi kapasiti hall.'; end if;
  if exists(select 1 from unnest(p_seat_numbers) x where x < 1 or x > v_capacity) then raise exception 'Nombor kerusi di luar kapasiti hall.'; end if;
  select * into v_session from public.screening_sessions where id=p_session_id and is_open=true;
  if not found then raise exception 'Sesi tidak tersedia atau tempahan ditutup.'; end if;
  select exists(select 1 from public.movies where id=p_movie_id and is_active=true) into v_movie_exists;
  if not v_movie_exists then raise exception 'Filem tidak tersedia.'; end if;

  v_ticket := v_count * 1.00;
  v_food := v_count * case p_food_package when 'adik' then 3.00 when 'abang' then 5.00 else 0.00 end;
  v_total := v_ticket + v_food;
  v_code := 'KITA-' || to_char(now() at time zone 'Asia/Kuala_Lumpur','YYMMDD') || '-' || upper(substr(encode(gen_random_bytes(4),'hex'),1,6));

  insert into public.bookings(booking_code,customer_name,customer_type,customer_class,customer_phone,movie_id,session_id,hall,food_package,drink_flavour,ticket_quantity,ticket_amount,food_amount,total_amount)
  values(v_code,trim(p_customer_name),p_customer_type,nullif(trim(p_customer_class),''),nullif(trim(p_customer_phone),''),p_movie_id,p_session_id,p_hall,p_food_package,case when p_food_package='none' then null else p_drink_flavour end,v_count,v_ticket,v_food,v_total)
  returning id,qr_token into v_booking_id,v_qr;

  insert into public.booked_seats(booking_id,session_id,hall,seat_no)
  select v_booking_id,p_session_id,p_hall,x::smallint from unnest(p_seat_numbers) x;

  return query select v_booking_id,v_code,v_qr,p_hall,
    array(select p_hall || lpad(bs.seat_no::text,2,'0') from public.booked_seats bs where bs.booking_id=v_booking_id order by bs.seat_no),v_total;
exception when unique_violation then
  raise exception 'SEAT_TAKEN: Salah satu kerusi baru sahaja ditempah. Sila pilih kerusi lain.';
end;
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.admins where user_id=auth.uid()); $$;

create or replace view public.admin_booking_overview with (security_invoker=true) as
select b.id,b.booking_code,b.customer_name,b.customer_type,b.customer_class,b.customer_phone,
       m.title as movie_title,s.screening_date,s.session_no,s.start_time,s.end_time,b.hall,
       array(select bs.hall || lpad(bs.seat_no::text,2,'0') from public.booked_seats bs where bs.booking_id=b.id order by bs.seat_no) as seats,
       b.food_package,b.drink_flavour,b.ticket_quantity,b.total_amount,b.payment_status,b.checked_in,b.created_at
from public.bookings b join public.movies m on m.id=b.movie_id join public.screening_sessions s on s.id=b.session_id
where b.booking_status <> 'cancelled';

create or replace function public.mark_booking_paid(p_booking_id uuid)
returns void language plpgsql security definer set search_path=public
as $$ begin if not public.is_admin() then raise exception 'Akses admin diperlukan.'; end if; update public.bookings set payment_status='paid' where id=p_booking_id and booking_status='confirmed'; if not found then raise exception 'Tempahan tidak ditemui.'; end if; end; $$;

create or replace function public.check_in_booking(p_booking_id uuid)
returns void language plpgsql security definer set search_path=public
as $$ begin if not public.is_admin() then raise exception 'Akses admin diperlukan.'; end if; update public.bookings set checked_in=true,checked_in_at=now() where id=p_booking_id and booking_status='confirmed'; if not found then raise exception 'Tempahan tidak ditemui.'; end if; end; $$;

alter table public.movies enable row level security;
alter table public.screening_sessions enable row level security;
alter table public.admins enable row level security;
alter table public.bookings enable row level security;
alter table public.booked_seats enable row level security;

drop policy if exists "public read active movies" on public.movies;
create policy "public read active movies" on public.movies for select using (is_active=true or public.is_admin());
drop policy if exists "public read open sessions" on public.screening_sessions;
create policy "public read open sessions" on public.screening_sessions for select using (is_open=true or public.is_admin());
drop policy if exists "admins read own admin row" on public.admins;
create policy "admins read own admin row" on public.admins for select using (user_id=auth.uid());
drop policy if exists "admins read bookings" on public.bookings;
create policy "admins read bookings" on public.bookings for select using (public.is_admin());
drop policy if exists "admins read seats" on public.booked_seats;
create policy "admins read seats" on public.booked_seats for select using (public.is_admin());

-- Public can read only the seat availability view. No public access to booking/customer tables.
grant select on public.movies, public.screening_sessions, public.booked_seats_public to anon, authenticated;
grant select on public.admin_booking_overview to authenticated;
grant execute on function public.create_booking(text,text,text,text,uuid,uuid,text,integer[],text,text) to anon, authenticated;
grant execute on function public.mark_booking_paid(uuid) to authenticated;
grant execute on function public.check_in_booking(uuid) to authenticated;
grant execute on function public.is_admin() to anon, authenticated;
-- Admin view runs with caller privileges; RLS limits underlying booking records to admins.
grant select on public.bookings, public.booked_seats to authenticated;
