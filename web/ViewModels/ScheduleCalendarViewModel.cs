// ============================================================
// PROJECT: Cutting Edge Salon
// STUDENT DETAILS:
// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================

namespace CuttingEdge.ManagerPortal.ViewModels;

// Backs the month-view schedule calendar: one entry per day, plus the
// available stylists and the currently selected filter.

public class ScheduleCalendarViewModel
{
    public DateTime Month { get; set; }
    public List<ScheduleCalendarDay> Days { get; set; } = new();
    public List<CuttingEdge.ManagerPortal.Models.Stylist> Stylists { get; set; } = new();
    public long? SelectedStylistId { get; set; }
    public string? Error { get; set; }
}

// One day cell in the calendar: shifts, blocked dates, and active booking count.
public class ScheduleCalendarDay
{
    public DateTime Date { get; set; }
    public List<ScheduleCalendarShift> Shifts { get; set; } = new();
    public List<ScheduleCalendarBlockedDate> BlockedDates { get; set; } = new();
    public int ActiveBookings { get; set; }
}

// A single shift on the calendar, tied to a stylist.
public class ScheduleCalendarShift
{
    public long StylistId { get; set; }
    public string StylistName { get; set; } = "";
    public string Hours { get; set; } = "";
    public int BookingCount { get; set; }
    public bool IsAvailable { get; set; }
}

// A stylist's blocked date as shown on the calendar.
public class ScheduleCalendarBlockedDate
{
    public long StylistId { get; set; }
    public string StylistName { get; set; } = "";
    public string Reason { get; set; } = "Not specified";
}
