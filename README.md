# DressCast

DressCast is a native iOS weather app written in Swift and SwiftUI. It's a clone of the iPhone Weather app with one new feature: it tells you **what to wear and what to bring** based on the forecast for the hours you'll actually be out, what you're doing, and what you usually carry.

Forecast data comes from the free [National Weather Service API](https://www.weather.gov/documentation/services-web-api) (`api.weather.gov`). It needs no API key, but it only covers US locations.

See [`proposal.md`](proposal.md) for the original Part 1 proposal.

## Requirements

- macOS with **Xcode 16 or later** (built and tested with Xcode 27)
- An iPhone simulator, or an iPhone running **iOS 17 or later**
- An internet connection, since the forecast is fetched live

No third-party packages, API keys or setup scripts are needed.


## How to build app / Project Structure 
```
DressCast/
├── DressCast.xcodeproj
└── DressCast/
    ├── DressCastApp.swift            App entry point
    ├── ContentView.swift             Main screen, header, location search sheet, error view
    ├── Models/
    │   ├── NWSModels.swift           Decodable types for api.weather.gov responses
    │   ├── ForecastSummary.swift     Current temp, today's high/low, hour grid, 7-day pairing
    │   └── OutfitAdvisor.swift       What-to-wear / what-to-bring rules (new feature)
    ├── Services/
    │   ├── WeatherService.swift      NWS networking (points → hourly + daily forecasts)
    │   └── LocationProvider.swift    GPS location and place-name search
    ├── ViewModels/
    │   └── WeatherViewModel.swift    Loading state and the Davis, CA fallback
    └── Views/
        ├── AdviceCard.swift          DressCast wear/bring card
        ├── ForecastCard.swift        Tappable hourly grid / 7-day list
        └── WeatherStyle.swift        Condition icons, background colors, card styling
```

### How the weather data is fetched
1. `GET https://api.weather.gov/points/{lat},{lon}` returns the city name, time zone, and the forecast URLs for that spot.
2. The app fetches the `forecastHourly` URL (hourly grid and the 12-hour outfit advice) and the `forecast` URL (day/night periods paired into the 7-day highs and lows) in parallel.
3. Requests send a `User-Agent` header, as NWS asks, and retry automatically on the occasional 5xx error from NWS.

## To run

### In Xcode (recommended)

1. Clone the repository and open the project:
   ```bash
   git clone <repo-url>
   cd ecs191-hw
   open DressCast/DressCast.xcodeproj
   ```
2. In the toolbar, select the **DressCast** scheme and an iPhone simulator (for example, **iPhone 17**).
3. Press **⌘R** (Product ▸ Run).
4. When the app asks, allow location access, or choose **Don't Allow** to see the Davis, CA default.


## Using DressCast / Main Features 

### First launch: Personal Setup
The first time you open DressCast, a one-screen **Personal Setup** appears. You can reopen it any time with the **⚙︎ gear** (top left).

- **Your items:** for an extra layer, sunscreen, sunglasses, a water bottle and a hat, choose:
  - **Remind me** (default): DressCast suggests it when the forecast makes it useful.
  - **I always bring it**: you already carry it, so it's never suggested.
  - **Never**: you don't want it, so it's never suggested.
- **Do you run cold, normal, or warm?** Cold shifts the coat and jacket thresholds 5° warmer (you get a jacket sooner); warm shifts them 5° cooler.
- **How do you get around?** Walk, bike, bus, or drive. Walking and biking make rain and wind matter more.

### 2. DressCast: what to wear and what to bring ( new feature ) 
This card sits right under the current conditions so you see it first. It looks at the **next 12 hours** of the hourly forecast and suggests:

### The main screen
The whole screen fits on one page with no horizontal swiping. From top to bottom:

1. **Location bar:** ⚙︎ Personal Setup, the city name, and 🔍 to change location.
2. **Time window chip**, e.g. **"Out 8 AM to 5 PM"**. Tap it to pick when you **leave** and when you're **back** (and whether that's today or tomorrow). By default the window is **now until 10 PM**. After 8 PM it switches to **tomorrow, 8 AM to 5 PM** and says "Tomorrow" on the chip.
3. **Activity menu:** **Class/Work**, **Outdoors**, or **Evening out**. DressCast remembers your last choice.
   - **Class/Work:** you're inside most of the day, so only the trip out (first hour of the window) and the trip home (last hour) count.
   - **Outdoors:** every hour counts, and sun, heat, rain and wind matter more.
   - **Evening out:** every hour in the window counts, with normal limits.
4. **DressCast advice ⭐ (the main feature):** a one-line verdict like **"Jacket and umbrella today."**, followed by each suggestion with a reason taken from the forecast, e.g. *"50° at 8 AM but 71° by 4 PM, so wear layers you can take off"* or *"60% chance of rain at 4 PM on your way home"*. If nothing is needed, it says **"Nothing special today."**
5. **Current conditions:** the current temperature, conditions, and today's high and low.
6. **Your hours / 7-day forecast:** a compact grid of just the hours in your window (time, icon, temperature, rain chance when 20% or higher). Tap **7-Day** in the card's corner to switch to the week, and **Hourly** to switch back.

#### When each suggestion appears

| Suggestion | Kind | When it appears |
|---|---|---|
| **Warm coat / Jacket / Light jacket** | Essential | The coldest hour you're outside feels below 40° / 55° / 63° (adjusted by cold/normal/warm) |
| **Windbreaker** | Essential | Wind reaches 15 mph (walking, biking or outdoors) or 25 mph (otherwise) |
| **Waterproof boots** | Essential | Snow is likely (30%+) |
| **Umbrella** | Essential | Rain chance reaches 30% (walking, biking or outdoors) or 50% (otherwise) |
| **Extra layer** | Personal | The temperature swings 15° or more while you're out |
| **Warm hat / Sun hat** | Personal | It feels below 40°, or it's sunny and 80°+ (75°+ outdoors) |
| **Sunscreen** | Personal | Sunny daytime hour at 70°+ (60°+ outdoors) |
| **Sunglasses** | Personal | Any sunny or clear daytime hour |
| **Water bottle** | Personal | It gets to 80°+ (75°+ outdoors) |

"Personal" items only appear if you chose **Remind me** for them. The NWS API doesn't provide a UV index, so sun advice is based on sunny conditions and temperature.

### Tappable days
In the 7-day forecast, **tap any day** to open its detail screen: that day's conditions, **high and low**, its own **DressCast advice**, and its **hours inside your time window**, using the same setup, window and activity as the main screen. Tap the **‹ back** button (or swipe from the left edge) to return.

### Changing location
- On launch, DressCast asks for your location and shows the weather where you are.
- Tap the **🔍 magnifying glass** (top right) to type a **US city, "City, State" or ZIP code** (for example, `Sacramento, CA` or `95616`).
- In the same sheet, tap **Use My Current Location** to go back to GPS.
- **Davis, CA is the default.** If location permission is denied, no location arrives within 10 seconds, or a search can't be found or is outside the US, DressCast loads Davis, CA and shows a short banner explaining why.

### Refreshing
**Pull down** on the screen to refresh the forecast. If the weather service can't be reached, an error screen appears with a **Try Again** button.

