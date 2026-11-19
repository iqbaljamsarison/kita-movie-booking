# K.I.T.A Movie Booking — SK Seri Mendapat

A responsive booking-site starter for Karnival K.I.T.A Generasi Madani. Frontend hosting: GitHub Pages. Database and authentication: Supabase.

## Included in this starter

- Public landing page with the supplied event poster.
- Five movie choices and the six screening slots from the event poster, including the corrected Monday/Tuesday Session 2 start time of 12:30 PM.
- Hall selection: Hall A (40 seats) or Hall B (35 seats).
- Numbered seat selection and live availability when Supabase is configured.
- Ticket pricing RM1 per seat; Pakej Adik RM3 and Pakej Abang RM5 per seat.
- Cash-at-counter payment status (new bookings are unpaid).
- Booking reference and QR ticket.
- Admin sign-in, booking list, mark-paid and check-in actions.
- Database-side atomic booking function and unique seat constraint to prevent duplicate seat bookings.

## 1. Create Supabase project

1. Create a project at https://supabase.com/.
2. Open **SQL Editor** in the Supabase dashboard.
3. Paste and run `supabase/schema.sql`.
4. In **Project Settings → API**, copy the Project URL and anon/public key.
5. Open `assets/js/app.js` and replace:
   - `PASTE_YOUR_SUPABASE_PROJECT_URL`
   - `PASTE_YOUR_SUPABASE_ANON_KEY`
6. Do not put a `service_role` key in this website. The anon key is designed for browser use; Row Level Security and database functions enforce access.

## 2. Create the first admin

1. In Supabase **Authentication → Users**, add an admin user with an email and a strong password.
2. Copy that user's UUID.
3. In SQL Editor, run the following, replacing the UUID and display name:

```sql
insert into public.admins(user_id, display_name)
values ('PASTE-AUTH-USER-UUID-HERE', 'Admin K.I.T.A');
```

Only user IDs in `public.admins` can view the admin booking list, mark payments, and check in bookings. Do not share the admin password.

## 3. Publish using GitHub Pages

1. Create a GitHub repository named `kita-movie-booking`.
2. Upload the contents of this folder to the repository root (make sure `index.html` is at the root).
3. In **Settings → Pages**, select **Deploy from a branch**, choose `main` and `/ (root)`, then Save.
4. Wait for GitHub Pages to publish. The expected address format is `https://YOUR-GITHUB-USERNAME.github.io/kita-movie-booking/`.
5. Open the site on a phone and computer and submit a test booking before sharing it with users.

## 4. Event configuration

The starter has these six sessions preloaded by the SQL script:

| Date | Session | Time |
|---|---|---|
| 20 Nov 2026 | 1 | 8:00–10:00 AM |
| 20 Nov 2026 | 2 | 10:30 AM–12:00 PM |
| 23 Nov 2026 | 1 | 10:30 AM–12:30 PM |
| 23 Nov 2026 | 2 | 12:30–1:30 PM |
| 24 Nov 2026 | 1 | 10:30 AM–12:30 PM |
| 24 Nov 2026 | 2 | 12:30–1:30 PM |

Each session can be booked in either hall. Seat numbers are A01–A40 and B01–B35. The booking form currently makes one booking with one food-package choice applied per ticket in that booking. For a group requiring mixed food packages, make separate bookings by package type.

All five movies are initially selectable for all six sessions. Confirm this arrangement with the event committee; the current poster does not specify which movie is assigned to each session.

## 5. Important operational notes

- A booking is recorded immediately and its selected seats are reserved. Payment remains **unpaid** until an admin marks it paid.
- Cancelled bookings are not exposed in the public availability view. A cancellation workflow is not included in this starter; do not manually delete rows while a user is booking.
- The QR code identifies the booking. Admin check-in is currently performed from the dashboard booking list; QR-camera scanning is a planned enhancement, not included in this initial build.
- Test the booking flow with dummy data first. Confirm the hall layout, session schedule, movie-to-session allocation, and payment workflow before opening bookings to students.
- Do not store sensitive student information that is not needed for the event. Restrict admin access to authorised teachers.

## Project structure

```text
kita-movie-booking/
├── index.html
├── README.md
├── assets/
│   ├── css/style.css
│   ├── js/app.js
│   └── images/poster-karnival-kita.jpeg
└── supabase/schema.sql
```

## Current scope

This is a deployable starter, not a connected live booking service yet. It becomes live only after a Supabase project is created, the SQL is run, the browser configuration is added, an admin is created, and GitHub Pages is published. The initial build provides booking, seat locking, QR ticket generation, admin payment marking and manual check-in. Payment gateway, camera-based QR scanning, downloadable reports, cancellation/refund workflow and admin movie/session editing are not included yet.
