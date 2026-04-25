from __future__ import annotations

import argparse
import logging
import os
import queue
import shutil
import sys
import threading
import time
import urllib.error
import urllib.request
import webbrowser
from pathlib import Path

import tkinter as tk
from tkinter import scrolledtext, ttk

import uvicorn
from dotenv import dotenv_values


BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from app.config import settings
from app.db import assert_database_reachable_for_startup
from app.main import app
from app.runtime import env_example_path, env_path
from app.service import ensure_order_schema

try:
    import psutil
except ImportError:  # pragma: no cover
    psutil = None


APP_TITLE = "SK Bags Desktop"
LOCAL_HOST = "127.0.0.1"
SERVER_HOST = "0.0.0.0"
LICENSE_CHECK_URL = "https://interlinkpos.com/sk_bags/isactive"
LICENSE_CHECK_TIMEOUT = 6.0
LICENSE_IS_ACTIVE: bool | None = None
LICENSE_LAST_RESPONSE = ""


def _quote_env_value(value: str) -> str:
    if value == "":
        return '""'
    if any(character in value for character in [' ', '#', '"', "'", "\t"]):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    return value


def refresh_license_status() -> tuple[bool, str]:
    global LICENSE_IS_ACTIVE
    global LICENSE_LAST_RESPONSE

    request = urllib.request.Request(
        LICENSE_CHECK_URL,
        headers={"User-Agent": "SKBagsDesktop/1.0"},
    )

    try:
        with urllib.request.urlopen(request, timeout=LICENSE_CHECK_TIMEOUT) as response:
            raw_value = response.read().decode("utf-8", errors="ignore").strip()
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        LICENSE_IS_ACTIVE = False
        LICENSE_LAST_RESPONSE = ""
        return False, f"Could not verify licence status: {error}"

    LICENSE_LAST_RESPONSE = raw_value
    LICENSE_IS_ACTIVE = raw_value == "1"

    if raw_value == "1":
        return True, "Licence is active. Service startup is allowed."
    if raw_value == "0":
        return False, "Licence is expired. Contact to developer."
    return False, f"Unexpected licence response: {raw_value!r}. Contact to developer."


class LocalEnvStore:
    KEY_ORDER = [
        "PORT",
        "DB_HOST",
        "DB_PORT",
        "DB_USER",
        "DB_PASSWORD",
        "DB_NAME",
        "DB_TIMEOUT",
        "DB_STARTUP_TIMEOUT",
        "DEFAULT_PAGE_SIZE",
        "MAX_PAGE_SIZE",
        "DEBUG",
    ]

    CONFIG_KEYS = ["PORT", "DB_HOST", "DB_PORT", "DB_USER", "DB_PASSWORD", "DB_NAME"]

    def ensure_env_file(self) -> None:
        if env_path().exists() or not env_example_path().exists():
            return
        shutil.copyfile(env_example_path(), env_path())

    def load_values(self) -> dict[str, str]:
        values: dict[str, str] = {}

        if env_example_path().exists():
            values.update(self._read_env_file(env_example_path()))

        if env_path().exists():
            values.update(self._read_env_file(env_path()))

        return values

    def has_saved_connection(self) -> bool:
        if not env_path().exists():
            return False

        values = self.load_values()
        return all(values.get(key, "").strip() for key in ["DB_HOST", "DB_PORT", "DB_USER", "DB_NAME"])

    def save_connection(self, connection_values: dict[str, str]) -> None:
        values = self.load_values()
        values.update({key: value for key, value in connection_values.items() if key in self.CONFIG_KEYS})

        if "PORT" not in values:
            values["PORT"] = "8000"
        if "DB_TIMEOUT" not in values:
            values["DB_TIMEOUT"] = str(settings.db_timeout)
        if "DB_STARTUP_TIMEOUT" not in values:
            values["DB_STARTUP_TIMEOUT"] = str(settings.db_startup_timeout)
        if "DEFAULT_PAGE_SIZE" not in values:
            values["DEFAULT_PAGE_SIZE"] = str(settings.default_page_size)
        if "MAX_PAGE_SIZE" not in values:
            values["MAX_PAGE_SIZE"] = str(settings.max_page_size)

        lines: list[str] = []
        for key in self.KEY_ORDER:
            if key in values:
                lines.append(f"{key}={_quote_env_value(str(values[key]))}")

        for key in sorted(values.keys()):
            if key not in self.KEY_ORDER:
                lines.append(f"{key}={_quote_env_value(str(values[key]))}")

        env_path().write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _read_env_file(self, path: Path) -> dict[str, str]:
        raw_values = dotenv_values(path)
        return {key: "" if value is None else str(value) for key, value in raw_values.items()}


class QueueLogHandler(logging.Handler):
    def __init__(self, log_queue: "queue.Queue[str]") -> None:
        super().__init__()
        self.log_queue = log_queue

    def emit(self, record: logging.LogRecord) -> None:
        try:
            message = self.format(record)
        except Exception:
            message = record.getMessage()
        self.log_queue.put(message)


