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
// A discount/promotion attached to a service (public.promotions).


public class Promotion
{
    public long PromotionId { get; set; } // Primary key.
    public long ServiceId { get; set; }  // FK to the service the promotion applies to.
    public string Title { get; set; } = string.Empty;  // Display headline.
    public string? Description { get; set; }  // Optional description / terms.
    public string? DiscountType { get; set; }  // How the discount is expressed, e.g. "percent" or "amount".
    public decimal? DiscountValue { get; set; }   // Numeric discount value (interpretation depends on DiscountType).
    public DateTime StartDate { get; set; } // Promotion start date
    public DateTime EndDate { get; set; } // Promotion end date.
    public bool Active { get; set; } = true; // Whether the promotion is currently enabled (defaults to true).
    public string? ImageUrl { get; set; }  // Optional banner image URL.
    public DateTime CreatedAt { get; set; }  // When the promotion was created.

    // Navigation property populated by the service layer.
    public Service? Service { get; set; }
}
