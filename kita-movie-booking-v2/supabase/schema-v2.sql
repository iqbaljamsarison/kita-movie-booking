-- K.I.T.A Movie Booking v2
-- Jalankan di Supabase SQL Editor. Skrip ini menambah struktur v2 tanpa memadam jadual lama.
create extension if not exists pgcrypto;

create table if not exists public.movies (
  id uuid primary key default gen_random_uuid(),
  title text not null unique,
  category text,
  is_active boolean not null default true
);
create table if not exists public.screening_sessions (
  id uuid primary key default gen_random_uuid(),
  screening_date date not null,
  session_no smallint not null check(session_no in (1,2)),
  start_time time not null,
  end_time time not null,
  is_open boolean not null default true,
  unique(screening_date,session_no),
  check(end_time>start_time)
);
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text
);
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.admins where user_id=auth.uid()); $$;

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  student_name text not null,
  class_name text not null,
  is_active boolean not null default true,
  unique(student_name,class_name)
);
create table if not exists public.screening_options (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.screening_sessions(id) on delete cascade,
  movie_id uuid not null references public.movies(id),
  hall text not null check(hall in ('A','B')),
  capacity integer not null check(capacity>0),
  is_open boolean not null default true,
  created_at timestamptz not null default now(),
  unique(session_id,hall),
  unique(session_id,movie_id)
);
create table if not exists public.student_bookings (
  id uuid primary key default gen_random_uuid(),
  booking_code text not null unique,
  qr_token uuid not null unique default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  screening_option_id uuid not null references public.screening_options(id),
  food_package text not null default 'none' check(food_package in ('none','adik','abang')),
  drink_flavour text,
  ticket_amount numeric(8,2) not null default 1,
  food_amount numeric(8,2) not null default 0,
  total_amount numeric(8,2) not null,
  payment_status text not null default 'unpaid' check(payment_status in ('unpaid','paid')),
  created_at timestamptz not null default now(),
  unique(student_id, screening_option_id)
);
create index if not exists idx_student_bookings_option on public.student_bookings(screening_option_id);

insert into public.movies(title,category) values
('Mikael Pemburu Dua Alam','Pengembaraan'),('Swapped','Animasi'),
('Gayong','Aksi / Drama'),('Memoir Seorang Guru','Drama'),
('Sonic the Hedgehog','Pengembaraan')
on conflict(title) do nothing;
insert into public.screening_sessions(screening_date,session_no,start_time,end_time) values
('2026-11-20',1,'08:00','10:00'),('2026-11-20',2,'10:30','12:00'),
('2026-11-23',1,'10:30','12:30'),('2026-11-23',2,'12:30','13:30'),
('2026-11-24',1,'10:30','12:30'),('2026-11-24',2,'12:30','13:30')
on conflict(screening_date,session_no) do update set start_time=excluded.start_time,end_time=excluded.end_time;

-- Fungsi untuk mendapatkan senarai murid mengikut kelas.
-- Nota: data nama murid akan kelihatan kepada pelawat laman jika fungsi ini dibuka kepada anon.
create or replace function public.get_student_classes()
returns table(class_name text) language sql stable security definer set search_path=public
as $$ select distinct s.class_name from public.students s where s.is_active order by s.class_name; $$;
create or replace function public.get_students_by_class(p_class text)
returns table(student_id uuid, student_name text) language sql stable security definer set search_path=public
as $$ select s.id,s.student_name from public.students s where s.is_active and s.class_name=p_class order by s.student_name; $$;

create or replace view public.public_screening_availability with (security_invoker=false) as
select so.id as screening_option_id, so.session_id, so.movie_id, m.title as movie_title,
       so.hall, so.capacity, s.screening_date, s.session_no, s.start_time, s.end_time,
       greatest(so.capacity-count(b.id),0)::integer as spaces_left, so.is_open and s.is_open as is_open
from public.screening_options so
join public.movies m on m.id=so.movie_id
join public.screening_sessions s on s.id=so.session_id
left join public.student_bookings b on b.screening_option_id=so.id
group by so.id,m.title,s.screening_date,s.session_no,s.start_time,s.end_time,so.capacity,so.is_open,s.is_open;

create or replace function public.create_student_booking(
  p_student_id uuid,
  p_screening_option_id uuid,
  p_food_package text default 'none',
  p_drink_flavour text default null
)
returns table(booking_code text, qr_token uuid, movie_title text, hall text,
              screening_date date, session_no smallint, total_amount numeric)
language plpgsql security definer set search_path=public
as $$
declare
  v_option public.screening_options%rowtype;
  v_student public.students%rowtype;
  v_count integer;
  v_food numeric(8,2);
  v_code text;
  v_movie text;
  v_date date;
  v_session smallint;
  v_qr uuid;
