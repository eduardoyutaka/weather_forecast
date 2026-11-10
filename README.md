# Weather Forecast

A Ruby on Rails app that takes a US ZIP code, retrieves the current weather for it, caches the result for 30 minutes per ZIP code and tells the user whether what they're seeing came from the cache.

## Requirements coverage

| Requirement | Implementation |
| --- | --- |
| Accept an address as input | The user enters a US ZIP code (ZIP+4 accepted). It's geocoded into an `Address` (city, state, coordinates) through [Zippopotam.us](https://zippopotam.us). See [Assumptions](#assumptions). |
| Retrieve forecast data (bonus: high/low) | [OpenWeatherMap Current Weather](https://openweathermap.org/current): temperature, high/low and a description, in °F. |
| Display the forecast | `/addresses/:zip` shows the location and lazy-loads the forecast in a Turbo Frame. |
| Cache for 30 minutes by ZIP code | `Rails.cache.fetch("forecast/v1/us/#{zip}", expires_in: 30.minutes)` in `ForecastService`. |
| Indicator when served from cache | A **Live** or **Cached** badge, plus "fetched N minutes ago". |

## Running locally

**Prerequisites:** Ruby 4.0.9 (see `.ruby-version`) and SQLite 3. Google Chrome is needed only for system tests. Other gems, including Rails 8.1, come from `bundle install`.

```bash
git clone https://github.com/eduardoyutaka/weather_forecast.git
cd weather_forecast
bundle install
bin/rails db:prepare
```

Provide an OpenWeatherMap API key. Either option works; the environment variable takes precedence:

```bash
# Option A: use the key in the encrypted credentials (shared for evaluation purposes only)
echo "09fee242a17a0fb1e950d42b596e2dd5" > config/master.key

# Option B: use your own free key from https://home.openweathermap.org/api_keys
export OPENWEATHERMAP_API_KEY=your-key
```

> Publishing `master.key` is a deliberate trade-off so evaluators can run the app with zero setup. In a real project the key would live only in the deployment's secret store and this one would be rotated.

```bash
bin/dev            # http://localhost:3000
```

### Tests and checks

```bash
bin/rails test           # unit + integration tests (no network, no secrets needed)
bin/rails test:system    # browser tests in headless Chrome
bin/ci                   # everything CI runs: RuboCop, Brakeman, bundler-audit, importmap audit, all tests
```

## Architecture

```
Browser
  │  POST /addresses (postal_code)
  ▼
AddressesController#create ──► AddressLookup ──► Address (SQLite, unique index on postal_code)
  │                                  └─ first time a ZIP is seen ──► ZippopotamClient ──► api.zippopotam.us
  │  303 See Other
  ▼
GET /addresses/10001 ──► AddressesController#show (renders page + <turbo-frame src=…/forecast>)
                                                                 │
GET /addresses/10001/forecast ◄─────────────────────────────────┘
  ▼
ForecastsController#show ──► ForecastService ──► Rails.cache (30 min TTL, keyed by ZIP)
                                                       └─ on miss ──► OpenWeatherMapClient ──► api.openweathermap.org
```

| Layer | Location | Responsibility |
| --- | --- | --- |
| Controllers | `app/controllers` | HTTP concerns only: params, status codes, rendering, mapping domain errors to user-facing messages. |
| Services | `app/services` | Use cases. `AddressLookup` (DB first, geocode on miss, race-safe insert) and `ForecastService` (cache-aside around the weather client). |
| Clients | `app/clients` | Adapters to third-party APIs. `ApiClient` owns timeouts, status-code mapping and JSON parsing; subclasses only build the request and map the payload. |
| Models | `app/models` | `Address` (ActiveRecord: normalization, validation, URL param) and `Forecast` (an immutable `Data` value object, never persisted). |

## Design decisions and trade-offs

**Lean controllers, service objects, client adapters.**
Controllers don't know about HTTP clients, JSON shapes or cache keys. Services depend on clients through constructor injection, so tests swap in fakes without a mocking library, and a different weather provider can be added without touching controllers. The clients act as an anti-corruption layer: provider-specific field names such as `"place name"` and `"temp_max"` never leak past them.

**Persist the address, cache the forecast.**
A ZIP code's coordinates are effectively static, so the geocoding result is stored once in `addresses`. Later searches for that ZIP never call the geocoder again. A forecast is ephemeral: it's stale after 30 minutes. It lives only in `Rails.cache` with an explicit TTL rather than in a table that would grow forever and need pruning. An earlier version wrote a `weather_data` row per API call; a migration drops that table.

**Cache design.**
- *Key per ZIP code* (`forecast/v1/us/10001`), as the requirement asks, not per database row.
- *Versioned key.* Cached `Forecast` objects are marshaled Ruby objects, so the `v1` is bumped whenever their shape changes. That way an old entry is never deserialized into a new structure.
- *Failures are never cached.* Errors propagate out of the `fetch` block, so nothing is written. The original version rescued inside the block and cached `nil`/`true` for 30 minutes.
- *Cache indicator.* `fetch` runs its block only on a miss. A flag set inside the block tells the view whether the value was computed (**Live**) or read (**Cached**), with no extra cache round-trip.
- *Stampede protection.* `race_condition_ttl: 10.seconds` means that when a hot entry expires, the first reader refreshes it while concurrent readers keep receiving the stale value instead of all calling the API (see [Scaling](#production-and-scaling-considerations)).
- *Store.* Development uses `:memory_store` and production uses Solid Cache (Rails 8's database-backed cache, already configured in `config/cache.yml`). Swapping to Redis is a one-line `config.cache_store` change, because the code only talks to `Rails.cache`.

**`Net::HTTP` instead of Faraday or HTTParty.**
Two GET requests don't justify a dependency. Everything that matters is explicit in `ApiClient`:
- connect and read timeouts;
- a closed set of error classes;
- no secrets in error messages.

With more integrations, retries or middleware needs, I'd move to Faraday with `faraday-retry`.

**Defensive boundaries.**
- *Input:* `Address` normalizes the ZIP (whitespace, ZIP+4 → 5 digits) and `AddressLookup` rejects anything that isn't exactly five digits *before* any network call. `ZippopotamClient` re-checks the format too, because the value is interpolated into a URL path (`../` would otherwise change which endpoint is called). Nested or array params can't produce a 500.
- *Output:* payload mapping uses `fetch`/`dig`, so a missing field becomes `ApiClient::InvalidResponseError` instead of a `NoMethodError` in a view.
- *Abuse:* Rails 8's built-in `rate_limit` caps searches at 10 per minute per client, which protects the upstream API quotas.

**Race-safe address creation.**
Two users searching the same new ZIP at the same moment can both miss the `find_by`. A unique index plus `create_or_find_by!` turns the second INSERT into a read of the winner's row. There is deliberately no `validates :postal_code, uniqueness: true`. Its pre-check SELECT would raise `RecordInvalid` in that race instead of the `RecordNotUnique` that `create_or_find_by!` recovers from.

**Lazy-loaded forecast frame.**
The address page renders immediately from the database. The forecast loads in a `<turbo-frame>`, so a slow or failing weather API degrades only that box and never the page. Errors render a message inside the frame with the correct status code.

**Readable URLs.**
`Address#to_param` returns the ZIP code, so URLs are `/addresses/10001`. They are bookmarkable and don't expose sequential IDs.

**Errors are reported, not just logged.**
Handled upstream failures go through `Rails.error.report`, so plugging in Sentry, Honeybadger or similar requires no code changes.

## Failure modes

| Situation | Result |
| --- | --- |
| Blank, malformed or nested `postal_code` | 422 with the form re-rendered and "Please enter a valid 5-digit US ZIP code." No network call is made. |
| ZIP unknown to the geocoder (404) | 422: "We couldn't find a US location for that ZIP code." |
| Geocoder timeout, connection error, 5xx or 429 | 503 on the search form: "Location lookup is temporarily unavailable…" |
| Weather API timeout, connection error, 5xx, malformed JSON or missing fields | 503 inside the forecast frame. The rest of the page still works, and nothing is cached. |
| Weather API rate limit (429) | Same as above, and the upstream `Retry-After` is forwarded. |
| Weather API rejects the key (401/403) or no key configured | `ApiClient::ConfigurationError` is reported to the error tracker, and the user sees the same 503 message. |
| More than 10 searches per minute from one client | 429 with the form and "Too many searches…" |
| Unknown `/addresses/:zip` | 404 |

Timeouts are 2 seconds to connect and 5 seconds per read (`ApiClient::OPEN_TIMEOUT` and `READ_TIMEOUT`). A hung upstream therefore occupies a Puma thread for seconds rather than indefinitely.

## Testing strategy

There are 47 Minitest tests plus 2 system tests. `WebMock.disable_net_connect!` guarantees the suite never touches the real APIs, and a fake API key is pinned, so it runs in CI without secrets.

| Layer | What's covered |
| --- | --- |
| Clients (`test/clients`) | Success mapping; 404; 429 with `Retry-After`; 401; 500/502/503; timeouts; refused or reset connections; DNS failure; malformed JSON; missing or mistyped fields; path-injection attempts; the API key never appearing in error messages. |
| Model (`test/models`) | Normalization; invalid formats; coordinate ranges; uniqueness enforced by the database. |
| Services (`test/services`) | Cache miss then hit (one upstream call); expiry after 30 minutes using time travel; failures not cached; key per ZIP; stampede (a concurrent reader gets the stale value during a refresh); DB-first lookup with no HTTP call; the concurrent-insert race. |
| Integration (`test/controllers`) | Status codes and messages for invalid input, unknown ZIP, upstream outage, malformed upstream data, upstream 429 (`Retry-After` forwarding) and unknown addresses, plus Live → Cached → Live across the TTL through real requests. |
| System (`test/system`) | A browser search through to the rendered forecast in the lazy frame, and the validation error. |

Services are tested with injected fakes and an in-memory cache rather than stubbed HTTP, so they assert on behaviour (how many upstream calls happened) instead of implementation. The stampede and race tests were checked by deleting the mechanism they guard (`race_condition_ttl` and `create_or_find_by!`) and confirming that they fail.

## Production and scaling considerations

- **Cache stampede.** `race_condition_ttl` covers the common case: a hot key expiring. It doesn't help a *cold* key that many requests hit at once. Options, by increasing complexity:
  - A short distributed lock around the refresh (Redis `SET NX PX`, or a DB advisory lock).
  - Request coalescing within a process.
  - Refreshing popular ZIP codes ahead of expiry in a background job, so users never wait on the API.
- **Background processing.** Solid Queue is already configured. A recurring job could pre-warm the top N ZIP codes; with Sidekiq/Redis the same job would be a few lines. The request path stays synchronous today because a cache miss costs a single API call bounded by the client timeouts.
- **Resilience next steps.**
  - A circuit breaker around each client (e.g. Semian or Stoplight), so a dead provider fails fast instead of consuming threads for 5 seconds.
  - Serve-stale-on-error: keep the last good forecast past its TTL and show it with a "may be outdated" flag.
  - A secondary weather provider behind the same client interface.
  - Retries with jitter for background refreshes only, not in the request path.
- **Database.** Each request performs one indexed lookup by `postal_code`. There are no collections rendered, so there is no N+1 surface. If features such as "recent searches" were added, I'd use `includes` and counter caches and watch the query log (`verbose_query_logs` is on in development).
- **Horizontal scale.** The app servers are stateless. The cache must be shared across instances (Solid Cache or Redis, never `:memory_store`) for the 30-minute guarantee to hold cluster-wide. Solid Cache trades a little latency for much larger, cheaper, disk-backed capacity; Redis is the better fit when sub-millisecond reads matter.
- **Service boundaries.** The `Forecast` value object and the client interface form a natural contract. The weather integration could be extracted into a separate service (for example Go with a ProtoBuf/gRPC contract) without changing controllers or views; only `OpenWeatherMapClient` would change.
- **Observability.** Wrap client calls in `ActiveSupport::Notifications.instrument` to emit upstream latency, error rate and cache hit ratio, and subscribe an error tracker to `Rails.error`.

## Assumptions

- "Address" is interpreted as a US ZIP code: it's what the forecast is cached by, and ZIP-only input avoids a paid geocoding API. Accepting a full street address would add a geocoder (e.g. the US Census Geocoder) in front of `AddressLookup`, with no other changes.
- US only, so temperatures are in Fahrenheit.
- Weather comes from OpenWeatherMap's free tier.

## Known limitations and next steps

- OpenWeatherMap's current-weather `temp_min`/`temp_max` describe variation across the area *right now*, not the day's high and low. The free 5-day/3-hour endpoint (`/data/2.5/forecast`) could be aggregated into true daily highs and lows plus an extended forecast.
- Unknown ZIP codes aren't negatively cached, so repeated searches for the same invalid ZIP hit the geocoder (the rate limiter bounds this). A short-TTL negative cache entry would remove it.
- International postal codes: Zippopotam supports other countries, but this would also need a country selector, unit preferences and a different ZIP format check per country.
- User-facing strings would move to `config/locales` for i18n.
- Loading state is plain text. A skeleton or spinner would improve perceived performance.
