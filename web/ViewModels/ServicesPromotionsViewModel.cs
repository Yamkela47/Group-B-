using CuttingEdge.ManagerPortal.Models;

namespace CuttingEdge.ManagerPortal.ViewModels;

public class ServicesPromotionsViewModel
{
    public List<Service> Services { get; set; } = new();
    public List<Promotion> Promotions { get; set; } = new();
}
