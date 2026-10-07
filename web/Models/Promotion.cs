namespace CuttingEdge.ManagerPortal.Models;

public class Promotion
{
    public Guid PromotionId { get; set; }
    public Guid ServiceId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? DiscountType { get; set; }
    public decimal? DiscountValue { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public bool Active { get; set; } = true;
    public string? ImageUrl { get; set; }
    public DateTime CreatedAt { get; set; }

    public Service? Service { get; set; }
}
