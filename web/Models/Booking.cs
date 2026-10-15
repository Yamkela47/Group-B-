namespace CuttingEdge.ManagerPortal.Models;

public class Booking
{
    public Guid BookingId { get; set; }
    public Guid CustomerId { get; set; }
    public Guid StylistId { get; set; }
    public Guid ServiceId { get; set; }
    public Guid PaymentMethodId { get; set; }
    public DateTime AppointmentDate { get; set; }
    public TimeSpan StartTime { get; set; }
    public TimeSpan EndTime { get; set; }
    public string Status { get; set; } = "Incomplete";
    public string? AdditionalNotes { get; set; }
    public DateTime CreatedAt { get; set; }

    // Navigation properties (filled in by the service layer)
    public Profile? Customer { get; set; }
    public Stylist? Stylist { get; set; }
    public Service? Service { get; set; }
    public PaymentMethod? PaymentMethod { get; set; }
}
