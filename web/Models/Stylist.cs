namespace CuttingEdge.ManagerPortal.Models;

public class Stylist
{
    public Guid StylistId { get; set; }
    public Guid ProfileId { get; set; }
    public string? PhotoUrl { get; set; }
    public bool Active { get; set; } = true;
    public DateTime CreatedAt { get; set; }

    public Profile? Profile { get; set; }
}