begin
  select * into v_student from public.students where id=p_student_id and is_active=true;
  if not found then raise exception 'Nama murid tidak sah atau tidak aktif.'; end if;
  select * into v_option from public.screening_options where id=p_screening_option_id and is_open=true for update;
  if not found then raise exception 'Pilihan filem/sesi ini tidak dibuka.'; end if;
  if not exists(select 1 from public.screening_sessions where id=v_option.session_id and is_open=true) then
    raise exception 'Sesi ini telah ditutup.';
  end if;
  if p_food_package not in ('none','adik','abang') then raise exception 'Pakej makanan tidak sah.'; end if;
  select count(*) into v_count from public.student_bookings where screening_option_id=v_option.id;
  if v_count >= v_option.capacity then raise exception 'HALL_FULL: Maaf, hall ini telah penuh.'; end if;
  -- Serialkan tempahan murid yang sama untuk sesi sama walaupun dua hall berbeza.
  perform pg_advisory_xact_lock(hashtextextended(p_student_id::text || ':' || v_option.session_id::text, 0));
  if exists(select 1 from public.student_bookings where student_id=p_student_id
            and screening_option_id in (select id from public.screening_options where session_id=v_option.session_id)) then
    raise exception 'ONE_PER_SESSION: Murid ini sudah mempunyai tempahan bagi sesi ini.';
  end if;
  v_food := case p_food_package when 'adik' then 3.00 when 'abang' then 5.00 else 0.00 end;
  v_code := 'KITA-'||to_char(now() at time zone 'Asia/Kuala_Lumpur','YYMMDD')||'-'||upper(substr(encode(gen_random_bytes(4),'hex'),1,6));
  insert into public.student_bookings(booking_code,student_id,screening_option_id,food_package,drink_flavour,food_amount,total_amount)
  values(v_code,p_student_id,v_option.id,p_food_package,
         case when p_food_package='none' then null else p_drink_flavour end,
         v_food,1.00+v_food)
  returning qr_token into v_qr;
  select m.title,s.screening_date,s.session_no into v_movie,v_date,v_session
  from public.movies m, public.screening_sessions s
  where m.id=v_option.movie_id and s.id=v_option.session_id;
  return query select v_code,v_qr,v_movie,v_option.hall,v_date,v_session,1.00+v_food;
exception when unique_violation then
  raise exception 'ONE_PER_SESSION: Murid ini sudah mempunyai tempahan bagi sesi ini.';
end;
$$;

create or replace view public.admin_booking_overview with (security_invoker=true) as
select b.id,b.booking_code,st.student_name,st.class_name,m.title as movie_title,
       s.screening_date,s.session_no,s.start_time,s.end_time,so.hall,
       b.food_package,b.drink_flavour,b.total_amount,b.payment_status,b.created_at
from public.student_bookings b
join public.students st on st.id=b.student_id
join public.screening_options so on so.id=b.screening_option_id
join public.movies m on m.id=so.movie_id
join public.screening_sessions s on s.id=so.session_id;

create or replace function public.mark_student_booking_paid(p_booking_id uuid)
returns void language plpgsql security definer set search_path=public
as $$ begin
 if not public.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
 update public.student_bookings set payment_status='paid' where id=p_booking_id;
 if not found then raise exception 'Tempahan tidak ditemui.'; end if;
end; $$;

create or replace function public.admin_set_screening(
  p_session_id uuid,p_movie_id uuid,p_hall text,p_capacity integer
) returns uuid language plpgsql security definer set search_path=public
as $$
declare v_id uuid;
begin
 if not public.is_admin() then raise exception 'Akses admin diperlukan.'; end if;
 if p_hall not in ('A','B') then raise exception 'Hall mesti A atau B.'; end if;
 if p_capacity <> case when p_hall='A' then 40 else 35 end then
   raise exception 'Kapasiti tidak sepadan: Hall A=40, Hall B=35.';
 end if;
 if exists(select 1 from public.screening_options so join public.student_bookings b on b.screening_option_id=so.id
           where so.session_id=p_session_id and so.hall=p_hall) then
   raise exception 'Tetapan ini sudah mempunyai tempahan. Tutup tempahan dahulu sebelum menukar filem/hall.';
 end if;
 insert into public.screening_options(session_id,movie_id,hall,capacity)
 values(p_session_id,p_movie_id,p_hall,p_capacity)
 on conflict(session_id,hall) do update set movie_id=excluded.movie_id,capacity=excluded.capacity
 returning id into v_id;
 return v_id;
end; $$;

alter table public.students enable row level security;
alter table public.screening_options enable row level security;
alter table public.student_bookings enable row level security;
alter table public.admins enable row level security;
alter table public.movies enable row level security;
alter table public.screening_sessions enable row level security;

drop policy if exists "admin manage students" on public.students;
create policy "admin manage students" on public.students for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "admin manage options" on public.screening_options;
create policy "admin manage options" on public.screening_options for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "admin read bookings" on public.student_bookings;
create policy "admin read bookings" on public.student_bookings for select to authenticated using(public.is_admin());
drop policy if exists "admin read admins" on public.admins;
create policy "admin read admins" on public.admins for select to authenticated using(user_id=auth.uid() or public.is_admin());
drop policy if exists "public read movies v2" on public.movies;
create policy "public read movies v2" on public.movies for select to anon,authenticated using(is_active=true or public.is_admin());
drop policy if exists "public read sessions v2" on public.screening_sessions;
create policy "public read sessions v2" on public.screening_sessions for select to anon,authenticated using(is_open=true or public.is_admin());

grant select on public.movies,public.screening_sessions,public.public_screening_availability to anon,authenticated;
grant select on public.admin_booking_overview to authenticated;
grant execute on function public.get_student_classes() to anon,authenticated;
grant execute on function public.get_students_by_class(text) to anon,authenticated;
grant execute on function public.create_student_booking(uuid,uuid,text,text) to anon,authenticated;
grant execute on function public.is_admin() to anon,authenticated;
grant execute on function public.mark_student_booking_paid(uuid) to authenticated;
grant execute on function public.admin_set_screening(uuid,uuid,text,integer) to authenticated;

-- Import roster CSV in Supabase Table Editor:
-- public.students columns: student_name, class_name, is_active.
