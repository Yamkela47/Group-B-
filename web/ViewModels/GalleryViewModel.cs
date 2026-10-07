using CuttingEdge.ManagerPortal.Models;

namespace CuttingEdge.ManagerPortal.ViewModels;

public class GalleryViewModel
{
    public List<GalleryImage> Images { get; set; } = new();
    public string AboutUs { get; set; } = string.Empty;
}
