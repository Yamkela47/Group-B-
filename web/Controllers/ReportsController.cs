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

            ViewBag.Period = period;
            ViewBag.FromDate = from;
            ViewBag.ToDate = to;
            ViewBag.CompletedBookings = report.CompletedBookings;
            ViewBag.Cancelled = report.Cancelled;
            ViewBag.CashRevenue = report.CashRevenue;
            ViewBag.CardRevenue = report.CardRevenue;
            ViewBag.TotalRevenue = report.TotalRevenue;
            ViewBag.CashPercent = report.CashPercent;
            ViewBag.CardPercent = report.CardPercent;

            return View(report);
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error loading reports: {ex.Message}";
            return View();
        }
    }

    // GET: /Reports/Download
    public async Task<IActionResult> Download(string period = "monthly", DateTime? from = null, DateTime? to = null)
    {
        try
        {
            var report = await _supabaseService.GetReportAsync(period, from, to);
            var pdfBytes = await _supabaseService.GenerateReportPdfAsync(report);

            return File(pdfBytes, "application/pdf", $"Reports_{DateTime.UtcNow:MMMM_yyyy}.pdf");
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Error downloading report: {ex.Message}";
            return RedirectToAction(nameof(Index));
        }
    }
}