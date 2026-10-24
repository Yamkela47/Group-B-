// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================

using CuttingEdge.ManagerPortal.Services;
using Microsoft.AspNetCore.Mvc;

namespace CuttingEdge.ManagerPortal.Controllers;

public class ReportsController : Controller
{
    private readonly SupabaseService _supabaseService;

    public ReportsController(SupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    // GET: /Reports
    public async Task<IActionResult> Index(string period = "monthly", DateTime? from = null, DateTime? to = null)
    {
        try
        {
            var report = await _supabaseService.GetReportAsync(period, from, to);

            ViewBag.Period = report.Period;
            ViewBag.FromDate = from;
            ViewBag.ToDate = to;

            return View(report);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading reports: {ex.Message}";
            return View(new CuttingEdge.ManagerPortal.ViewModels.ReportData());
        }
    }

    // GET: /Reports/Download
    public async Task<IActionResult> Download(string period = "monthly", DateTime? from = null, DateTime? to = null)
    {
        try
        {
            var report = await _supabaseService.GetReportAsync(period, from, to);
            var pdfBytes = await _supabaseService.GenerateReportPdfAsync(report);

            if (pdfBytes == null || pdfBytes.Length == 0)
            {
                TempData["Error"] = "PDF generation returned no data.";
                return RedirectToAction(nameof(Index), new { period, from, to });
            }

            // Sanitize the filename to avoid browser rejections
            var safeLabel = (report.PeriodLabel ?? "Report")
                .Replace(" ", "_")
                .Replace("/", "-")
                .Replace("\\", "-");

            return File(pdfBytes, "application/pdf", $"Reports_{safeLabel}.pdf");
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Download failed: {ex.Message}";
            return RedirectToAction(nameof(Index), new { period, from, to });
        }
    }
}