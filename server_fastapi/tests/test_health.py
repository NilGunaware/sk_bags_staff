import unittest
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from app import health
from app.main import app
from app.schemas import HealthResponse


class HealthTests(unittest.TestCase):
    def setUp(self):
        health._checked_at = 0
        health._database_name = ""

    def test_readiness_is_cached_and_connection_closed(self):
        connection = MagicMock()
        with patch("app.health.get_connection", return_value=connection) as connect:
            first = health.health_snapshot()
            second = health.health_snapshot()
        self.assertTrue(first.databaseReady)
        self.assertEqual(second.status, "ok")
        connect.assert_called_once()
        connection.close.assert_called_once()

    def test_database_failure_keeps_api_available_as_degraded(self):
        with patch("app.health.get_connection", side_effect=RuntimeError("offline")):
            snapshot = health.health_snapshot()
        self.assertFalse(snapshot.databaseReady)
        self.assertEqual(snapshot.status, "degraded")

    def test_http_and_websocket_share_readiness_payload(self):
        snapshot = HealthResponse(status="degraded", database="test", version="test", databaseReady=False)
        with patch("app.main.health_snapshot", return_value=snapshot):
            client = TestClient(app)
            response = client.get("/health")
            self.assertEqual(response.status_code, 200)
            self.assertFalse(response.json()["databaseReady"])
            with client.websocket_connect("/ws/health") as socket:
                event = socket.receive_json()
                self.assertEqual(event["type"], "health")
                self.assertFalse(event["databaseReady"])
                self.assertEqual(event["status"], "degraded")


if __name__ == "__main__":
    unittest.main()
