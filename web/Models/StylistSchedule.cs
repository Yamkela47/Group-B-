// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================
namespace CuttingEdge.ManagerPortal.Models;
// A stylist's working availability on a given date (public.stylist_schedules)

public class StylistSchedule
{
    public long ScheduleId { get; set; }
    public long StylistId { get; set; }
    public DateTime WorkDate { get; set; }
    public TimeSpan StartTime { get; set; }
    public TimeSpan EndTime { get; set; }
    public bool IsAvailable { get; set; } = true;

    public Stylist? Stylist { get; set; }  // Navigation property populated by the service layer.
}
