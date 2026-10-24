# Cutting Edge — Salon Management & Booking System

Integrated prototype developed for ITC327W (Work Integrated Learning), Central University of Technology, Free State — Faculty of Engineering, Built Environment and Information Technology.

A Flutter mobile application and an ASP.NET web application, connected to a shared Supabase backend, built for Cutting Edge to manage salon bookings, services, and scheduling.

## Team — Framework Fanatics

| Name | Student Number | Role |
|---|---|---|
| Goitse Kgwele    | 221050663 | Facilitator |
| Thabang Zitha    | 223007074 | Requirement Analyst |
| Yamkela Mazamani | 224007421 | Documentation Lead |
| Nyakallo Pali    | 223060226 | Backend Lead |
| Bennet Linda     | 224004294 | Frontend Lead |

## Repository Structure

```
Group-B-/
├── doc/        Documentation
├── mobile/     Flutter mobile application
├── web/        ASP.NET web application
└── README.md
```

## Tech Stack

- **Mobile:** Flutter
- **Web:** ASP.NET Core
- **Backend/Database:** Supabase (PostgreSQL)
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

## Project Status

Phase 2 completed. Phase 3 development, integration and testing are currently in progress for ITC327W, 2026.