class ServerManager:
    def __init__(self, log_queue: "queue.Queue[str]") -> None:
        self.log_queue = log_queue
        self.server: uvicorn.Server | None = None
        self.server_thread: threading.Thread | None = None
        self.ready_event = threading.Event()
        self.stop_event = threading.Event()
        self.status = "Stopped"
        self._logger_setup = False

    @property
    def server_port(self) -> int:
        return settings.port

    @property
    def base_url(self) -> str:
        return f"http://{LOCAL_HOST}:{self.server_port}"

    @property
    def health_url(self) -> str:
        return f"{self.base_url}/health"

    def log(self, message: str) -> None:
        timestamp = time.strftime("%H:%M:%S")
        self.log_queue.put(f"[{timestamp}] {message}")

    def start(self) -> bool:
        if self.server_thread and self.server_thread.is_alive():
            self.log("API is already running.")
            return True

        self.log("Checking licence status.")
        is_active, message = refresh_license_status()
        self.log(message)

        if not is_active:
            self.status = "License Expired"
            return False

        settings.reload()
        self.stop_event.clear()
        self.ready_event.clear()
        self._setup_logging()

        if not settings.has_database_config():
            self.status = "Config Required"
            self.log("Database settings are incomplete. Save and reconnect from the desktop app.")
            return False

        if not self._preflight_database():
            self.status = "Error"
            return False

        if not self._handle_existing_listener():
            self.status = "Error"
            return False

        config = uvicorn.Config(
            app,
            host=SERVER_HOST,
            port=self.server_port,
            log_level="info",
            access_log=True,
            reload=False,
            workers=1,
            log_config=None,
            lifespan="on",
        )

        self.server = uvicorn.Server(config)
        self.server.install_signal_handlers = lambda: None
        self.server_thread = threading.Thread(target=self._run_server, name="skbags-api", daemon=True)
        self.server_thread.start()
        threading.Thread(target=self._wait_for_health, name="skbags-health", daemon=True).start()
        self.status = "Starting"
        self.log(
            f"Starting API service on {self.base_url} using "
            f"{settings.db_host}:{settings.db_port}/{settings.db_name}"
        )
        return True

    def stop(self, timeout: float = 8.0) -> None:
        if not self.server:
            self.status = "Stopped"
            return

        self.log("Stopping API service...")
        self.status = "Stopping"
        self.stop_event.set()
        self.server.should_exit = True

        if self.server_thread and self.server_thread.is_alive():
            self.server_thread.join(timeout=timeout)

        if self.server_thread and self.server_thread.is_alive():
            self.log("Graceful stop timed out. Forcing exit.")
            self.server.force_exit = True
            self.server_thread.join(timeout=2.0)

        self.server = None
        self.server_thread = None
        self.ready_event.clear()
        self.status = "Stopped"
        self.log("API service stopped.")

    def wait_until_ready(self, timeout: float = 20.0) -> bool:
        return self.ready_event.wait(timeout)

    def _run_server(self) -> None:
        try:
            assert self.server is not None
            self.server.run()
        except Exception as error:
            self.status = "Error"
            self.log(f"Server crashed: {error}")
        finally:
            if not self.stop_event.is_set() and self.status not in {"Error", "Stopped"}:
                self.status = "Stopped"
                self.log("API service exited.")

    def _wait_for_health(self) -> None:
        deadline = time.time() + 20
        while time.time() < deadline and not self.stop_event.is_set():
            if self._health_ok():
                self.ready_event.set()
                self.status = "Live"
                self.log(f"API is live at {self.base_url}")
                return
            time.sleep(0.35)

        if not self.stop_event.is_set() and self.status != "Live":
            self.status = "Error"
            self.log("API did not become healthy in time.")

    def _health_ok(self) -> bool:
        try:
            with urllib.request.urlopen(self.health_url, timeout=1.0) as response:
                return response.status == 200
        except (urllib.error.URLError, TimeoutError, OSError):
            return False

    def _setup_logging(self) -> None:
        if self._logger_setup:
            return

        formatter = logging.Formatter("%(asctime)s | %(name)s | %(message)s", "%H:%M:%S")
        handler = QueueLogHandler(self.log_queue)
        handler.setFormatter(formatter)

        for logger_name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
            logger = logging.getLogger(logger_name)
            logger.handlers = [handler]
            logger.setLevel(logging.INFO)
            logger.propagate = False

        self._logger_setup = True

    def _preflight_database(self) -> bool:
        try:
            self.log(
                f"Checking database connection for {settings.db_host}:{settings.db_port}/{settings.db_name}"
            )
            assert_database_reachable_for_startup()
            ensure_order_schema()
            self.log("Database connection check passed.")
            return True
        except Exception as error:
            self.log(str(error))
            return False

    def _handle_existing_listener(self) -> bool:
        if not self._is_port_open():
            return True

        command = self._find_uvicorn_command_by_port()
        if command:
            self.log(f"Stopping existing API process on port {self.server_port}: {command}")
            self._terminate_uvicorn_by_port()
            time.sleep(0.6)
            if not self._is_port_open():
                return True

        self.log(f"Port {self.server_port} is already in use by another process. Stop it before launching the desktop app.")
        return False

    def _is_port_open(self) -> bool:
        import socket

        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(0.3)
            return sock.connect_ex((LOCAL_HOST, self.server_port)) == 0

    def _find_uvicorn_command_by_port(self) -> str | None:
        if psutil is None:
            return None

        try:
            connections = psutil.net_connections(kind="inet")
        except Exception:
            return None

        for connection in connections:
            if not connection.laddr or connection.laddr.port != self.server_port:
                continue
            if connection.status != psutil.CONN_LISTEN or not connection.pid:
                continue

            try:
                process = psutil.Process(connection.pid)
                command = " ".join(process.cmdline())
            except Exception:
                continue

            if "uvicorn" in command and "app.main:app" in command:
                return command

        return None

    def _terminate_uvicorn_by_port(self) -> None:
        if psutil is None:
            return

        try:
            connections = psutil.net_connections(kind="inet")
        except Exception as error:
            self.log(f"Could not inspect running processes: {error}")
            return

        for connection in connections:
            if not connection.laddr or connection.laddr.port != self.server_port:
                continue
            if connection.status != psutil.CONN_LISTEN or not connection.pid:
                continue

            try:
                process = psutil.Process(connection.pid)
                command = " ".join(process.cmdline())
                if "uvicorn" not in command or "app.main:app" not in command:
                    continue
                process.terminate()
                try:
                    process.wait(timeout=4)
                except psutil.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=2)
                self.log(f"Stopped process PID {process.pid}.")
            except Exception as error:
                self.log(f"Could not stop existing API process: {error}")


