# perfect_news
# WireNews

> A high-performance, decoupled news content delivery system — async Python ingestion backend paired with a minimal Flutter reader frontend.

**Platform:** Android · iOS · Web · Desktop (via Flutter)  
**Stack:** Python 3 · asyncio · feedparser · Firebase · Flutter · Dart · C++ · GitHub Actions CI

---

## What Is It?

WireNews is a two-layer news delivery system. The backend is a Python async service that watches RSS feeds, parses articles, and pushes data to Firebase in real time. The frontend is a minimal Flutter app that reads from that data source and presents articles cleanly, with near-zero latency.

The two layers are fully decoupled — the backend runs independently and can be swapped or extended without touching the Flutter app, and the Flutter app does not care where its data comes from beyond the repository contract.

---

## Architecture

### System Overview

```
[RSS / External News APIs]
          │
          ▼  (feedparser — non-blocking poll)
[watcher.py — Python Async Ingestion Service]
          │
          ├── ArticleModel.from_json()   ← typed parsing with KeyError guards
          │
          ├── Defensive assertion layer  ← upstream API shape validation
          │
          ▼
[Firebase Realtime Database]
          │
          ▼  (stream / future)
[ArticleRepository — Flutter Data Layer]
          │
          ▼
[UI State Controller]
          │
          ▼
[Minimal Reader UI]  →  User
```

Every stage has an explicit failure boundary. Data corruption at any layer does not propagate to the next — it is logged, discarded, and the system continues.

---

### Backend: Python Async Ingestion Service (`watcher.py`)

The backend runs as a long-lived async process. It polls configured RSS sources, parses each feed, maps entries to `ArticleModel` instances, and pushes them to Firebase.

**Key design decisions:**

**Non-blocking I/O** — All network calls use `asyncio`. The watcher never blocks. Multiple feeds are polled concurrently, so a slow or timing-out upstream source does not delay ingestion of others.

**Typed ArticleModel factory** — Every raw JSON payload passes through `ArticleModel.from_json()` before it enters the pipeline. Required fields (`id`, `title`) are validated at construction time. Missing keys raise a `ValueError` that is caught and logged — not silently swallowed, and not allowed to propagate.

```python
@classmethod
def from_json(cls, data: Dict[str, Any]) -> 'ArticleModel':
    try:
        return cls(
            id=str(data['id']),
            title=str(data['title']),
            content=str(data.get('content', '')),
            source=str(data.get('source', 'Unknown'))
        )
    except KeyError as e:
        logger.error(f"Data mapping corruption: Missing required key {e}")
        raise ValueError(f"Invalid payload structure: Missing {e}")
```

**Assertion-based upstream validation** — Before processing any API response, the system asserts the expected shape. A response that is not a list causes an `AssertionError` that is caught as a critical-level event, and the pipeline returns an empty safe state instead of crashing.

**Structured logging** — Every stage of the pipeline emits structured log output via Python's `logging` module. Trace-level debugging is available without modifying production code.

---

### Frontend: Flutter Article Reader (`wire_app/`)

The Flutter frontend is intentionally minimal. It has one job: present articles from the data layer clearly and fast.

**Repository pattern** — `ArticleRepository` is the only class that knows about Firebase. Screens receive a `Stream<List<ArticleModel>>` and render from it reactively. The data source is fully swappable.

**State isolation** — No global variables. Widget state is encapsulated. The UI layer cannot directly call network or parsing code.

**Predictive local caching** — Articles are cached locally so previously loaded content renders immediately on reopen, before the network responds.

---

### CI/CD Pipeline (GitHub Actions)

Every push to `main` triggers:

```yaml
- flutter analyze        # static analysis — zero warnings policy
- flutter test           # unit + widget tests
- flutter build apk      # confirms the release build compiles
```

The pipeline prevents regressions from being merged. A commit that breaks analysis or tests cannot land silently.

---

### Engineering Commitments

| Decision | Why |
|---|---|
| Decoupled Python backend + Flutter frontend | Each layer evolves independently; the backend can be replaced (e.g. with a Node service) without touching the app |
| `asyncio` for all I/O | Multiple feeds polled concurrently — one slow source never delays others |
| Typed `ArticleModel` factory with `KeyError` guards | Data corruption is caught at the boundary, never in the UI |
| Assertion-based upstream shape validation | Explicit contract with the API — unexpected shapes are critical-logged, not silently ignored |
| Firebase as the data bus | Real-time push to all connected clients without polling from the app side |
| GitHub Actions CI | Every commit is analyzed and tested — no silent regressions |

---

## Getting Started

### Backend Setup (Python)

**Requirements:** Python 3.10+

```bash
pip install -r requirements.txt
```

**Dependencies:**

| Package | Purpose |
|---|---|
| `feedparser==6.0.10` | RSS / Atom feed parsing |
| `firebase-admin==6.2.0` | Firebase Realtime Database writes |
| `requests==2.31.0` | HTTP source fetching |

**Configure sources:**

Edit `sources.json` to add or remove RSS feeds:

```json
[
  { "name": "BBC News", "url": "http://feeds.bbci.co.uk/news/rss.xml" },
  { "name": "Reuters", "url": "https://feeds.reuters.com/reuters/topNews" }
]
```

**Run the watcher:**

```bash
python watcher.py
```

The watcher runs indefinitely, polling feeds at the configured interval and pushing new articles to Firebase.

---

### Flutter App Setup

```bash
cd wire_app
flutter pub get
flutter run
```

### Verify

```bash
flutter analyze
flutter test
```

---

## Project Structure

```
.
├── watcher.py               # Python async ingestion service (entry point)
├── sources.json             # RSS feed source configuration
├── requirements.txt         # Python dependencies
├── .github/
│   └── workflows/           # GitHub Actions CI pipeline
└── wire_app/                # Flutter frontend
    └── lib/
        ├── main.dart
        ├── models/
        │   └── article_model.dart      # Typed domain model
        ├── repositories/
        │   └── article_repository.dart # Firebase data access layer
        ├── controllers/
        │   └── feed_controller.dart    # UI state management
        └── screens/
            ├── feed_screen.dart        # Article list
            └── article_screen.dart     # Article reader
```

---

## License

MIT — see `LICENSE` for details.
