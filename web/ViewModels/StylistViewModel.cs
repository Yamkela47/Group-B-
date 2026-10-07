namespace CuttingEdge.ManagerPortal.ViewModels;

public class StylistViewModel
{
    public Guid StylistId { get; set; }
    public Guid ProfileId { get; set; }

    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Role { get; set; } = "Stylist";
    public string? WorkingHours { get; set; }
    public bool Active { get; set; } = true;
    public string? PhotoUrl { get; set; }

    /// <summary>Checked services (checkbox name="ServiceIds").</summary>
    public List<Guid> ServiceIds { get; set; } = new();
}
