namespace CuttingEdge.ManagerPortal.Models;

public class Service
{
    public Guid ServiceId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public int DurationMinutes { get; set; }
    public bool IsFlagship { get; set; }
    public bool Active { get; set; } = true;
    public DateTime CreatedAt { get; set; }
}
