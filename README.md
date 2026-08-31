# Cutting Edge — Salon Management & Booking System

Integrated prototype developed for ITC327W (Work Integrated Learning), Central University of Technology, Free State — Faculty of Engineering, Built Environment and Information Technology.

A Flutter mobile application and an ASP.NET web application, connected to a shared Supabase backend, built for Cutting Edge to manage salon bookings, services, and scheduling.

## Team — Framework Fanatics

| Name | Student Number | Role |
|---|---|---|
| Goitse Kgwele    | 221050663 | [role] |
| Thabang Zitha    | 223007074 | [role] |
| Yamkela Mazamani | 224007421 | [role] |
| Nyakallo Pali    | 223060226 | [role] |
| Bennet Linda     | 224004294 | [role] |

## Repository Structure

```
Group-B-/
├── mobile/     Flutter mobile application
├── web/        ASP.NET web application
├── docs/       SRS, feasibility study, risk register, MS Project schedule
└── README.md
```

## Tech Stack

- **Mobile:** Flutter
- **Web:** ASP.NET Core
- **Backend/Database:** Supabase (PostgreSQL)
- **Project management:** Microsoft Project
- **Version control:** GitHub

## Getting Started

### Mobile (Flutter)
```bash
cd mobile
flutter pub get
flutter run
```

### Web (ASP.NET)
```bash
cd web
dotnet restore
dotnet run
```

### Environment variables
Both apps require a Supabase URL and anon key. Copy `.env.example` to `.env` in each folder and fill in your own values — **never commit real keys or the Supabase service-role key.**

## Documentation

Full project documentation is in [`docs/`](./docs), including:
- Software Requirements Specification (SRS)
- Feasibility study and risk register
- Microsoft Project schedule

## Project Status

Prototype in development as part of ITC327W, 2026. This is an educational prototype — not intended for production use. Known limitations and incomplete functions are documented in `docs/`.
