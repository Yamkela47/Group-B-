using System.Text;
using CuttingEdge.ManagerPortal.Models;
using CuttingEdge.ManagerPortal.ViewModels;

namespace CuttingEdge.ManagerPortal.Services;

// ---------------------------------------------------------------------------
//  SAMPLE-DATA VERSION
//  Every method keeps the signature the controllers already use, but reads and
//  writes an in-memory list instead of Supabase. To go live, replace the body
//  of each method with the real Supabase call (the method names stay the same
//  so no controller has to change).
// ---------------------------------------------------------------------------

public class AuthUser { public string? Email { get; set; } }

public class AuthSession
{
    public string? AccessToken { get; set; }
    public AuthUser? User { get; set; }
}

public class SupabaseService
{
    private static readonly string[] Days =
        { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" };

    private static readonly object _lock = new();

    private static readonly List<Profile> _profiles = new();
    private static readonly List<Stylist> _stylists = new();
    private static readonly List<Service> _services = new();
    private static readonly List<PaymentMethod> _payments = new();
    private static readonly List<Booking> _bookings = new();
    private static readonly List<Cancellation> _cancellations = new();
    private static readonly List<Promotion> _promotions = new();
    private static readonly List<Review> _reviews = new();
    private static readonly List<GalleryImage> _gallery = new();
    private static readonly Dictionary<Guid, Dictionary<string, DaySchedule>> _schedules = new();
    private static readonly Dictionary<Guid, List<Guid>> _stylistServices = new();
    private static string _aboutUs =
        "Cutting Edge is a premium salon based in Bloemfontein, offering expert haircuts, colouring, and grooming services since 2015. Our vision, your style.";

    // Stable GUIDs so links keep working after a restart.
    private static Guid G(int n) => new(n, 0, 0, new byte[8]);

    private static bool _seeded;
    private static readonly List<Notification> _notifications = new();

    public SupabaseService()
    {
        // Sample data is shared (static) so changes survive between requests,
        // even though ASP.NET creates a new service object per request.
        lock (_lock)
        {
            if (_seeded) return;
            Seed();
            _seeded = true;
        }
    }

    /// <summary>The portal only knows two booking statuses: Completed and Incomplete.</summary>
    private static string NormalizeStatus(string? status) =>
        string.Equals(status, "Completed", StringComparison.OrdinalIgnoreCase) ? "Completed" : "Incomplete";

    // =====================================================================
    //  SEED DATA
    // =====================================================================
    private void Seed()
    {
        var today = DateTime.Today;

        // Payment methods
        _payments.Add(new PaymentMethod { PaymentMethodId = G(1), MethodName = "Cash" });
        _payments.Add(new PaymentMethod { PaymentMethodId = G(2), MethodName = "Card" });

        // Manager + staff profiles
        _profiles.Add(new Profile { Id = G(100), FullName = "Thabo Mokwena", Email = "thabo@cuttingedge.co.za", Phone = "082 456 7890", Role = "Manager", CreatedAt = today.AddYears(-1) });

        var staff = new (int n, string name, string phone, bool active)[]
        {
            (101, "Ntsako",   "082 345 6789", true),
            (102, "Mes",      "072 111 2233", true),
            (103, "Nqobile",  "071 222 3344", true),
            (104, "Dimpho K", "073 333 4455", true),
            (105, "Lerato",   "074 444 5566", true),
            (106, "Carlos",   "075 555 6677", false),
        };
        foreach (var s in staff)
        {
            var p = new Profile
            {
                Id = G(s.n),
                FullName = s.name,
                Email = s.name.ToLower().Replace(" ", "").Replace(".", "") + "@cuttingedge.co.za",
                Phone = s.phone,
                Role = "Stylist",
                CreatedAt = today.AddMonths(-8)
            };
            _profiles.Add(p);
            _stylists.Add(new Stylist
            {
                StylistId = G(s.n + 100),
                ProfileId = p.Id,
                Active = s.active,
                CreatedAt = p.CreatedAt,
                Profile = p
            });
        }

        // Customers
        var customers = new[]
        {
            "Goitseone","Thabang","Nyakallo","Bennet","Yamkela","Katlego","Palesa",
            "Lindiwe","Kagiso","Refilwe","Tumelo","Boitumelo","Naledi","Mpho","Sipho","Karabo"
        };
        for (int i = 0; i < customers.Length; i++)
            _profiles.Add(new Profile
            {
                Id = G(300 + i),
                FullName = customers[i],
                Email = customers[i].ToLower() + "@example.com",
                Phone = $"076 123 {4567 + i}",
                Role = "Customer",
                CreatedAt = today.AddMonths(-4)
            });

        // Services
        void AddService(int n, string name, string desc, decimal price, int mins, bool flagship = false) =>
            _services.Add(new Service
            {
                ServiceId = G(n), Name = name, Description = desc, Price = price,
                DurationMinutes = mins, IsFlagship = flagship, Active = true, CreatedAt = today.AddMonths(-10)
            });

        AddService(200, "Standard Haircut", "Classic precision haircut with a clean finish.", 140, 30);
        AddService(201, "Cut & Dye", "Premium cut and colour service including consultation, professional colour application, precision cut and blow-dry.", 220, 80, true);
        AddService(202, "Beard Shave", "Hot lather shave with a sharp, comfortable line.", 90, 30);
        AddService(203, "Hot Towel Treatment", "Relaxing hot towel treatment to refresh skin and soften the beard.", 70, 20);
        AddService(204, "Air Dye", "Even, long-lasting colour applied with an air-brush technique.", 180, 60);
        AddService(205, "Bleach", "Professional bleach service for a bold, clean base.", 100, 45);
        AddService(206, "Express Facial", "Quick cleanse, exfoliate and hydrate.", 150, 30);
        AddService(207, "Chieskop Blade", "Close blade finish for a smooth, sharp look.", 65, 20);

        foreach (var st in _stylists)
            _stylistServices[st.StylistId] = _services.Select(s => s.ServiceId).ToList();

        // Weekly schedules (matches the designs)
        DaySchedule D(bool on, string s = "09:00", string e = "17:00") =>
            new() { Enabled = on, StartTime = on ? s : null, EndTime = on ? e : null };

        _schedules[G(201)] = new() { ["Monday"] = D(true), ["Tuesday"] = D(true), ["Wednesday"] = D(false), ["Thursday"] = D(true), ["Friday"] = D(true), ["Saturday"] = D(true, "09:00", "15:00"), ["Sunday"] = D(true) };
        _schedules[G(202)] = new() { ["Monday"] = D(true, "10:00", "18:00"), ["Tuesday"] = D(true, "10:00", "18:00"), ["Wednesday"] = D(true, "10:00", "18:00"), ["Thursday"] = D(false), ["Friday"] = D(true, "10:00", "18:00"), ["Saturday"] = D(true, "09:00", "15:00"), ["Sunday"] = D(false) };
        _schedules[G(203)] = new() { ["Monday"] = D(false), ["Tuesday"] = D(true), ["Wednesday"] = D(true), ["Thursday"] = D(true), ["Friday"] = D(true), ["Saturday"] = D(false), ["Sunday"] = D(true) };
        _schedules[G(204)] = new() { ["Monday"] = D(true), ["Tuesday"] = D(false), ["Wednesday"] = D(true), ["Thursday"] = D(true), ["Friday"] = D(false), ["Saturday"] = D(true, "09:00", "15:00"), ["Sunday"] = D(true) };
        _schedules[G(205)] = new() { ["Monday"] = D(true, "10:00", "18:00"), ["Tuesday"] = D(true, "10:00", "18:00"), ["Wednesday"] = D(false), ["Thursday"] = D(true, "10:00", "18:00"), ["Friday"] = D(true, "10:00", "18:00"), ["Saturday"] = D(false), ["Sunday"] = D(false) };

        // Bookings: 4 today (+1 cancelled), a few earlier this week
        Guid cust(string name) => _profiles.First(p => p.FullName == name).Id;
        void AddBooking(int n, string customer, int serviceN, int stylistN, DateTime date, string start, int payment, string status, string? notes = null)
        {
            var svc = _services.First(s => s.ServiceId == G(serviceN));
            var st = TimeSpan.Parse(start);
            _bookings.Add(new Booking
            {
                BookingId = G(400 + n),
                CustomerId = cust(customer),
                StylistId = G(stylistN),
                ServiceId = svc.ServiceId,
                PaymentMethodId = G(payment),
                AppointmentDate = date,
                StartTime = st,
                EndTime = st.Add(TimeSpan.FromMinutes(svc.DurationMinutes)),
                Status = status,
                AdditionalNotes = notes,
                CreatedAt = date.AddDays(-2)
            });
        }

        AddBooking(1, "Goitseone", 207, 201, today, "10:00", 2, "Incomplete");
        AddBooking(2, "Thabang", 201, 202, today, "12:00", 1, "Incomplete", "Please use a light brown colour.");
        AddBooking(3, "Nyakallo", 205, 203, today, "12:00", 1, "Incomplete");
        AddBooking(4, "Bennet", 207, 203, today, "15:00", 2, "Incomplete");

        AddBooking(6, "Katlego", 201, 202, today.AddDays(-3), "10:30", 2, "Completed");
        AddBooking(7, "Palesa", 201, 202, today.AddDays(-1), "13:00", 2, "Completed");
        AddBooking(8, "Kagiso", 200, 202, today.AddDays(1), "11:00", 1, "Incomplete");
        AddBooking(9, "Lindiwe", 200, 201, today.AddDays(-4), "11:00", 2, "Completed");
        AddBooking(10, "Tumelo", 200, 203, today.AddDays(-5), "15:45", 1, "Completed");

        // Cancellations come from customers in the mobile app (not a booking status here).
        _cancellations.Add(new Cancellation
        {
            CancellationId = G(800), BookingId = G(499), Reason = "Customer cancelled in the app", CancelledAt = DateTime.Now
        });

        // Reviews
        void AddReview(int n, string customer, int stylistN, int bookingN, int rating, string comment, DateTime when)
        {
            var b = _bookings.FirstOrDefault(x => x.BookingId == G(400 + bookingN));
            _reviews.Add(new Review
            {
                ReviewId = G(500 + n),
                BookingId = b?.BookingId ?? G(401),
                CustomerId = cust(customer),
                StylistId = G(stylistN),
                Rating = rating,
                Comment = comment,
                FollowUpRequired = rating <= 2,
                Resolved = false,
                CreatedAt = when
            });
        }

        var now = DateTime.Now;
        AddReview(1, "Goitseone", 201, 1, 5, "Amazing haircut, very professional!", now.Date.AddHours(10).AddMinutes(15));
        AddReview(2, "Thabang", 202, 2, 4, "Loved the color, will definitely come back.", now.Date.AddHours(12).AddMinutes(40));
        AddReview(3, "Nyakallo", 203, 3, 2, "Took longer than expected, felt rushed at the end.", now.Date.AddHours(12));
        AddReview(4, "Bennet", 203, 4, 5, "Great service as always, highly recommend.", now.Date.AddDays(-1).AddHours(15).AddMinutes(30));
        AddReview(5, "Yamkela", 204, 5, 3, "Facial was okay, room felt a bit rushed.", now.Date.AddDays(-1).AddHours(16));
        AddReview(6, "Sipho", 201, 9, 4, "Good cut, quick and friendly service.", now.Date.AddDays(-2).AddHours(9).AddMinutes(20));
        AddReview(7, "Palesa", 202, 7, 1, "Color came out much darker than I asked for.", now.Date.AddDays(-2).AddHours(14));
        AddReview(8, "Karabo", 203, 10, 5, "Best fade I've had in years, highly recommend.", now.Date.AddDays(-3).AddHours(14).AddMinutes(5));
        AddReview(9, "Lindiwe", 201, 9, 5, "Perfect as always, my go-to stylist!", now.Date.AddDays(-4).AddHours(11));
        AddReview(10, "Kagiso", 202, 6, 4, "Nice cut but had to wait a while.", now.Date.AddDays(-4).AddHours(13).AddMinutes(30));
        AddReview(11, "Refilwe", 204, 5, 2, "Facial products caused a mild reaction.", now.Date.AddDays(-5).AddHours(12));
        AddReview(12, "Mpho", 204, 5, 4, "Relaxing facial, will come back.", now.Date.AddDays(-7).AddHours(16));

        // Promotions
        void AddPromo(int n, string title, string desc, int serviceN, string type, decimal value, DateTime from, DateTime to) =>
            _promotions.Add(new Promotion
            {
                PromotionId = G(600 + n), ServiceId = G(serviceN), Title = title, Description = desc,
                DiscountType = type, DiscountValue = value, StartDate = from, EndDate = to,
                Active = true, CreatedAt = today.AddDays(-20)
            });

        AddPromo(1, "Cut & Dye Special", "Enjoy 15% off our signature Cut & Dye service this month — perfect for refreshing your look.", 201, "Percentage", 15, today.AddDays(-10), today.AddDays(20));
        AddPromo(2, "Fresh Prince", "Fresh fade and beard line-up for less.", 200, "Fixed Amount", 20, today.AddDays(-5), today.AddDays(25));
        AddPromo(3, "Birthday Discount", "Celebrate your birthday month with 10% off any service.", 200, "Percentage", 10, today.AddDays(-30), today.AddDays(60));

        // Gallery (no real images yet - the view shows a placeholder tile)
        string[] captions = { "Salon Interior", "Colour Station", "Team Photo", "Styling Station", "Express Facial", "Beard Shave", "Reception Area", "Hot Towel Treatment" };
        for (int i = 0; i < captions.Length; i++)
            _gallery.Add(new GalleryImage
            {
                ImageId = G(700 + i), UploadedBy = G(100), Title = captions[i],
                ImageUrl = "", CreatedAt = today.AddDays(-i * 2)
            });
    }

    // =====================================================================
    //  HELPERS
    // =====================================================================
    private Booking Hydrate(Booking b)
    {
        b.Customer = _profiles.FirstOrDefault(p => p.Id == b.CustomerId);
        b.Stylist = _stylists.FirstOrDefault(s => s.StylistId == b.StylistId);
        b.Service = _services.FirstOrDefault(s => s.ServiceId == b.ServiceId);
        b.PaymentMethod = _payments.FirstOrDefault(p => p.PaymentMethodId == b.PaymentMethodId);
        return b;
    }

    private Review Hydrate(Review r)
    {
        r.Customer = _profiles.FirstOrDefault(p => p.Id == r.CustomerId);
        r.Stylist = _stylists.FirstOrDefault(s => s.StylistId == r.StylistId);
        var b = _bookings.FirstOrDefault(x => x.BookingId == r.BookingId);
        r.Booking = b == null ? null : Hydrate(b);
        return r;
    }

    private Promotion Hydrate(Promotion p)
    {
        p.Service = _services.FirstOrDefault(s => s.ServiceId == p.ServiceId);
        return p;
    }

    private Stylist Hydrate(Stylist s)
    {
        s.Profile = _profiles.FirstOrDefault(p => p.Id == s.ProfileId);
        return s;
    }

    private static Dictionary<string, DaySchedule> DefaultWeek() =>
        Days.ToDictionary(d => d, d => new DaySchedule
        {
            Enabled = d != "Sunday",
            StartTime = "09:00",
            EndTime = d == "Saturday" ? "15:00" : "17:00"
        });

    private static Dictionary<string, DaySchedule> CloneWeek(Dictionary<string, DaySchedule>? src)
    {
        var result = new Dictionary<string, DaySchedule>();
        foreach (var d in Days)
        {
            var s = src != null && src.TryGetValue(d, out var v) ? v : null;
            result[d] = new DaySchedule
            {
                Enabled = s?.Enabled ?? false,
                StartTime = s?.StartTime,
                EndTime = s?.EndTime
            };
        }
        return result;
    }

    // =====================================================================
    //  AUTH  (demo mode: any non-empty email + password signs in)
    // =====================================================================
    public Task<AuthSession?> SignInAsync(string email, string password)
    {
        AuthSession? session = null;
        if (!string.IsNullOrWhiteSpace(email) && !string.IsNullOrWhiteSpace(password))
            session = new AuthSession { AccessToken = "demo-token", User = new AuthUser { Email = email } };
        return Task.FromResult(session);
    }

    public Task SignOutAsync() => Task.CompletedTask;
    public Task SendPasswordResetEmailAsync(string email) => Task.CompletedTask;
    public Task ResetPasswordAsync(string token, string newPassword) => Task.CompletedTask;
    public Task ChangePasswordAsync(string currentPassword, string newPassword) => Task.CompletedTask;

    public Task SendEmailAsync(string to, string subject, string body)
    {
        Console.WriteLine($"[DEMO EMAIL] To: {to} | Subject: {subject}");
        return Task.CompletedTask;
    }

    // =====================================================================
    //  DASHBOARD
    // =====================================================================
    public Task<DashboardMetrics> GetDashboardMetricsAsync()
    {
        lock (_lock)
        {
            var today = _bookings.Where(b => b.AppointmentDate.Date == DateTime.Today).ToList();
            var metrics = new DashboardMetrics
            {
                TodayBookings = today.Count,
                Cancelled = _cancellations.Count(c => c.CancelledAt.Date == DateTime.Today),
                EstimatedRevenue = today.Sum(b => _services.FirstOrDefault(s => s.ServiceId == b.ServiceId)?.Price ?? 0)
            };
            return Task.FromResult(metrics);
        }
    }

    public Task<List<Booking>> GetTodayBookingsAsync()
    {
        lock (_lock)
        {
            var list = _bookings
                .Where(b => b.AppointmentDate.Date == DateTime.Today)
                .OrderBy(b => b.StartTime)
                .Select(Hydrate).ToList();
            return Task.FromResult(list);
        }
    }

    public Task<List<Review>> GetRecentReviewsAsync(int count)
    {
        lock (_lock)
            return Task.FromResult(_reviews.OrderByDescending(r => r.CreatedAt).Take(count).Select(Hydrate).ToList());
    }

    // =====================================================================
    //  BOOKINGS
    // =====================================================================
    public Task<List<Booking>> GetFilteredBookingsAsync(string? status, string? date, string? search)
    {
        lock (_lock)
        {
            var q = _bookings.Select(Hydrate).AsEnumerable();

            if (!string.IsNullOrWhiteSpace(status) && status != "All")
                q = q.Where(b => b.Status.Equals(status, StringComparison.OrdinalIgnoreCase));

            if (DateTime.TryParse(date, out var d))
                q = q.Where(b => b.AppointmentDate.Date == d.Date);

            if (!string.IsNullOrWhiteSpace(search))
                q = q.Where(b =>
                    (b.Customer?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                    (b.Service?.Name ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                    (b.Stylist?.Profile?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase));

            return Task.FromResult(q.OrderByDescending(b => b.AppointmentDate).ThenBy(b => b.StartTime).ToList());
        }
    }

    public Task<Booking?> GetBookingByIdAsync(Guid id)
    {
        lock (_lock)
        {
            var b = _bookings.FirstOrDefault(x => x.BookingId == id);
            return Task.FromResult(b == null ? null : Hydrate(b));
        }
    }

    public Task UpdateBookingStatusAsync(Guid id, string status)
    {
        lock (_lock)
        {
            var b = _bookings.FirstOrDefault(x => x.BookingId == id);
            if (b != null) b.Status = NormalizeStatus(status);
        }
        return Task.CompletedTask;
    }

    public Task CreateNotificationAsync(Guid profileId, string title, string message, string? type = null)
    {
        lock (_lock)
            _notifications.Add(new Notification
            {
                NotificationId = Guid.NewGuid(), ProfileId = profileId, Title = title,
                Message = message, NotificationType = type, IsRead = false, CreatedAt = DateTime.Now
            });
        return Task.CompletedTask;
    }

    public Task CreateCancellationRecordAsync(Guid bookingId, string reason)
    {
        lock (_lock)
            _cancellations.Add(new Cancellation
            {
                CancellationId = Guid.NewGuid(), BookingId = bookingId, Reason = reason, CancelledAt = DateTime.Now
            });
        return Task.CompletedTask;
    }

    public Task UpdateBookingAsync(Booking booking)
    {
        lock (_lock)
        {
            var b = _bookings.FirstOrDefault(x => x.BookingId == booking.BookingId);
            if (b != null)
            {
                b.AppointmentDate = booking.AppointmentDate;
                b.StartTime = booking.StartTime;
                b.EndTime = booking.EndTime;
                b.Status = NormalizeStatus(booking.Status);
                b.AdditionalNotes = booking.AdditionalNotes;
            }
        }
        return Task.CompletedTask;
    }

    public Task DeleteBookingAsync(Guid id, string reason)
    {
        lock (_lock)
        {
            _bookings.RemoveAll(b => b.BookingId == id);
            _cancellations.Add(new Cancellation
            {
                CancellationId = Guid.NewGuid(), BookingId = id, Reason = reason, CancelledAt = DateTime.Now
            });
        }
        return Task.CompletedTask;
    }

    // =====================================================================
    //  STYLISTS
    // =====================================================================
    public Task<List<Stylist>> GetAllStylistsWithProfilesAsync()
    {
        lock (_lock)
            return Task.FromResult(_stylists.Select(Hydrate).OrderByDescending(s => s.Active).ThenBy(s => s.Profile?.FullName).ToList());
    }

    public Task<Stylist?> GetStylistByIdAsync(Guid id)
    {
        lock (_lock)
        {
            var s = _stylists.FirstOrDefault(x => x.StylistId == id);
            return Task.FromResult(s == null ? null : Hydrate(s));
        }
    }

    public Task<StylistViewModel?> GetStylistViewModelAsync(Guid id)
    {
        lock (_lock)
        {
            var s = _stylists.FirstOrDefault(x => x.StylistId == id);
            if (s == null) return Task.FromResult<StylistViewModel?>(null);
            Hydrate(s);
            return Task.FromResult<StylistViewModel?>(new StylistViewModel
            {
                StylistId = s.StylistId,
                ProfileId = s.ProfileId,
                FullName = s.Profile?.FullName ?? "",
                Email = s.Profile?.Email ?? "",
                Phone = s.Profile?.Phone,
                Role = s.Profile?.Role ?? "Stylist",
                Active = s.Active,
                PhotoUrl = s.PhotoUrl,
                WorkingHours = "Mon–Sat, 09:00 – 17:00",
                ServiceIds = _stylistServices.TryGetValue(s.StylistId, out var ids) ? ids.ToList() : new List<Guid>()
            });
        }
    }

    public Task CreateStylistAsync(StylistViewModel model)
    {
        lock (_lock)
        {
            var profile = new Profile
            {
                Id = Guid.NewGuid(), FullName = model.FullName, Email = model.Email, Phone = model.Phone,
                Role = model.Role ?? "Stylist", CreatedAt = DateTime.Now
            };
            var stylist = new Stylist
            {
                StylistId = Guid.NewGuid(), ProfileId = profile.Id, Active = model.Active, CreatedAt = DateTime.Now
            };
            _profiles.Add(profile);
            _stylists.Add(stylist);
            _stylistServices[stylist.StylistId] = model.ServiceIds.ToList();
            _schedules[stylist.StylistId] = DefaultWeek();
        }
        return Task.CompletedTask;
    }

    public Task UpdateStylistAsync(StylistViewModel model)
    {
        lock (_lock)
        {
            var s = _stylists.FirstOrDefault(x => x.StylistId == model.StylistId);
            if (s == null) return Task.CompletedTask;
            var p = _profiles.FirstOrDefault(x => x.Id == s.ProfileId);
            if (p != null)
            {
                p.FullName = model.FullName;
                p.Email = model.Email;
                p.Phone = model.Phone;
                p.Role = model.Role ?? p.Role;
            }
            s.Active = model.Active;
            _stylistServices[s.StylistId] = model.ServiceIds.ToList();
        }
        return Task.CompletedTask;
    }

    public Task DeactivateStylistAsync(Guid id)
    {
        lock (_lock)
        {
            var s = _stylists.FirstOrDefault(x => x.StylistId == id);
            if (s != null) s.Active = false;
        }
        return Task.CompletedTask;
    }

    public Task DeleteStylistAsync(Guid id)
    {
        lock (_lock)
        {
            var s = _stylists.FirstOrDefault(x => x.StylistId == id);
            if (s == null) return Task.CompletedTask;
            _stylists.Remove(s);
            _profiles.RemoveAll(p => p.Id == s.ProfileId);
            _schedules.Remove(id);
            _stylistServices.Remove(id);
        }
        return Task.CompletedTask;
    }

    // =====================================================================
    //  SCHEDULES
    // =====================================================================
    public Task<List<StylistScheduleViewModel>> GetWeeklySchedulesAsync()
    {
        lock (_lock)
        {
            var list = _stylists.Where(s => s.Active).Select(Hydrate).Select(s => new StylistScheduleViewModel
            {
                StylistId = s.StylistId,
                StylistName = s.Profile?.FullName ?? "",
                WeekSchedule = CloneWeek(_schedules.TryGetValue(s.StylistId, out var w) ? w : null)
            }).ToList();
            return Task.FromResult(list);
        }
    }

    public Task<ScheduleViewModel?> GetStylistScheduleAsync(Guid stylistId)
    {
        lock (_lock)
        {
            var s = _stylists.FirstOrDefault(x => x.StylistId == stylistId);
            if (s == null) return Task.FromResult<ScheduleViewModel?>(null);
            Hydrate(s);
            return Task.FromResult<ScheduleViewModel?>(new ScheduleViewModel
            {
                StylistId = stylistId,
                StylistName = s.Profile?.FullName,
                WeekSchedule = CloneWeek(_schedules.TryGetValue(stylistId, out var w) ? w : null)
            });
        }
    }

    public Task<List<Booking>> GetWeeklyBookingsByStylistAsync(Guid stylistId)
    {
        lock (_lock)
        {
            var monday = DateTime.Today.AddDays(-(((int)DateTime.Today.DayOfWeek + 6) % 7));
            var list = _bookings
                .Where(b => b.StylistId == stylistId
                         && b.Status == "Incomplete"   // completed appointments drop off the schedule
                         && b.AppointmentDate.Date >= monday && b.AppointmentDate.Date < monday.AddDays(7))
                .OrderBy(b => b.AppointmentDate).ThenBy(b => b.StartTime)
                .Select(Hydrate).ToList();
            return Task.FromResult(list);
        }
    }

    public Task SaveScheduleAsync(ScheduleViewModel model)
    {
        lock (_lock) _schedules[model.StylistId] = CloneWeek(model.WeekSchedule);
        return Task.CompletedTask;
    }

    public Task UpdateScheduleAsync(Guid stylistId, ScheduleViewModel model)
    {
        lock (_lock) _schedules[stylistId] = CloneWeek(model.WeekSchedule);
        return Task.CompletedTask;
    }

    public Task DeleteScheduleAsync(Guid stylistId)
    {
        lock (_lock) _schedules.Remove(stylistId);
        return Task.CompletedTask;
    }

    // =====================================================================
    //  SERVICES
    // =====================================================================
    public Task<List<Service>> GetAllServicesAsync()
    {
        lock (_lock) return Task.FromResult(_services.OrderBy(s => s.Name).ToList());
    }

    public Task<Service?> GetServiceByIdAsync(Guid id)
    {
        lock (_lock) return Task.FromResult(_services.FirstOrDefault(s => s.ServiceId == id));
    }

    public Task CreateServiceAsync(Service service)
    {
        lock (_lock)
        {
            service.ServiceId = Guid.NewGuid();
            service.CreatedAt = DateTime.Now;
            _services.Add(service);
        }
        return Task.CompletedTask;
    }

    public Task UpdateServiceAsync(Service service)
    {
        lock (_lock)
        {
            var s = _services.FirstOrDefault(x => x.ServiceId == service.ServiceId);
            if (s != null)
            {
                s.Name = service.Name;
                s.Description = service.Description;
                s.Price = service.Price;
                s.DurationMinutes = service.DurationMinutes;
                s.IsFlagship = service.IsFlagship;
                s.Active = service.Active;
            }
        }
        return Task.CompletedTask;
    }

    public Task DeleteServiceAsync(Guid id)
    {
        lock (_lock) _services.RemoveAll(s => s.ServiceId == id);
        return Task.CompletedTask;
    }

    // =====================================================================
    //  PROMOTIONS
    // =====================================================================
    public Task<List<Promotion>> GetAllPromotionsAsync()
    {
        lock (_lock) return Task.FromResult(_promotions.Select(Hydrate).OrderByDescending(p => p.StartDate).ToList());
    }

    public Task<List<Promotion>> GetActivePromotionsAsync()
    {
        lock (_lock) return Task.FromResult(_promotions.Where(p => p.Active).Select(Hydrate).OrderByDescending(p => p.StartDate).ToList());
    }

    public Task<Promotion?> GetPromotionByIdAsync(Guid id)
    {
        lock (_lock)
        {
            var p = _promotions.FirstOrDefault(x => x.PromotionId == id);
            return Task.FromResult(p == null ? null : Hydrate(p));
        }
    }

    public Task CreatePromotionAsync(Promotion promotion)
    {
        lock (_lock)
        {
            promotion.PromotionId = Guid.NewGuid();
            promotion.CreatedAt = DateTime.Now;
            _promotions.Add(promotion);
        }
        return Task.CompletedTask;
    }

    public Task UpdatePromotionAsync(Promotion promotion)
    {
        lock (_lock)
        {
            var p = _promotions.FirstOrDefault(x => x.PromotionId == promotion.PromotionId);
            if (p != null)
            {
                p.Title = promotion.Title;
                p.Description = promotion.Description;
                p.ServiceId = promotion.ServiceId;
                p.DiscountType = promotion.DiscountType;
                p.DiscountValue = promotion.DiscountValue;
                p.StartDate = promotion.StartDate;
                p.EndDate = promotion.EndDate;
                p.Active = promotion.Active;
                p.ImageUrl = promotion.ImageUrl;
            }
        }
        return Task.CompletedTask;
    }

    public Task DeletePromotionAsync(Guid id)
    {
        lock (_lock) _promotions.RemoveAll(p => p.PromotionId == id);
        return Task.CompletedTask;
    }

    // =====================================================================
    //  REVIEWS
    // =====================================================================
    public Task<List<Review>> GetFilteredReviewsAsync(string? rating, Guid? stylistId, DateTime? date, string? search)
    {
        lock (_lock)
        {
            var q = _reviews.Select(Hydrate).AsEnumerable();

            if (int.TryParse(rating, out var r)) q = q.Where(x => x.Rating == r);
            if (stylistId.HasValue && stylistId != Guid.Empty) q = q.Where(x => x.StylistId == stylistId);
            if (date.HasValue) q = q.Where(x => x.CreatedAt.Date == date.Value.Date);
            if (!string.IsNullOrWhiteSpace(search))
                q = q.Where(x =>
                    (x.Customer?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                    (x.Stylist?.Profile?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase));

            return Task.FromResult(q.OrderByDescending(x => x.CreatedAt).ToList());
        }
    }

    public Task<ReviewSummary> GetReviewSummaryAsync()
    {
        lock (_lock)
        {
            return Task.FromResult(new ReviewSummary
            {
                AverageRating = _reviews.Count == 0 ? 0 : Math.Round(_reviews.Average(x => x.Rating), 1),
                TotalReviews = _reviews.Count,
                NeedsFollowUp = _reviews.Count(x => x.FollowUpRequired && !x.Resolved)
            });
        }
    }

    public Task<Review?> GetReviewByIdAsync(Guid id)
    {
        lock (_lock)
        {
            var r = _reviews.FirstOrDefault(x => x.ReviewId == id);
            return Task.FromResult(r == null ? null : Hydrate(r));
        }
    }

    public Task MarkReviewResolvedAsync(Guid id)
    {
        lock (_lock)
        {
            var r = _reviews.FirstOrDefault(x => x.ReviewId == id);
            if (r != null) r.Resolved = true;
        }
        return Task.CompletedTask;
    }

    // =====================================================================
    //  REPORTS
    // =====================================================================
    public Task<ReportData> GetReportAsync(string period, DateTime? from, DateTime? to)
    {
        var data = period switch
        {
            "weekly" => new ReportData
            {
                Period = "weekly", CompletedBookings = 128, Cancelled = 9,
                CashRevenue = 12450m, CardRevenue = 7630m,
                PeriodLabel = $"{DateTime.Today.AddDays(-6):dd MMM} - {DateTime.Today:dd MMM yyyy}"
            },
            "custom" => new ReportData
            {
                Period = "custom", CompletedBookings = 734, Cancelled = 51,
                CashRevenue = 71200m, CardRevenue = 43900m,
                PeriodLabel = from.HasValue && to.HasValue ? $"{from:dd MMM yyyy} - {to:dd MMM yyyy}" : "Custom range"
            },
            _ => new ReportData
            {
                Period = "monthly", CompletedBookings = 512, Cancelled = 34,
                CashRevenue = 49800m, CardRevenue = 31200m,
                PeriodLabel = DateTime.Today.ToString("MMMM yyyy")
            }
        };
        return Task.FromResult(data);
    }

    /// <summary>Builds a small, valid one-page PDF without any extra packages.</summary>
    public Task<byte[]> GenerateReportPdfAsync(ReportData report)
    {
        var lines = new[]
        {
            "CUTTING EDGE - Revenue & Booking Report",
            $"Period: {report.PeriodLabel}",
            "",
            $"Completed bookings: {report.CompletedBookings}",
            $"Cancelled bookings: {report.Cancelled}",
            $"Cash revenue: R{report.CashRevenue:N2} ({report.CashPercent}%)",
            $"Card revenue: R{report.CardRevenue:N2} ({report.CardPercent}%)",
            $"Total revenue: R{report.TotalRevenue:N2}"
        };

        static string Esc(string s) => s.Replace("\\", "\\\\").Replace("(", "\\(").Replace(")", "\\)");

        var content = new StringBuilder("BT /F1 14 Tf 50 780 Td 20 TL\n");
        foreach (var l in lines) content.Append('(').Append(Esc(l)).Append(") Tj T*\n");
        content.Append("ET");

        var objs = new List<string>
        {
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
            $"<< /Length {content.Length} >>\nstream\n{content}\nendstream",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
        };

        var sb = new StringBuilder("%PDF-1.4\n");
        var offsets = new List<int>();
        for (int i = 0; i < objs.Count; i++)
        {
            offsets.Add(sb.Length);
            sb.Append($"{i + 1} 0 obj\n{objs[i]}\nendobj\n");
        }
        int xref = sb.Length;
        sb.Append($"xref\n0 {objs.Count + 1}\n0000000000 65535 f \n");
        foreach (var o in offsets) sb.Append($"{o:D10} 00000 n \n");
        sb.Append($"trailer\n<< /Size {objs.Count + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF");

        return Task.FromResult(Encoding.ASCII.GetBytes(sb.ToString()));
    }

    // =====================================================================
    //  GALLERY
    // =====================================================================
    public Task<List<GalleryImage>> GetAllGalleryImagesAsync()
    {
        lock (_lock) return Task.FromResult(_gallery.OrderByDescending(g => g.CreatedAt).ToList());
    }

    public Task<string> GetAboutUsContentAsync()
    {
        lock (_lock) return Task.FromResult(_aboutUs);
    }

    public Task UpdateAboutUsAsync(string aboutUs)
    {
        lock (_lock) _aboutUs = aboutUs ?? "";
        return Task.CompletedTask;
    }

    public async Task UploadGalleryImageAsync(IFormFile file, string title, string? description)
    {
        // Demo: keep the image in memory as a data URL so it shows up straight away.
        using var ms = new MemoryStream();
        await file.CopyToAsync(ms);
        var url = $"data:{file.ContentType};base64,{Convert.ToBase64String(ms.ToArray())}";

        lock (_lock)
            _gallery.Add(new GalleryImage
            {
                ImageId = Guid.NewGuid(), UploadedBy = G(100),
                Title = string.IsNullOrWhiteSpace(title) ? file.FileName : title,
                Description = description, ImageUrl = url, CreatedAt = DateTime.Now
            });
    }

    public Task UpdateGalleryImageAsync(Guid id, string title, string? description)
    {
        lock (_lock)
        {
            var g = _gallery.FirstOrDefault(x => x.ImageId == id);
            if (g != null) { g.Title = title; g.Description = description; }
        }
        return Task.CompletedTask;
    }

    public Task DeleteGalleryImageAsync(Guid id)
    {
        lock (_lock) _gallery.RemoveAll(g => g.ImageId == id);
        return Task.CompletedTask;
    }

    // =====================================================================
    //  PROFILE
    // =====================================================================
    public Task<Profile?> GetProfileByEmailAsync(string email)
    {
        lock (_lock)
        {
            var p = _profiles.FirstOrDefault(x => x.Email.Equals(email, StringComparison.OrdinalIgnoreCase))
                    ?? _profiles.First(x => x.Role == "Manager");
            return Task.FromResult<Profile?>(p);
        }
    }

    public Task UpdateProfileAsync(Profile profile)
    {
        lock (_lock)
        {
            var p = _profiles.FirstOrDefault(x => x.Id == profile.Id);
            if (p != null) { p.FullName = profile.FullName; p.Email = profile.Email; p.Phone = profile.Phone; }
        }
        return Task.CompletedTask;
    }
}
