using CuttingEdge.ManagerPortal.Models;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace CuttingEdge.ManagerPortal.Controllers;

public class HomeController : Controller
{
    // GET: /Home
    // The app always starts on the welcome screen. The button on that page
    // changes to "Continue to Dashboard" if the manager is already signed in.
    public IActionResult Index()
    {
        return View("Index");
    }

    // GET: /Home/Welcome
    // Always renders the welcome screen — used by the Back button on the Login page.
    [HttpGet]
    public IActionResult Welcome()
    {
        return View("Index");
    }

    // GET: /Home/Privacy
    public IActionResult Privacy()
    {
        return View();
    }

    // GET: /Home/Error
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel
        {
            RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier
        });
    }
}