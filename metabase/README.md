# Metabase BI export

Dashboard versionado para el portfolio: preguntas SQL sobre schema **`gold`** + manifest JSON importable.

## Contenido

| Archivo | Descripción |
|---------|-------------|
| `questions/*.sql` | SQL nativo de cada tarjeta |
| `exports/crypto-pulse-dashboard.json` | Layout del dashboard (colección, cards, posiciones) |
| `setup_dashboard.py` | Crea/actualiza todo vía API de Metabase |

## Dashboard: **Crypto Pulse — Prices**

1. **Source price comparison** — tabla spread CoinGecko vs Binance  
2. **Latest prices by source** — último tick por coin y fuente  
3. **Latest prices (CoinGecko)** — compat con `mart_latest_prices`  
4. **Daily average price by source** — línea temporal  
5. **Spread % by coin** — barras  

## Dashboard: **Crypto Pulse — Data Quality**

1. **Volume by zone and source** — conteos raw/silver/gold  
2. **Gold null and sanity checks** — precios nulos o ≤ 0  

## Dashboard: **Crypto Pulse — Freshness & SLA**

1. **Freshness by source** — minutos desde último evento (SLA 10 min)  
2. **Source timestamp gap** — diferencia temporal CoinGecko vs Binance por coin  

Manifests en `exports/`:

- `crypto-pulse-prices-dashboard.json`
- `crypto-pulse-quality-dashboard.json`
- `crypto-pulse-freshness-dashboard.json`

El script importa **todos** los `*-dashboard.json` por defecto. Un solo manifest:

```bash
METABASE_MANIFEST=exports/crypto-pulse-quality-dashboard.json python3 metabase/setup_dashboard.py
```

## Prerrequisitos

1. Stack arriba con datos en gold (`docker compose up`, esperar transform/dbt).
2. Metabase en http://localhost:3000 con cuenta admin creada.
3. Conexión PostgreSQL en Metabase:
   - Host: `postgres` (desde Docker) o `localhost`
   - Database: `cryptopulse`
   - User / password: `pulse` / `pulse`
   - Schema visible: **`gold`** solamente

## Import automático (recomendado)

```bash
METABASE_EMAIL=tu@email.com \
METABASE_PASSWORD=tu_password \
python3 metabase/setup_dashboard.py
```

Variables opcionales:

| Variable | Default |
|----------|---------|
| `METABASE_URL` | `http://localhost:3000` |
| `METABASE_EMAIL` | *(requerido)* |
| `METABASE_PASSWORD` | *(requerido)* |

El script es **idempotente**: vuelve a ejecutarlo tras cambiar SQL o layout y actualiza cards/dashboard existentes.

URL final impresa: `http://localhost:3000/dashboard/<id>`

## Import manual

1. **New collection** → "Crypto Pulse"
2. Por cada archivo en `questions/`: **New → SQL query** → pegar SQL → guardar en la colección
3. **New dashboard** → "Crypto Pulse — Prices" → añadir las 5 preguntas

## Screenshots para README / LinkedIn

Tras importar, captura:

- Tabla **Source price comparison** (muestra multi-fuente)
- Gráfico **Spread % by coin**

Guárdalas en `docs/screenshots/` (p. ej. `metabase-spread.png`).

## Actualizar el export

1. Edita SQL en `questions/` o layout en `exports/crypto-pulse-dashboard.json`
2. Vuelve a correr `setup_dashboard.py`
3. Commit de los cambios en git
