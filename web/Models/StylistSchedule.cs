namespace CuttingEdge.ManagerPortal.Models;

public class StylistSchedule
{
    public Guid ScheduleId { get; set; }
    public Guid StylistId { get; set; }
    public DateTime WorkDate { get; set; }
    public TimeSpan StartTime { get; set; }
    public TimeSpan EndTime { get; set; }
    public bool IsAvailable { get; set; } = true;

    public Stylist? Stylist { get; set; }
}
