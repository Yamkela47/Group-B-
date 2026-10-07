namespace CuttingEdge.ManagerPortal.Models;

public class Cancellation
{
    public Guid CancellationId { get; set; }
    public Guid BookingId { get; set; }
    public string? Reason { get; set; }
    public DateTime CancelledAt { get; set; }

    public Booking? Booking { get; set; }
}
