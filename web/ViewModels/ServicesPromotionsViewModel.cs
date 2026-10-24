// ============================================================
// PROJECT: Cutting Edge Salon
// STUDENT DETAILS:
// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================

using CuttingEdge.ManagerPortal.Models;

namespace CuttingEdge.ManagerPortal.ViewModels;
// Backs the Services & Promotions management page, showing both lists on one screen.

public class ServicesPromotionsViewModel
{
    public List<Service> Services { get; set; } = new(); // All available services.
    public List<Promotion> Promotions { get; set; } = new(); // All promotions (active and inactive).
}
