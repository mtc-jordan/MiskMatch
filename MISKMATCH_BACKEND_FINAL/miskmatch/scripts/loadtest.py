"""
MiskMatch — Locust Load Testing Script
"Sealed with musk." — Quran 83:26

Simulates realistic user traffic against the MiskMatch API.

Usage:
    locust -f scripts/loadtest.py --host http://localhost:8000
    # Then open http://localhost:8089 for the web UI.
"""

import random
import uuid

from locust import HttpUser, task, between, events


# ─────────────────────────────────────────────
# Test credentials — must exist in the database
# (create via seed.py or register manually)
# ─────────────────────────────────────────────
TEST_PHONE = "+962791000001"
TEST_PASSWORD = "Test1234!"

# Sample data for profile updates
PROFILE_BIOS = [
    "Seeking a partner who values deen above all.",
    "Looking for someone kind, honest, and family-oriented.",
    "Simple person with big dreams, seeking the same.",
    "Striving to be better every day, insha'Allah.",
    "Love hiking, reading, and long conversations.",
]

SAMPLE_MESSAGES = [
    "Assalamu alaikum, how are you?",
    "MashaAllah, your profile is impressive.",
    "What are your thoughts on living abroad?",
    "Do you have any questions for me?",
    "JazakAllah khair for your interest.",
    "What is most important to you in a spouse?",
    "How would you describe your relationship with your family?",
]

INTEREST_MESSAGES = [
    "Assalamu alaikum, I found your profile very interesting.",
    "MashaAllah, I would love to learn more about you.",
    "Salam, I believe we share similar values and goals.",
]


