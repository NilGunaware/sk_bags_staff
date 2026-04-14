from __future__ import annotations

import argparse
import logging
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


BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from app.config import settings
from app.main import app
from app.runtime import env_example_path, env_path

try:
    import psutil
except ImportError:  # pragma: no cover
    psutil = None


APP_TITLE = "SK Bags Desktop"
LOCAL_HOST = "127.0.0.1"
SERVER_HOST = "0.0.0.0"
SERVER_PORT = settings.port
HEALTH_URL = f"http://{LOCAL_HOST}:{SERVER_PORT}/health"


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
    def base_url(self) -> str:
        return f"http://{LOCAL_HOST}:{SERVER_PORT}"

    def log(self, message: str) -> None:
        timestamp = time.strftime("%H:%M:%S")
        self.log_queue.put(f"[{timestamp}] {message}")

    def ensure_env_file(self) -> None:
        writable_env_path = env_path()
        example_path = env_example_path()
        if writable_env_path.exists() or not example_path.exists():
            return

        shutil.copyfile(example_path, writable_env_path)
        self.log("Created .env from .env.example.")

    def start(self) -> None:
        if self.server_thread and self.server_thread.is_alive():
            self.log("API is already running.")
            return

        self.ensure_env_file()
        self.stop_event.clear()
        self.ready_event.clear()
        self._setup_logging()
        if not self._handle_existing_listener():
            self.status = "Error"
            return

        config = uvicorn.Config(
            app,
            host=SERVER_HOST,
            port=SERVER_PORT,
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
        self.log(f"Starting API service on {self.base_url}")

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
            with urllib.request.urlopen(HEALTH_URL, timeout=1.0) as response:
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

    def _handle_existing_listener(self) -> bool:
        if not self._is_port_open():
            return True

        command = self._find_uvicorn_command_by_port()
        if command:
            self.log(f"Stopping existing API process on port {SERVER_PORT}: {command}")
            self._terminate_uvicorn_by_port()
            time.sleep(0.6)
            if not self._is_port_open():
                return True

        self.log(f"Port {SERVER_PORT} is already in use by another process. Stop it before launching the desktop app.")
        return False

    def _is_port_open(self) -> bool:
        import socket

        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(0.3)
            return sock.connect_ex((LOCAL_HOST, SERVER_PORT)) == 0

    def _find_uvicorn_command_by_port(self) -> str | None:
        if psutil is None:
            return None

        try:
            connections = psutil.net_connections(kind="inet")
        except Exception:
            return None

        for connection in connections:
            if not connection.laddr or connection.laddr.port != SERVER_PORT:
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
            if not connection.laddr or connection.laddr.port != SERVER_PORT:
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
        self.root.geometry("1120x760")
        self.root.minsize(980, 640)
        self.root.configure(bg="#f4eadb")

        self.log_queue: "queue.Queue[str]" = queue.Queue()
        self.server_manager = ServerManager(self.log_queue)

        self.status_var = tk.StringVar(value="Starting...")
        self.url_var = tk.StringVar(value=self.server_manager.base_url)

        self._build_ui()
        self.root.protocol("WM_DELETE_WINDOW", self.stop_and_exit)
        self.server_manager.start()
        self.root.after(120, self._drain_logs)
        self.root.after(350, self._refresh_status)

    def _build_ui(self) -> None:
        style = ttk.Style()
        style.theme_use("clam")
        style.configure("Card.TFrame", background="#fffaf4")
        style.configure("Top.TFrame", background="#fffaf4")
        style.configure("TLabel", background="#fffaf4", foreground="#2b231d")
        style.configure("Muted.TLabel", background="#fffaf4", foreground="#6f6258")
        style.configure("Title.TLabel", background="#fffaf4", foreground="#2b231d", font=("Georgia", 22, "bold"))
        style.configure("Chip.TLabel", background="#f6dfc7", foreground="#8c431d", padding=8)
        style.configure("Primary.TButton", padding=(16, 10))
        style.configure("Secondary.TButton", padding=(14, 10))

        shell = ttk.Frame(self.root, padding=20, style="Top.TFrame")
        shell.pack(fill="both", expand=True)

        top_card = ttk.Frame(shell, padding=20, style="Card.TFrame")
        top_card.pack(fill="x")

        title = ttk.Label(top_card, text="SK Bags Desktop Launcher", style="Title.TLabel")
        title.grid(row=0, column=0, sticky="w")

        subtitle = ttk.Label(
            top_card,
            text="Starts the FastAPI service automatically, shows live logs, and lets you stop the API cleanly.",
            style="Muted.TLabel",
        )
        subtitle.grid(row=1, column=0, sticky="w", pady=(8, 14))

        meta_frame = ttk.Frame(top_card, style="Card.TFrame")
        meta_frame.grid(row=0, column=1, rowspan=2, sticky="e")

        ttk.Label(meta_frame, text="Status", style="Muted.TLabel").grid(row=0, column=0, sticky="e")
        ttk.Label(meta_frame, textvariable=self.status_var, style="Chip.TLabel").grid(row=1, column=0, sticky="e", pady=(4, 0))
        ttk.Label(meta_frame, text="Local URL", style="Muted.TLabel").grid(row=0, column=1, sticky="e", padx=(12, 0))
        ttk.Label(meta_frame, textvariable=self.url_var, style="Chip.TLabel").grid(row=1, column=1, sticky="e", padx=(12, 0), pady=(4, 0))

        button_row = ttk.Frame(top_card, style="Card.TFrame")
        button_row.grid(row=2, column=0, columnspan=2, sticky="ew", pady=(12, 0))

        ttk.Button(button_row, text="Open Home", style="Primary.TButton", command=lambda: self._open("/")).pack(side="left")
        ttk.Button(button_row, text="Open Orders", style="Secondary.TButton", command=lambda: self._open("/orders")).pack(side="left", padx=(10, 0))
        ttk.Button(button_row, text="Create Order", style="Secondary.TButton", command=lambda: self._open("/orders/new")).pack(side="left", padx=(10, 0))
        ttk.Button(button_row, text="Open Items", style="Secondary.TButton", command=lambda: self._open("/items")).pack(side="left", padx=(10, 0))
        ttk.Button(button_row, text="Swagger UI", style="Secondary.TButton", command=lambda: self._open("/docs")).pack(side="left", padx=(10, 0))
        ttk.Button(button_row, text="Restart API", style="Secondary.TButton", command=self.restart_server).pack(side="right")

        log_card = ttk.Frame(shell, padding=20, style="Card.TFrame")
        log_card.pack(fill="both", expand=True, pady=(18, 0))

        log_title = ttk.Label(log_card, text="Service Logs", style="Title.TLabel")
        log_title.pack(anchor="w")
        log_hint = ttk.Label(log_card, text="You can keep this window open to monitor startup, API requests, and shutdown events.", style="Muted.TLabel")
        log_hint.pack(anchor="w", pady=(6, 12))

        self.log_output = scrolledtext.ScrolledText(
            log_card,
            wrap="word",
            bg="#241f1a",
            fg="#f4eee7",
            insertbackground="#f4eee7",
            relief="flat",
            font=("Menlo", 11),
        )
        self.log_output.pack(fill="both", expand=True)
        self.log_output.configure(state="disabled")

        footer = ttk.Frame(shell, padding=(0, 16, 0, 0), style="Top.TFrame")
        footer.pack(fill="x")

        ttk.Label(
            footer,
            text="Stop API And Exit will shut down the service first, then close this desktop app.",
            style="Muted.TLabel",
        ).pack(side="left")
        ttk.Button(footer, text="Stop API And Exit", style="Primary.TButton", command=self.stop_and_exit).pack(side="right")

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
        self.root.after(350, self._refresh_status)

    def _open(self, path: str) -> None:
        webbrowser.open(f"{self.server_manager.base_url}{path}")

    def restart_server(self) -> None:
        self.server_manager.stop()
        time.sleep(0.4)
        self.server_manager.start()

    def stop_and_exit(self) -> None:
        self.server_manager.stop()
        self.root.destroy()

    def run(self) -> None:
        self.root.mainloop()


def smoke_test() -> int:
    log_queue: "queue.Queue[str]" = queue.Queue()
    manager = ServerManager(log_queue)
    manager.start()

    try:
        if not manager.wait_until_ready():
            print("Smoke test failed: API did not become ready in time.")
            while not log_queue.empty():
                print(log_queue.get())
            return 1

        print(f"Smoke test passed: {manager.base_url}")
        with urllib.request.urlopen(HEALTH_URL, timeout=2.0) as response:
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
