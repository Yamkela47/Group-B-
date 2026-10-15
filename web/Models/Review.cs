namespace CuttingEdge.ManagerPortal.Models;

public class Review
{
    public Guid ReviewId { get; set; }
    public Guid BookingId { get; set; }
    public Guid CustomerId { get; set; }
    public Guid StylistId { get; set; }
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public bool FollowUpRequired { get; set; }
    public bool Resolved { get; set; }
    public DateTime CreatedAt { get; set; }

    public Booking? Booking { get; set; }
    public Profile? Customer { get; set; }
    public Stylist? Stylist { get; set; }
}