class MiskMatchUser(HttpUser):
    """
    Simulates a typical MiskMatch user session:
    login, browse discovery, view/update profile, interact with matches, and chat.
    """

    # Wait 1-5 seconds between tasks to simulate real browsing
    wait_time = between(1, 5)

    # Auth state
    token: str = ""
    user_id: str = ""
    discovered_user_ids: list = []
    match_ids: list = []

    # ─────────────────────────────────────────
    # Lifecycle
    # ─────────────────────────────────────────

    def on_start(self):
        """Login on virtual-user spawn and store the JWT."""
        self._login()

    def _auth_headers(self) -> dict:
        """Return Authorization header dict."""
        if not self.token:
            return {}
        return {"Authorization": f"Bearer {self.token}"}

    def _login(self):
        """Authenticate and store the access token."""
        with self.client.post(
            "/api/v1/auth/login",
            json={"phone": TEST_PHONE, "password": TEST_PASSWORD},
            name="/api/v1/auth/login",
            catch_response=True,
        ) as resp:
            if resp.status_code == 200:
                data = resp.json()
                self.token = data.get("access_token", "")
                self.user_id = data.get("user_id", "")
                if not self.token:
                    resp.failure("Login succeeded but no access_token in response")
            else:
                resp.failure(f"Login failed: {resp.status_code} — {resp.text[:200]}")

    # ─────────────────────────────────────────
    # Tasks — weighted by realistic usage
    # ─────────────────────────────────────────

    @task(5)
    def discover_profiles(self):
        """Browse the discovery feed — most common action."""
        with self.client.get(
            "/api/v1/matches/discover",
            headers=self._auth_headers(),
            name="/api/v1/matches/discover",
            catch_response=True,
        ) as resp:
            if resp.status_code == 200:
                data = resp.json()
                # Store discovered user IDs for later interest expressions
                if isinstance(data, list):
                    self.discovered_user_ids = [
                        p.get("user_id") or p.get("id") for p in data if p.get("user_id") or p.get("id")
                    ]
                elif isinstance(data, dict) and "results" in data:
                    self.discovered_user_ids = [
                        p.get("user_id") or p.get("id") for p in data["results"] if p.get("user_id") or p.get("id")
                    ]
                resp.success()
            elif resp.status_code == 401:
                resp.failure("Unauthorized — token may have expired")
                self._login()  # re-auth
            else:
                resp.failure(f"Discovery failed: {resp.status_code}")

    @task(2)
    def get_my_profile(self):
        """View own profile."""
        with self.client.get(
            "/api/v1/profiles/me",
            headers=self._auth_headers(),
            name="/api/v1/profiles/me [GET]",
            catch_response=True,
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            elif resp.status_code == 401:
                resp.failure("Unauthorized")
                self._login()
            else:
                resp.failure(f"Get profile failed: {resp.status_code}")

    @task(2)
    def update_profile(self):
        """Update own profile bio — simulates profile editing."""
        payload = {"bio": random.choice(PROFILE_BIOS)}
        with self.client.put(
            "/api/v1/profiles/me",
            json=payload,
            headers=self._auth_headers(),
            name="/api/v1/profiles/me [PUT]",
            catch_response=True,
        ) as resp:
            if resp.status_code in (200, 204):
                resp.success()
            elif resp.status_code == 401:
                resp.failure("Unauthorized")
                self._login()
            elif resp.status_code == 422:
                # Validation error — not a server failure
                resp.success()
            else:
                resp.failure(f"Update profile failed: {resp.status_code}")

    @task(1)
    def express_interest(self):
        """Express interest in a discovered profile."""
        if not self.discovered_user_ids:
            return  # nothing to express interest in yet

        receiver_id = random.choice(self.discovered_user_ids)
        payload = {
            "receiver_id": str(receiver_id),
            "message": random.choice(INTEREST_MESSAGES),
        }
        with self.client.post(
            "/api/v1/matches/interest",
            json=payload,
            headers=self._auth_headers(),
            name="/api/v1/matches/interest",
            catch_response=True,
        ) as resp:
            if resp.status_code in (200, 201):
                data = resp.json()
                match_id = data.get("match_id") or data.get("id")
                if match_id and match_id not in self.match_ids:
                    self.match_ids.append(match_id)
                resp.success()
            elif resp.status_code == 401:
                resp.failure("Unauthorized")
                self._login()
            elif resp.status_code in (409, 422):
                # Duplicate interest or validation error — expected under load
                resp.success()
            else:
                resp.failure(f"Express interest failed: {resp.status_code}")

    @task(3)
    def send_message(self):
        """Send a message in an existing match conversation."""
        if not self.match_ids:
            return  # no active matches to message in

        match_id = random.choice(self.match_ids)
        payload = {"content": random.choice(SAMPLE_MESSAGES)}
        with self.client.post(
            f"/api/v1/messages/{match_id}",
            json=payload,
            headers=self._auth_headers(),
            name="/api/v1/messages/{match_id} [POST]",
            catch_response=True,
        ) as resp:
            if resp.status_code in (200, 201):
                resp.success()
            elif resp.status_code == 401:
                resp.failure("Unauthorized")
                self._login()
            elif resp.status_code in (403, 404):
                # Match closed or not found — remove from list
                if match_id in self.match_ids:
                    self.match_ids.remove(match_id)
                resp.success()
            else:
                resp.failure(f"Send message failed: {resp.status_code}")

    @task(3)
    def get_message_history(self):
        """Fetch message history for a match."""
        if not self.match_ids:
            return

        match_id = random.choice(self.match_ids)
        with self.client.get(
            f"/api/v1/messages/{match_id}",
            headers=self._auth_headers(),
            name="/api/v1/messages/{match_id} [GET]",
            catch_response=True,
        ) as resp:
            if resp.status_code == 200:
                resp.success()
            elif resp.status_code == 401:
                resp.failure("Unauthorized")
                self._login()
            elif resp.status_code in (403, 404):
                if match_id in self.match_ids:
                    self.match_ids.remove(match_id)
                resp.success()
            else:
                resp.failure(f"Get messages failed: {resp.status_code}")


# ─────────────────────────────────────────────
# Event hooks for logging
# ─────────────────────────────────────────────

@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    print("=" * 60)
    print("  MiskMatch Load Test Starting")
    print(f"  Target host: {environment.host}")
    print("=" * 60)


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    print("=" * 60)
    print("  MiskMatch Load Test Complete")
    print("=" * 60)
