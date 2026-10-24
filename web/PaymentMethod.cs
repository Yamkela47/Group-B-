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

// Lookup table of accepted payment methods (public.payment_methods).
public class PaymentMethod
{
    // Primary key.
    public long PaymentMethodId { get; set; }
    // Display name, e.g. "Cash", "Card", "EFT".
    public string MethodName { get; set; } = string.Empty;
}
