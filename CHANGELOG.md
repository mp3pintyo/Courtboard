# Changelog / Változásnapló

A részletes, kétnyelvű kiadási jegyzetek a [GitHub Releases](https://github.com/mp3pintyo/Courtboard/releases) oldalon olvashatók.
Detailed bilingual release notes are available on [GitHub Releases](https://github.com/mp3pintyo/Courtboard/releases).

## 0.9.0

**HU** – Infrastruktúra: egységes, lemezes JSON-gyorsítótár (`%APPDATA%\Courtboard\cache`) elavult-adat visszaeséssel és negatív cache-sel; közös HTTP-réteg egyetlen klienssel, szolgáltatónkénti kéréskorláttal, helyi napi/havi keretszámlálóval és újrapróbálással; kvótavédő cache az API-Sports, football-data.org, BALLDONTLIE, TheSportsDB és FotMob hívásokra; frissességi adatok (letöltés ideje, gyorsítótárból) a profilkártyákon; HTML/RSS-feldolgozás külön isolate-ban; a hírarchívum modulokra bontva, indexekkel, upserttel, megőrzési szabállyal és FTS5 teljes szöveges kereséssel.

**EN** – Infrastructure: unified on-disk JSON cache (`%APPDATA%\Courtboard\cache`) with stale fallback and negative caching; shared HTTP layer with one client, per-provider rate limiting, local daily/monthly quota tracking and retries; quota-protecting caches for API-Sports, football-data.org, BALLDONTLIE, TheSportsDB and FotMob; freshness metadata (fetched at, from cache) on profile cards; HTML/RSS parsing off the UI isolate; news archive split into modules with indexes, upserts, retention and FTS5 full-text search.

**HU** – Biztonság és kódminőség: az API-kulcsok a Windows Hitelesítőadat-kezelőbe kerülnek (titkosítva), a régi, titkosítatlan JSON-kulcsok első indításkor ellenőrzött migrációval költöznek át; tárolóhiba esetén a kulcsok nem vesznek el, és az Adatforrások oldal figyelmeztet. A RapidAPI kulcs semleges `RAPIDAPI_KEY` nevet kapott (a `RAPIDAPI_DARTS_KEY` továbbra is működik). Szigorúbb statikus elemzés (`strict-casts`, `strict-inference`, `strict-raw-types`, aszinkron és erőforrás-lintek).

**EN** – Security and code quality: API keys are stored in Windows Credential Manager (encrypted); legacy plain-text JSON keys are migrated with read-back verification on first launch, and are never lost if the store fails (the Data Sources page shows a warning). The RapidAPI key is now the neutral `RAPIDAPI_KEY` (`RAPIDAPI_DARTS_KEY` still works). Stricter static analysis (`strict-casts`, `strict-inference`, `strict-raw-types`, async and resource lints).

## 0.8.1

**HU** – Stabilitási és biztonsági javítások: atomikus, sorba rendezett állapotmentés sérültfájl-mentéssel; helyes hazai/vendég felismerés (football-data.org); NBA/WNBA szezonváltás és WNBA-cache frissítés; HTTP-időkorlátok; név szerinti keresés hamis találatok nélkül; biztonságos linkmegnyitás (`url_launcher`, csak http/https); érthető magyar hibaüzenetek újrapróbálással; kitalált adatok eltávolítása; navigáció-, kereső- és rendezésjavítások.

**EN** – Stability and security fixes: atomic, serialized state saving with corrupt-file backup; correct home/away detection (football-data.org); NBA/WNBA season rollover and WNBA cache refresh; HTTP timeouts; no false-positive name lookups; safe link opening (`url_launcher`, http/https only); friendly Hungarian errors with retry; fabricated data removed; navigation, search and ordering fixes.

## 0.8.0

**HU** – Dinamikus football-data.org játékos- és csapatfeloldás, Messi/Inter Miami javítások, moduláris `lib/ui/` felület.

**EN** – Dynamic football-data.org player and team resolution, Messi/Inter Miami fixes, modular `lib/ui/` structure.
