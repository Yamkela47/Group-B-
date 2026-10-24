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

/// <summary>Working hours for one weekday. Times are "HH:mm" strings (from &lt;input type="time"&gt;).</summary>
public class DaySchedule
{
    public bool Enabled { get; set; }
    public string? StartTime { get; set; }
    public string? EndTime { get; set; }
}

/// <summary>Form model for Add / Edit schedule. Keys are "Monday" ... "Sunday".</summary>
public class ScheduleViewModel
{
    public long StylistId { get; set; }
    public string? StylistName { get; set; }
    public Dictionary<string, DaySchedule> WeekSchedule { get; set; } = new();

    // Date-specific editor; unlike WeekSchedule, edits affect ONLY this selected week.
    public DateTime WeekStart { get; set; }
    public List<ScheduleDateRowViewModel> DateRows { get; set; } = new();

    // Date-specific absences from public.blocked_dates. This is display-only:
    // a blocked Tuesday must not turn off every Tuesday of the recurring week.
    public List<ScheduleBlockedDateViewModel> BlockedDates { get; set; } = new();
}


/// <summary>One actual calendar date in the week being edited.</summary>
public class ScheduleDateRowViewModel
{
    public DateTime Date { get; set; }
    public bool Enabled { get; set; }
    public string? StartTime { get; set; }
    public string? EndTime { get; set; }

    // Display-only facts loaded directly from the database. Never trust posted values.
    public bool IsBlocked { get; set; }
    public string? BlockedReason { get; set; }
    public bool HasBooking { get; set; }
    public bool IsPast { get; set; }
}

public class ScheduleBlockedDateViewModel
{
    public DateTime Date { get; set; }
    public string Reason { get; set; } = "Unavailable";
}

// <summary>One row in the schedule overview table.</summary>
public class StylistScheduleViewModel
{
    public long StylistId { get; set; }
    public string StylistName { get; set; } = string.Empty;
    public Dictionary<string, DaySchedule> WeekSchedule { get; set; } = new();
}
