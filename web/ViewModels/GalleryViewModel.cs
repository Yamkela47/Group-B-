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
// Backs the Gallery management page: the list of images plus the editable
// About Us copy shown on the public site.

public class GalleryViewModel
{
    // Images rendered in the gallery grid.
    public List<GalleryImage> Images { get; set; } = new();
    public string AboutUs { get; set; } = string.Empty; // Editable "About Us" text; defaults to empty so the view can render safely.
}
