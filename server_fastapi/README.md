# SK Bags FastAPI Service

This Python service is focused on the single recent BUSY database:

- `BusyComp0019_db12026`

It exposes:

- browser dashboard home at `http://localhost:8000/`
- separate UI pages:
  - `http://localhost:8000/orders`
  - `http://localhost:8000/orders/new`
  - `http://localhost:8000/items`
- desktop launcher that starts the API automatically, shows logs, and can stop the API on exit
- item listing with pagination and filtering
- order placement
- order list with pagination and filtering
- order detail with paginated line items
- interactive API UI with Swagger and ReDoc

## API UI

- Home dashboard: `http://localhost:8000/`
- Orders page: `http://localhost:8000/orders`
- Create order page: `http://localhost:8000/orders/new`
- Items page: `http://localhost:8000/items`
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`
- OpenAPI JSON: `http://localhost:8000/openapi.json`

## Desktop Launcher

Double-click this file on macOS:

- `server_fastapi/launch_desktop.command`

Or run:

```bash
cd server_fastapi
python3 desktop_app.py
```

The desktop app will:

- let you enter the database host/IP, port, username, password, and database name
- save those values locally in `server_fastapi/.env`
- call `https://interlinkpos.com/sk_bags/isactive` on startup and store the result in the launcher
- block service startup and disable launcher controls if the licence response is `0`
- re-check the licence automatically on every API start or restart
- auto-start the FastAPI service on next open if saved DB settings already exist
- let you update the DB details and restart the API with `Reconnect`
- show live API logs
- show the running service address in the launcher with the started IP and port
- open the UI pages from buttons
- stop the API when you click `Stop API And Exit` or close the window

If SQL Server is not reachable, the launcher stays open and the logs will show the startup error so you can fix the server IP, port, database name, or credentials and use `Reconnect`.

## Windows EXE Build

This macOS machine cannot produce a native Windows `.exe` directly, but the project is now prepared for a Windows build.

### Build on Windows

1. Open Command Prompt in `server_fastapi`
2. Run:

```bat
build_windows.bat
```

Output:

- main executable: `server_fastapi\dist\SKBagsDesktop.exe`

### Build on GitHub Actions

If this repo is pushed to GitHub, run the workflow:

- `.github/workflows/build-windows-exe.yml`

It will build the Windows desktop package on `windows-latest` and upload it as an artifact.

## Assumptions

- `itemCode` comes from `Master1.Alias` when available
- fallback item code uses `MasterSupport.C1`, then `Master1.Code`
- `itemName` comes from `Master1.Name`
- `itemQuantity` comes from aggregated `Folio1.D1`
- item-level QR code is not available in the current database, so `qrCode` is returned as `null`
- orders are stored in:
  - `dbo.ApiOrders`
  - `dbo.ApiOrderItems`

## Setup

1. Copy `.env.example` to `.env`
2. Install dependencies

```bash
cd server_fastapi
python3 -m pip install -r requirements.txt
```

3. Start the API

```bash
cd server_fastapi
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Main Endpoints

- `GET /`
- `GET /health`
- `GET /api/items`
- `POST /api/orders`
- `GET /api/orders`
- `GET /api/orders/{order_id}`
