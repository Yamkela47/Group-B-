# Connecting the Manager Portal to Supabase

The portal now reads and writes your real Supabase project instead of in-memory sample data.

## 1. Run the SQL (once)
Supabase Dashboard → **SQL Editor** → paste `Database/supabase_setup.sql` → **Run**.
It adds the few columns/tables the portal needs, your two booking rules, and the `gallery` storage bucket.
Then follow section 7 in that file to create the first **manager** login.

## 2. Put your keys in user-secrets (not in git)
Dashboard → **Project Settings → API** has the three values. From the project folder:

```
dotnet user-secrets init
dotnet user-secrets set "Supabase:Url" "https://YOUR-PROJECT.supabase.co"
dotnet user-secrets set "Supabase:AnonKey" "YOUR-ANON-PUBLIC-KEY"
dotnet user-secrets set "Supabase:ServiceRoleKey" "YOUR-SERVICE-ROLE-KEY"
```

The **service-role key is a secret**: it bypasses Row Level Security, so it must only live on the server
(user-secrets / environment variable) — never in `appsettings.json`, GitHub, or the browser.
(On a host, set the same names as environment variables: `Supabase__Url`, `Supabase__AnonKey`, `Supabase__ServiceRoleKey`.)

## 3. Allow the password-reset link
Dashboard → **Authentication → URL Configuration** → add your portal address to **Redirect URLs**, e.g.
`https://localhost:7054/Account/ResetPassword` (and your live address later).
If the portal is behind a different public address, also set `Supabase:SiteUrl`.

## 4. Run
`dotnet run` → sign in with the manager account from step 1.

## How the app maps to your tables
| Portal screen | Tables |
|---|---|
| Login / profile | Supabase Auth + `profiles` → `roles` (only role **Manager** may sign in) |
| Bookings | `bookings` (+ `customers`, `stylists`, `services`, `payment_methods`) |
| Cancel a booking | `bookings.status='cancelled'` + `cancellations` row; trigger frees `stylist_schedules` |
| Stylists | `profiles` + `stylists` (+ Auth user, + `stylist_services`) |
| Schedules | `stylist_schedules` (weekly pattern written as one row per date, next 8 weeks) |
| Services / Promotions | `services`, `promotions` |
| Reviews | `reviews` (new) |
| Gallery / About Us | `gallery_images` + Storage bucket `gallery`; `site_settings` (new) |
| Reports / Dashboard | computed from completed `bookings` × `services.price` by `payment_methods` |

Status mapping: `pending`/`confirmed` show as **Incomplete**, `completed` as **Completed**, `cancelled` as **Cancelled**.

## E-mail (apology / stylist report buttons)
Uses SMTP from the `Email:*` settings. Add `Email:SmtpUser` / `Email:SmtpPass` (a Gmail *app password*) as user-secrets.
Note: the sample `SmtpUser`/`FromEmail` in `appsettings.json` (`cuttinged@88@gmail.com`) is not a valid address — replace it.
