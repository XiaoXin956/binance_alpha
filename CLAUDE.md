# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Binance Alpha (币安阿尔法) — a Flutter mobile/web app that displays Binance airdrop events, real-time token prices, and airdrop history. Uses Material 3 design and Chinese-language UI.

## Commands

```bash
flutter run                  # Run on connected device or emulator
flutter build apk            # Build Android APK
flutter build web            # Build for web
flutter analyze              # Static analysis (uses flutter_lints)
flutter test                 # Run all tests
flutter test test/widget_test.dart  # Run single test file
```

## Architecture

```
lib/
  main.dart                   # App entry, MainScreen with bottom NavigationBar (IndexedStack)
  models/data_model.dart      # All data models and JSON parsing
  services/
    api_service.dart           # HTTP client hitting https://alpha123.uk
    widget_service.dart        # Android home-screen widget via MethodChannel
  pages/
    home_page.dart             # Current airdrops, BNB price header, Top 3 bottom bar
    history_page.dart          # Historical airdrop list (date-sorted)
```

**Data flow:** `ApiService` (static methods) → `models` (`fromJson` factories) → `StatefulWidget` pages.

**Two API endpoints consumed:**
- `/api/data?fresh=1` → `DataResponse` (airdrops, alpha_checkins, top3_tokens, bnb_price_usd)
- `/api/historydata` → `HistoryResponse` (all historical airdrops)
- `/api/price/?batch_dex=true` → `PriceResponse` (token prices, has multi-attempt retry logic with varying headers)

**AirdropItem.type** drives card rendering: `"grab"` shows `_GrabCard`, `"warning"` shows `_WarningCard` (with red border, contract address, tx hash).

**WidgetService** pushes JSON payloads to an Android native widget via `MethodChannel('com.xiaoxin.binance_alpha/widget')`.

## Key Conventions

- All UI text is in Chinese (Simplified). Status strings use English internally (`announced`, `ongoing`, `completed`, `upcoming`) and are mapped to Chinese display text via `statusText`/`_statusText()`.
- `_formatNumber()` is duplicated in three files — it adds thousand-separator commas. Models also have `_parseString`, `_parseInt`, `_parseDouble`, `_parseBool` helpers for tolerant JSON parsing (handles String/int/double interchangeably).
- Home page auto-refreshes every 10 minutes via `Timer.periodic`. Price fetch has a 6-strategy fallback chain to work around 403 responses.
- `refreshIndicator` pull-to-refresh is implemented on both pages.
