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
    public Guid StylistId { get; set; }
    public string? StylistName { get; set; }
    public Dictionary<string, DaySchedule> WeekSchedule { get; set; } = new();
}

/// <summary>One row in the schedule overview table.</summary>
public class StylistScheduleViewModel
{
    public Guid StylistId { get; set; }
    public string StylistName { get; set; } = string.Empty;
    public Dictionary<string, DaySchedule> WeekSchedule { get; set; } = new();
}
