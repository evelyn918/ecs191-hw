# DressCast

DressCast is a native iOS weather app written in Swift and SwiftUI. It's a clone of the iPhone Weather app with one new feature: it tells you **what to wear and what to bring** based on the forecast for the next 12 hours.

Forecast data comes from the free [National Weather Service API](https://www.weather.gov/documentation/services-web-api) (`api.weather.gov`). It needs no API key, but it only covers US locations.

See [`proposal.md`](proposal.md) for the original Part 1 proposal.

---

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

---

## Using DressCast / Main Features 

The whole main screen fits on one page with no horizontal swiping. From top to bottom, it shows:

### 1. Current conditions
The **city name**, **current temperature**, **current conditions** (for example, "Mostly Sunny"), and today's **high (H) and low (L)**.

### 2. DressCast: what to wear and what to bring ( new feature ) 
This card sits right under the current conditions so you see it first. It looks at the **next 12 hours** of the hourly forecast and suggests:

| Suggestion | When it appears |
|---|---|
| **Shorts & T-shirt** | It gets to 75°F or warmer |
| **T-shirt & pants** | 65–74°F |
| **Light jacket** | 55–64°F |
| **Jacket** | 40–54°F |
| **Heavy coat** plus **hat & gloves** | Below 40°F |
| **Extra layer** | It gets cooler later in the day (drops 12°F or more, or dips below 60°F on a warm day). Tells you how cold it gets and when. |
| **Dress in layers** | It starts cold and warms up by 15°F or more |
| **Windbreaker** | Winds reach 20 mph or more |
| **Waterproof boots** | Snow is likely |
| **Umbrella** | Rain is expected (40% chance or higher). Shows the peak chance and time. |
| **Compact umbrella** | There's a slight chance of rain (20–39%) |
| **Sunscreen** | Sunny and 65°F or warmer, or 80°F or warmer during the day |
| **Sunglasses** | Sunny/clear daytime skies |
| **Water bottle** | It gets to 80°F or warmer |
| **Nothing extra** | Nothing needs to be brought along |

The outfit is based on the warmest **daytime** hour in the 12-hour window, since that's when you're most likely to be out. At night it uses the average temperature instead. The NWS API doesn't provide a UV index, so sunscreen is based on sunny conditions and temperature.

### 3. Hourly grid ↔ 7-day forecast (tap to switch)
- By default, the card shows **every remaining hour of today** in a grid (4 or 6 columns), so you never swipe sideways like you do in the built-in Weather app. Each cell shows the hour, a condition icon, the temperature, and the chance of rain when it's 20% or higher.
- Late in the evening, when fewer than 6 hours are left in the day, the grid shows the **next 12 hours** instead so it's never nearly empty.
- **Tap anywhere on the card** to switch to the **7-day forecast**: each day's condition icon, rain chance, low and high, and a bar showing that day's range compared to the rest of the week. Tap again to go back to the hourly grid.

### 4. Changing location
- On launch, DressCast asks for your location and shows the weather where you are.
- Tap the **🔍 magnifying glass** (top right) to type a **US city, "City, State" or ZIP code** (for example, `Sacramento, CA` or `95616`).
- In the same sheet, tap **Use My Current Location** to go back to GPS.
- **Davis, CA is the default.** If location permission is denied, no location arrives within 10 seconds, or a search can't be found or is outside the US, DressCast loads Davis, CA and shows a short banner explaining why.

### 5. Refreshing
**Pull down** on the screen to refresh the forecast. If the weather service can't be reached, an error screen appears with a **Try Again** button.

---
