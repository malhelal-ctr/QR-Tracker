# QR Tracker (Flutter)

Mobile app for tracking a laser QR printing machine. Android APK + web PWA from one Flutter codebase.

- **Import** your QR list (CSV / TXT / XLSX, one column, in print order)
- **Scan** the code the machine is printing → `#12,450 of 30,000`, % done, remaining, since last scan, next code
  - flashlight button, "light code on dark surface" switch for laser-marked codes, manual entry
- **Daily log** each morning: machine counter (before reset) + day's target; history with +/- vs target
- **Dashboard**: print position, today's progress vs target, avg per day, estimated finish, needed per day
- **Lid stock**: log deliveries received, waste and physical stock counts; usage comes from the daily
  machine counter (1 lid per printed code). Shows lids on hand (live, minus today's scanned printing),
  days of cover at the average daily use, whether stock covers the rest of the QR list, and a low-stock alert
- **Data**: period end date, CSV export (log, scans, lid stock), full backup / restore (same format as the Ionic version)

All data stays on the device (Hive: files on Android, IndexedDB on web). Works offline.

## Project structure (feature-based, Cubit)

```
lib/
  main.dart                     app entry: opens storage, provides TrackerRepository
  core/
    data/                       models (Scan, Day), TrackerRepository (Hive), ProgressStats, RepositoryListener
    theme/app_theme.dart        "Industrial Optical Matrix" colors, fonts, Material theme
    widgets/app_widgets.dart    shared UI: Panel, Metric, Pill, Meter, BigButton, TrackerAppBar…
    utils/                      format (numbers/dates), file_io (CSV/XLSX parse, save/pick files)
  features/
    main/        cubit/ widget/                    bottom-nav shell + selected tab
    dashboard/   screen/ widget/ model/ cubit/
    scan/        screen/ widget/ model/ cubit/
    daily_log/   screen/ widget/ model/ cubit/
    stock/       screen/ widget/ model/ cubit/      lid stock: deliveries, waste, counts, low-stock alert
    data/        screen/ widget/ model/ cubit/
```

Each `screen/` provides its cubit (`BlocProvider`) and builds from its state (`BlocBuilder`).
Cubits read and write through `TrackerRepository` and refresh when its `changes` stream fires,
so a scan on the Scan tab updates the Dashboard and Data screens automatically.

## Responsive sizes (sizer) and tablet layout

The app is wrapped in `Sizer`, which measures the screen (phone/tablet, orientation).
All sizes are written in design pixels from the Stitch file and converted with `.r`
(`core/utils/responsive.dart`), which scales by sizer's `vmin` (shortest screen side):

- Phone: design frame 375 → the layout keeps the Stitch proportions on every phone.
- Tablet: design frame 720 → controls stay a comfortable size and the extra room goes to layout.
- Text sizes are scaled inside `mono()` / `sans()`, so pass the design value (e.g. `sans(14)`).

Tablet layout (`core/widgets/adaptive_layout.dart`):
- Side navigation rail instead of the bottom bar.
- Landscape (≥ 840 px wide): two columns — Dashboard (position | today + plan),
  Scan (camera + controls | result), Daily log (form | history), Data (list + period | export + danger zone).
- Portrait: one centred column with a comfortable width.

## Tools on this PC

Flutter `C:\env\flutter`, JDK 21 `C:\env\jdk-21`, Android SDK `C:\env` (set with `flutter config`).

## Run / build (PowerShell)

```powershell
$env:Path = "C:\env\flutter\bin;$env:Path"; $env:JAVA_HOME = "C:\env\jdk-21"
flutter run -d chrome          # try it on the PC
flutter build apk --release    # → build\app\outputs\flutter-apk\app-release.apk
flutter build web --release    # → build\web  (PWA, host on any https site)
```

Install the APK: copy it to the phone and tap it (allow "Install unknown apps").

iPhone: host `build\web` on any https site, open it in Safari → Share → Add to Home Screen.
The web scanner loads its QR library from a CDN the first time, so open the Scan tab once while online.

## Widget catalog (Widgetbook)

`widgetbook/` is a separate entry point that shows the UI widgets on their own, with knobs to
change their props and a device picker (phones, tablet). It is a dev dependency, so it is not part
of the app or the APK, and it lives outside `lib/` (code in `lib/` can't import dev dependencies).

```
widgetbook/
  main.dart                 Widgetbook app: device viewports, text scale, inspector; wraps each use case in Sizer + app theme
  core_use_cases.dart       shared widgets: BigButton, Pill, Meter, Metric, Panel, DateRow, PeriodChips, StepperField…
  feature_use_cases.dart    feature cards: Dashboard (position, today, plan, stock), Daily log, Data
```

```powershell
flutter run -t widgetbook/main.dart -d chrome                        # open the catalog
flutter build web -t widgetbook/main.dart -o build\widgetbook         # static build to host or share
```

To add a widget: add a `WidgetbookComponent` with one or more `WidgetbookUseCase`s to the matching
`*_use_cases.dart` list. Widgets that need a cubit, the camera or a file picker (screens, scanner,
import sheet, save forms) are not in the catalog yet.