class DesktopApp:
    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title(APP_TITLE)
        self._configure_window()

        self.log_queue: "queue.Queue[str]" = queue.Queue()
        self.env_store = LocalEnvStore()
        self.server_manager = ServerManager(self.log_queue)
        self.license_control_widgets: list[ttk.Widget] = []

        self.status_var = tk.StringVar(value="Preparing...")
        self.url_var = tk.StringVar(value=self.server_manager.base_url)
        self.service_bind_var = tk.StringVar(value="Not started")
        self.connection_note_var = tk.StringVar(value="")
        self.db_target_var = tk.StringVar(value="No saved database settings yet")
        self.api_toggle_text_var = tk.StringVar(value="Start API")

        self.service_port_var = tk.StringVar()
        self.db_host_var = tk.StringVar()
        self.db_port_var = tk.StringVar()
        self.db_user_var = tk.StringVar()
        self.db_password_var = tk.StringVar()
        self.db_name_var = tk.StringVar()

        self._load_connection_form()
        self._build_ui()
        self._check_license_status_on_start()
        self.root.protocol("WM_DELETE_WINDOW", self.stop_and_exit)
        self._maybe_autostart()
        self.root.after(120, self._drain_logs)
        self.root.after(350, self._refresh_status)

    def _configure_window(self) -> None:
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()

        preferred_width = min(1320, screen_width - 40)
        preferred_height = min(860, screen_height - 70)
        minimum_width = min(980, max(screen_width - 20, 760))
        minimum_height = min(680, max(screen_height - 20, 560))

        window_width = max(preferred_width, minimum_width)
        window_height = max(preferred_height, minimum_height)

        offset_x = max((screen_width - window_width) // 2, 10)
        offset_y = max((screen_height - window_height) // 2, 10)

        self.root.geometry(f"{window_width}x{window_height}+{offset_x}+{offset_y}")
        self.root.minsize(minimum_width, minimum_height)

    def _build_ui(self) -> None:
        colors = {
            "app_bg": "#0b1220",
            "hero_bg": "#111b31",
            "hero_accent": "#4fd1c5",
            "card_bg": "#f8fafc",
            "card_soft": "#eef6f6",
            "card_border": "#dbe5ef",
            "text": "#0f172a",
            "muted": "#64748b",
            "accent": "#0f766e",
            "accent_hover": "#115e59",
            "secondary_bg": "#e2e8f0",
            "secondary_hover": "#cbd5e1",
            "secondary_fg": "#1e293b",
            "danger": "#b91c1c",
            "danger_hover": "#991b1b",
            "status_live_bg": "#dcfce7",
            "status_live_fg": "#166534",
            "status_warm_bg": "#fef3c7",
            "status_warm_fg": "#92400e",
            "status_error_bg": "#fee2e2",
            "status_error_fg": "#991b1b",
            "status_neutral_bg": "#e2e8f0",
            "status_neutral_fg": "#334155",
            "log_bg": "#020617",
            "log_fg": "#e2e8f0",
        }
        self.colors = colors

        style = ttk.Style()
        style.theme_use("clam")

        self.root.configure(bg=colors["app_bg"])

        style.configure("App.TFrame", background=colors["app_bg"])
        style.configure("Hero.TFrame", background=colors["hero_bg"])
        style.configure("Card.TFrame", background=colors["card_bg"], relief="flat")
        style.configure("SoftCard.TFrame", background=colors["card_soft"], relief="flat")
        style.configure("SectionTitle.TLabel", background=colors["card_bg"], foreground=colors["text"], font=("Segoe UI", 15, "bold"))
        style.configure("SectionBody.TLabel", background=colors["card_bg"], foreground=colors["muted"], font=("Segoe UI", 9))
        style.configure("Eyebrow.TLabel", background=colors["hero_bg"], foreground=colors["hero_accent"], font=("Segoe UI", 10, "bold"))
        style.configure("HeroTitle.TLabel", background=colors["hero_bg"], foreground="#f8fafc", font=("Segoe UI", 21, "bold"))
        style.configure("HeroBody.TLabel", background=colors["hero_bg"], foreground="#cbd5e1", font=("Segoe UI", 10))
        style.configure("StatLabel.TLabel", background=colors["card_soft"], foreground=colors["muted"], font=("Segoe UI", 9, "bold"))
        style.configure("StatValue.TLabel", background=colors["card_soft"], foreground=colors["text"], font=("Segoe UI", 11, "bold"))
        style.configure("FieldLabel.TLabel", background=colors["card_bg"], foreground=colors["muted"], font=("Segoe UI", 9, "bold"))
        style.configure("Hint.TLabel", background=colors["card_bg"], foreground=colors["muted"], font=("Segoe UI", 9))
        style.configure("Footer.TLabel", background=colors["app_bg"], foreground="#94a3b8", font=("Segoe UI", 9))
        style.configure(
            "Field.TEntry",
            fieldbackground="#ffffff",
            foreground=colors["text"],
            bordercolor=colors["card_border"],
            lightcolor=colors["card_border"],
            darkcolor=colors["card_border"],
            insertcolor=colors["text"],
            padding=(8, 6),
        )
        style.map(
            "Field.TEntry",
            bordercolor=[("focus", colors["accent"])],
            lightcolor=[("focus", colors["accent"])],
            darkcolor=[("focus", colors["accent"])],
        )
        style.configure(
            "Primary.TButton",
            font=("Segoe UI", 9, "bold"),
            padding=(14, 8),
            background=colors["accent"],
            foreground="#f8fafc",
            borderwidth=0,
        )
        style.map(
            "Primary.TButton",
            background=[("active", colors["accent_hover"]), ("pressed", colors["accent_hover"])],
            foreground=[("disabled", "#cbd5e1")],
        )
        style.configure(
            "Secondary.TButton",
            font=("Segoe UI", 9, "bold"),
            padding=(12, 8),
            background=colors["secondary_bg"],
            foreground=colors["secondary_fg"],
            borderwidth=0,
        )
        style.map(
            "Secondary.TButton",
            background=[("active", colors["secondary_hover"]), ("pressed", colors["secondary_hover"])],
        )
        style.configure(
            "Danger.TButton",
            font=("Segoe UI", 9, "bold"),
            padding=(12, 8),
            background=colors["danger"],
            foreground="#fef2f2",
            borderwidth=0,
        )
        style.map(
            "Danger.TButton",
            background=[("active", colors["danger_hover"]), ("pressed", colors["danger_hover"])],
        )
        style.configure("InfoChip.TLabel", background=colors["secondary_bg"], foreground=colors["secondary_fg"], padding=(8, 5), font=("Segoe UI", 9, "bold"))
        style.configure("AccentChip.TLabel", background="#d1fae5", foreground=colors["accent"], padding=(8, 5), font=("Segoe UI", 9, "bold"))
        style.configure("StatusNeutral.TLabel", background=colors["status_neutral_bg"], foreground=colors["status_neutral_fg"], padding=(10, 6), font=("Segoe UI", 9, "bold"))
        style.configure("StatusLive.TLabel", background=colors["status_live_bg"], foreground=colors["status_live_fg"], padding=(10, 6), font=("Segoe UI", 9, "bold"))
        style.configure("StatusWarm.TLabel", background=colors["status_warm_bg"], foreground=colors["status_warm_fg"], padding=(10, 6), font=("Segoe UI", 9, "bold"))
        style.configure("StatusDanger.TLabel", background=colors["status_error_bg"], foreground=colors["status_error_fg"], padding=(10, 6), font=("Segoe UI", 9, "bold"))

        shell = ttk.Frame(self.root, padding=14, style="App.TFrame")
        shell.pack(fill="both", expand=True)
        shell.columnconfigure(0, weight=5, uniform="main")
        shell.columnconfigure(1, weight=7, uniform="main")
        shell.rowconfigure(1, weight=1)

        hero = ttk.Frame(shell, padding=14, style="Hero.TFrame")
        hero.grid(row=0, column=0, columnspan=2, sticky="nsew")
        hero.columnconfigure(0, weight=1)
        hero.columnconfigure(1, weight=0)

        hero_copy = ttk.Frame(hero, style="Hero.TFrame")
        hero_copy.grid(row=0, column=0, sticky="nsew", padx=(0, 18))

        ttk.Label(hero_copy, text="SERVICE CONTROL CENTER", style="Eyebrow.TLabel").pack(anchor="w")
        ttk.Label(hero_copy, text="SK Bags API Desktop", style="HeroTitle.TLabel").pack(anchor="w", pady=(6, 0))
        ttk.Label(
            hero_copy,
            text="Control the API, review logs, and update SQL Server details from one compact launcher.",
            style="HeroBody.TLabel",
            wraplength=420,
            justify="left",
        ).pack(anchor="w", pady=(6, 0))

        hero_stats = ttk.Frame(hero, style="Hero.TFrame")
        hero_stats.grid(row=0, column=1, sticky="nsew")
        for column in range(3):
            hero_stats.columnconfigure(column, weight=1)

        summary_cards = [
            ("Status", "status"),
            ("Local URL", "url"),
            ("Service Started At", "service"),
        ]

        for column, (label_text, key) in enumerate(summary_cards):
            stat = ttk.Frame(hero_stats, padding=10, style="SoftCard.TFrame")
            stat.grid(row=0, column=column, sticky="nsew", padx=(0 if column == 0 else 6, 0 if column == 2 else 6))
            ttk.Label(stat, text=label_text, style="StatLabel.TLabel").pack(anchor="w")
            if key == "status":
                self.status_chip_label = ttk.Label(stat, textvariable=self.status_var, style="StatusNeutral.TLabel")
                self.status_chip_label.pack(anchor="w", pady=(4, 0))
            elif key == "url":
                ttk.Label(stat, textvariable=self.url_var, style="StatValue.TLabel", wraplength=145).pack(anchor="w", pady=(4, 0))
            else:
                self.service_bind_label = ttk.Label(stat, textvariable=self.service_bind_var, style="InfoChip.TLabel", wraplength=145)
                self.service_bind_label.pack(anchor="w", pady=(4, 0))

        hero_button_row = ttk.Frame(hero, style="Hero.TFrame")
        hero_button_row.grid(row=1, column=0, columnspan=2, sticky="ew", pady=(12, 0))
        for column in range(2):
            hero_button_row.columnconfigure(column, weight=1)

        home_button = ttk.Button(
            hero_button_row,
            text="Open Home",
            style="Secondary.TButton",
            command=lambda: self._open("/"),
        )
        home_button.grid(row=0, column=0, sticky="ew", padx=(0, 6))
        self._register_license_widget(home_button)

        self.api_toggle_button = ttk.Button(
            hero_button_row,
            textvariable=self.api_toggle_text_var,
            style="Primary.TButton",
            command=self.toggle_server,
        )
        self.api_toggle_button.grid(row=0, column=1, sticky="ew", padx=(6, 0))

        left_column = ttk.Frame(shell, style="App.TFrame")
        left_column.grid(row=1, column=0, sticky="nsew", padx=(0, 12), pady=(12, 0))

        right_column = ttk.Frame(shell, style="App.TFrame")
        right_column.grid(row=1, column=1, sticky="nsew", pady=(12, 0))
        right_column.rowconfigure(1, weight=1)

        connection_card = ttk.Frame(left_column, padding=14, style="Card.TFrame")
        connection_card.pack(fill="both", expand=True)
        ttk.Label(connection_card, text="Service & Database Connection", style="SectionTitle.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(
            connection_card,
            text="Reconnect saves the service port and DB settings locally, then restarts the API.",
            style="SectionBody.TLabel",
            wraplength=320,
            justify="left",
        ).grid(row=1, column=0, sticky="w", pady=(4, 10))
        self.db_target_chip_label = ttk.Label(
            connection_card,
            textvariable=self.db_target_var,
            style="AccentChip.TLabel",
            wraplength=220,
            justify="center",
        )
        self.db_target_chip_label.grid(row=0, column=1, rowspan=2, sticky="e")

        form_grid = ttk.Frame(connection_card, style="Card.TFrame")
        form_grid.grid(row=2, column=0, columnspan=2, sticky="ew")
        form_grid.columnconfigure(0, weight=2)
        form_grid.columnconfigure(1, weight=1)
        form_grid.columnconfigure(2, weight=2)

        self._build_connection_field(form_grid, 0, 0, "Service Port", self.service_port_var, width=10)
        self._build_connection_field(form_grid, 0, 1, "DB Host / IP", self.db_host_var, width=16)
        self._build_connection_field(form_grid, 0, 2, "DB Port", self.db_port_var, width=9)
        self._build_connection_field(form_grid, 1, 0, "DB User", self.db_user_var, width=16)
        self._build_connection_field(form_grid, 1, 1, "DB Password", self.db_password_var, show="*", width=14)
        self._build_connection_field(form_grid, 1, 2, "Database Name", self.db_name_var, width=16)

        action_row = ttk.Frame(connection_card, style="Card.TFrame")
        action_row.grid(row=3, column=0, columnspan=2, sticky="ew", pady=(10, 0))
        load_button = ttk.Button(
            action_row,
            text="Load Saved",
            style="Secondary.TButton",
            command=self.load_saved_settings,
        )
        load_button.pack(side="left")
        self._register_license_widget(load_button)
        save_button = ttk.Button(
            action_row,
            text="Save",
            style="Secondary.TButton",
            command=self.save_form_values_locally,
        )
        save_button.pack(side="left", padx=(10, 0))
        self._register_license_widget(save_button)
        reconnect_button = ttk.Button(
            action_row,
            text="Reconnect",
            style="Primary.TButton",
            command=self.reconnect_with_form_values,
        )
        reconnect_button.pack(side="left", padx=(10, 0))
        self._register_license_widget(reconnect_button)

        self.connection_note_label = ttk.Label(
            connection_card,
            textvariable=self.connection_note_var,
            style="Hint.TLabel",
            wraplength=360,
            justify="left",
        )
        self.connection_note_label.grid(row=4, column=0, columnspan=2, sticky="w", pady=(8, 0))

        monitor_card = ttk.Frame(right_column, padding=14, style="Card.TFrame")
        monitor_card.grid(row=0, column=0, sticky="ew")
        ttk.Label(monitor_card, text="Service Monitor", style="SectionTitle.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(
            monitor_card,
            text="Keep the current endpoint and database target in view while the service runs.",
            style="SectionBody.TLabel",
            wraplength=500,
            justify="left",
        ).grid(row=1, column=0, sticky="w", pady=(4, 10))

        monitor_grid = ttk.Frame(monitor_card, style="Card.TFrame")
        monitor_grid.grid(row=2, column=0, sticky="ew")
        monitor_grid.columnconfigure(0, weight=1)
        monitor_grid.columnconfigure(1, weight=1)

        active_url_card = ttk.Frame(monitor_grid, padding=12, style="SoftCard.TFrame")
        active_url_card.grid(row=0, column=0, sticky="nsew", padx=(0, 8))
        ttk.Label(active_url_card, text="Active Endpoint", style="StatLabel.TLabel").pack(anchor="w")
        ttk.Label(active_url_card, textvariable=self.url_var, style="StatValue.TLabel", wraplength=220).pack(anchor="w", pady=(8, 0))

        target_db_card = ttk.Frame(monitor_grid, padding=12, style="SoftCard.TFrame")
        target_db_card.grid(row=0, column=1, sticky="nsew", padx=(8, 0))
        ttk.Label(target_db_card, text="Target Database", style="StatLabel.TLabel").pack(anchor="w")
        ttk.Label(target_db_card, textvariable=self.db_target_var, style="StatValue.TLabel", wraplength=220).pack(anchor="w", pady=(8, 0))

        ttk.Label(
            monitor_card,
            textvariable=self.connection_note_var,
            style="Hint.TLabel",
            wraplength=500,
            justify="left",
        ).grid(row=3, column=0, sticky="w", pady=(8, 0))

        log_card = ttk.Frame(right_column, padding=14, style="Card.TFrame")
        log_card.grid(row=1, column=0, sticky="nsew", pady=(12, 0))
        log_card.rowconfigure(1, weight=1)
        log_card.columnconfigure(0, weight=1)

        ttk.Label(log_card, text="Live Service Logs", style="SectionTitle.TLabel").grid(row=0, column=0, sticky="w")
        ttk.Label(
            log_card,
            text="Startup checks, reconnects, requests, and shutdown events stream here.",
            style="SectionBody.TLabel",
            wraplength=520,
            justify="left",
        ).grid(row=1, column=0, sticky="w", pady=(4, 8))

        self.log_output = scrolledtext.ScrolledText(
            log_card,
            wrap="word",
            bg=colors["log_bg"],
            fg=colors["log_fg"],
            insertbackground=colors["log_fg"],
            relief="flat",
            borderwidth=0,
            padx=12,
            pady=12,
            width=72,
            height=13,
            font=("Menlo", 10),
        )
        self.log_output.grid(row=2, column=0, sticky="nsew")
        self.log_output.configure(state="disabled")

        footer = ttk.Frame(shell, padding=(0, 8, 0, 0), style="App.TFrame")
        footer.grid(row=2, column=0, columnspan=2, sticky="ew")
        ttk.Label(
            footer,
            text="Saved DB settings auto-start the API when available.",
            style="Footer.TLabel",
        ).pack(side="left")

    def _build_connection_field(
        self,
        parent: ttk.Frame,
        row: int,
        column: int,
        label_text: str,
        variable: tk.StringVar,
        *,
        show: str | None = None,
        columnspan: int = 1,
        width: int = 16,
    ) -> None:
        field = ttk.Frame(parent, style="Card.TFrame")
        field.grid(
            row=row,
            column=column,
            columnspan=columnspan,
            sticky="ew",
            padx=(0, 8 if columnspan == 1 and column in {0, 1} else 0),
            pady=(0, 10 if row == 0 else 0),
        )
        ttk.Label(field, text=label_text, style="FieldLabel.TLabel").pack(anchor="w")
        entry_options: dict[str, object] = {"textvariable": variable, "style": "Field.TEntry", "width": width}
        if show is not None:
            entry_options["show"] = show
        entry = ttk.Entry(field, **entry_options)
        entry.pack(fill="x", pady=(6, 0))
        self._register_license_widget(entry)

    def _register_license_widget(self, widget: ttk.Widget) -> None:
        self.license_control_widgets.append(widget)

    def _set_license_controls_enabled(self, enabled: bool) -> None:
        for widget in self.license_control_widgets:
            try:
                if enabled:
                    widget.state(["!disabled"])
                else:
                    widget.state(["disabled"])
            except tk.TclError:
                continue

    def _status_style(self) -> str:
        status = self.server_manager.status
        if status == "Live":
            return "StatusLive.TLabel"
        if status in {"Starting", "Stopping"}:
            return "StatusWarm.TLabel"
        if status in {"Error", "Config Error", "License Expired"}:
            return "StatusDanger.TLabel"
        return "StatusNeutral.TLabel"

    def _check_license_status_on_start(self) -> None:
        self.server_manager.log("Checking licence status.")
        is_active, message = refresh_license_status()
        self.server_manager.log(message)

        if is_active:
            self._set_license_controls_enabled(True)
            self.connection_note_var.set("Licence verified. Service startup is enabled.")
            if self.server_manager.status == "License Expired":
                self.server_manager.status = "Stopped"
            return

        if self.server_manager.server_thread and self.server_manager.server_thread.is_alive():
            self.server_manager.log("Stopping API because the licence is expired.")
            self.server_manager.stop()

        self.server_manager.status = "License Expired"
        self.connection_note_var.set("Licence is expired. Contact to developer.")
        self.service_bind_var.set("Licence blocked")
        self._set_license_controls_enabled(False)

    def _load_connection_form(self) -> None:
        values = self.env_store.load_values()
        self.service_port_var.set(values.get("PORT", str(settings.port or 8000)))
        self.db_host_var.set(values.get("DB_HOST", settings.db_host))
        self.db_port_var.set(values.get("DB_PORT", str(settings.db_port)))
        self.db_user_var.set(values.get("DB_USER", settings.db_user))
        self.db_password_var.set(values.get("DB_PASSWORD", settings.db_password))
        self.db_name_var.set(values.get("DB_NAME", settings.db_name))
        self._apply_runtime_connection_values(self._collect_connection_values())
        self._update_connection_summary()

    def _update_connection_summary(self) -> None:
        host = self.db_host_var.get().strip() or "-"
        port = self.db_port_var.get().strip() or "-"
        database = self.db_name_var.get().strip() or "-"
        self.db_target_var.set(f"{host}:{port}\n{database}")

    def _apply_runtime_connection_values(self, values: dict[str, str]) -> None:
        for key in self.env_store.CONFIG_KEYS:
            os.environ[key] = values.get(key, "")
        settings.reload()
        self.url_var.set(self.server_manager.base_url)

    def _collect_connection_values(self) -> dict[str, str]:
        return {
            "PORT": self.service_port_var.get().strip() or "8000",
            "DB_HOST": self.db_host_var.get().strip(),
            "DB_PORT": self.db_port_var.get().strip(),
            "DB_USER": self.db_user_var.get().strip(),
            "DB_PASSWORD": self.db_password_var.get(),
            "DB_NAME": self.db_name_var.get().strip(),
        }

    def _validate_connection_values(self, values: dict[str, str]) -> None:
        if not values["PORT"]:
            raise ValueError("Service Port is required.")
        try:
            service_port = int(values["PORT"])
        except ValueError as error:
            raise ValueError("Service Port must be a number.") from error
        if service_port <= 0 or service_port > 65535:
            raise ValueError("Service Port must be a positive number.")
        if not values["DB_HOST"]:
            raise ValueError("DB Host / IP is required.")
        if not values["DB_PORT"]:
            raise ValueError("DB Port is required.")
        try:
            db_port = int(values["DB_PORT"])
        except ValueError as error:
            raise ValueError("DB Port must be a number.") from error
        if db_port <= 0 or db_port > 65535:
            raise ValueError("DB Port must be a positive number.")
        if not values["DB_USER"]:
            raise ValueError("DB User is required.")
        if not values["DB_NAME"]:
            raise ValueError("Database Name is required.")

    def _maybe_autostart(self) -> None:
        if LICENSE_IS_ACTIVE is not True:
            self.server_manager.status = "License Expired"
            self.connection_note_var.set("Licence is expired. Contact to developer.")
            self.server_manager.log("Service startup blocked because the licence is expired.")
            return

        if self.env_store.has_saved_connection():
            self.connection_note_var.set("Saved settings found. Starting automatically.")
            self.server_manager.log("Saved database settings detected. Starting API automatically.")
            self.server_manager.start()
        else:
            self.server_manager.status = "Config Required"
            self.connection_note_var.set("Enter DB settings and click Reconnect.")
            self.server_manager.log("No saved database settings found. Enter connection values and click Reconnect.")

    def load_saved_settings(self) -> None:
        if LICENSE_IS_ACTIVE is not True:
            self.server_manager.log("Load Saved is blocked because the licence is expired.")
            return
        self._load_connection_form()
        self.connection_note_var.set("Loaded saved settings from local .env.")
        self.server_manager.log("Loaded saved database settings into the form.")

    def save_form_values_locally(self) -> None:
        if LICENSE_IS_ACTIVE is not True:
            self.server_manager.log("Save is blocked because the licence is expired.")
            return

        try:
            values = self._collect_connection_values()
            self._validate_connection_values(values)
        except Exception as error:
            self.connection_note_var.set(str(error))
            self.server_manager.log(str(error))
            self.server_manager.status = "Config Error"
            return

        self.env_store.save_connection(values)
        self._apply_runtime_connection_values(values)
        self._update_connection_summary()
        self.connection_note_var.set("Saved locally. Current form values were stored in .env.")
        self.server_manager.log(
            f"Saved service port {settings.port} and database settings for "
            f"{settings.db_host}:{settings.db_port}/{settings.db_name} locally."
        )

    def start_server_only(self) -> None:
        if not self.env_store.has_saved_connection():
            self.connection_note_var.set("Enter DB settings and click Reconnect.")
            self.server_manager.status = "Config Required"
            self.server_manager.log("Start API is blocked until database settings are saved.")
            return

        self.connection_note_var.set("Starting API service...")
        if not self.server_manager.start() and LICENSE_IS_ACTIVE is not True:
            self.connection_note_var.set("Licence is expired. Contact to developer.")

    def toggle_server(self) -> None:
        is_running = bool(self.server_manager.server_thread and self.server_manager.server_thread.is_alive())
        if is_running or self.server_manager.status in {"Live", "Starting"}:
            self.stop_server_only()
            return

        self.start_server_only()

    def reconnect_with_form_values(self) -> None:
        try:
            values = self._collect_connection_values()
            self._validate_connection_values(values)
        except Exception as error:
            self.connection_note_var.set(str(error))
            self.server_manager.log(str(error))
            self.server_manager.status = "Config Error"
            return

        self.env_store.save_connection(values)
        self._apply_runtime_connection_values(values)
        self._update_connection_summary()
        self.connection_note_var.set("Saved locally. Reconnecting service...")
        self.server_manager.log(
            f"Saved service port {settings.port} and database settings for "
            f"{settings.db_host}:{settings.db_port}/{settings.db_name}. Reconnecting API."
        )
        self.server_manager.stop()
        time.sleep(0.4)
        if not self.server_manager.start() and LICENSE_IS_ACTIVE is not True:
            self.connection_note_var.set("Licence is expired. Contact to developer.")

    def stop_server_only(self) -> None:
        self.server_manager.stop()
        self.connection_note_var.set("API stopped. Click Reconnect to start again.")

    def _append_log(self, line: str) -> None:
        self.log_output.configure(state="normal")
        self.log_output.insert("end", line + "\n")
        self.log_output.see("end")
        self.log_output.configure(state="disabled")

    def _drain_logs(self) -> None:
        while True:
            try:
                line = self.log_queue.get_nowait()
            except queue.Empty:
                break
            self._append_log(line)

        self.root.after(120, self._drain_logs)

    def _refresh_status(self) -> None:
        self.status_var.set(self.server_manager.status)
        self.url_var.set(self.server_manager.base_url)

        self._set_license_controls_enabled(LICENSE_IS_ACTIVE is True)
        self._refresh_api_toggle_button()

        if self.server_manager.status == "Live":
            self.service_bind_var.set(self.server_manager.base_url)
            service_style = "AccentChip.TLabel"
        elif self.server_manager.status in {"Starting", "Stopping"}:
            self.service_bind_var.set("Starting...")
            service_style = "StatusWarm.TLabel"
        elif self.server_manager.status == "License Expired":
            self.service_bind_var.set("Licence blocked")
            service_style = "StatusDanger.TLabel"
        elif self.server_manager.status in {"Error", "Config Error"}:
            self.service_bind_var.set("Unavailable")
            service_style = "StatusDanger.TLabel"
        else:
            self.service_bind_var.set("Not started")
            service_style = "InfoChip.TLabel"

        self.status_chip_label.configure(style=self._status_style())
        self.service_bind_label.configure(style=service_style)
        self._update_connection_summary()
        self.root.after(350, self._refresh_status)

    def _refresh_api_toggle_button(self) -> None:
        status = self.server_manager.status
        if status in {"Live", "Starting"}:
            self.api_toggle_text_var.set("Stop API")
            self.api_toggle_button.configure(style="Danger.TButton")
            self.api_toggle_button.state(["!disabled"])
            return

        if status == "Stopping":
            self.api_toggle_text_var.set("Stopping...")
            self.api_toggle_button.configure(style="Danger.TButton")
            self.api_toggle_button.state(["disabled"])
            return

        self.api_toggle_text_var.set("Start API")
        self.api_toggle_button.configure(style="Primary.TButton")
        self.api_toggle_button.state(["!disabled"])

    def _open(self, path: str) -> None:
        if LICENSE_IS_ACTIVE is not True:
            self.server_manager.log("Open page action blocked because the licence is expired.")
            return
        webbrowser.open(f"{self.server_manager.base_url}{path}")

    def stop_and_exit(self) -> None:
        self.server_manager.stop()
        self.root.destroy()

    def run(self) -> None:
        self.root.mainloop()


def smoke_test() -> int:
    log_queue: "queue.Queue[str]" = queue.Queue()
    manager = ServerManager(log_queue)
    is_active, message = refresh_license_status()
    print(message)
    if not is_active:
        return 1
    manager.start()

    try:
        if not manager.wait_until_ready():
            print("Smoke test failed: API did not become ready in time.")
            while not log_queue.empty():
                print(log_queue.get())
            return 1

        print(f"Smoke test passed: {manager.base_url}")
        with urllib.request.urlopen(manager.health_url, timeout=2.0) as response:
            print(response.read().decode("utf-8"))
        return 0
    finally:
        manager.stop()
        while not log_queue.empty():
            print(log_queue.get())


def main() -> int:
    parser = argparse.ArgumentParser(description="SK Bags desktop launcher")
    parser.add_argument("--smoke-test", action="store_true", help="Start the API, verify health, then stop.")
    args = parser.parse_args()

    if args.smoke_test:
        return smoke_test()

    desktop = DesktopApp()
    desktop.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
