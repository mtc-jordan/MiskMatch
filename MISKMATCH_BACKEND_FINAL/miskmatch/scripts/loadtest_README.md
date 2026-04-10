# MiskMatch Load Testing

Load test script for the MiskMatch API using [Locust](https://locust.io/).

## Prerequisites

1. Install locust:

```bash
pip install locust
```

2. Ensure the MiskMatch API is running locally:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

3. Ensure a test user exists in the database with these credentials:

- Phone: `+962791000001`
- Password: `Test1234!`

You can create one via `python scripts/seed.py` or by registering manually.

## Running the Load Test

### Web UI mode (recommended)

```bash
locust -f scripts/loadtest.py --host http://localhost:8000
```

Then open **http://localhost:8089** in your browser. Set the number of users and spawn rate, then start the test.

### Headless mode (CI / terminal)

```bash
locust -f scripts/loadtest.py \
    --host http://localhost:8000 \
    --headless \
    --users 50 \
    --spawn-rate 5 \
    --run-time 2m
```

### Export results to CSV

```bash
locust -f scripts/loadtest.py \
    --host http://localhost:8000 \
    --headless \
    --users 100 \
    --spawn-rate 10 \
    --run-time 5m \
    --csv results/loadtest
```

## Task Weights

| Task              | Weight | Description                     |
|-------------------|--------|---------------------------------|
| Discovery         | 5      | Browse the discovery feed       |
| Get profile       | 2      | View own profile                |
| Update profile    | 2      | Edit profile bio                |
| Send message      | 3      | Send a chat message             |
| Message history   | 3      | Fetch conversation history      |
| Express interest  | 1      | Express interest in a profile   |

## Customization

Edit `TEST_PHONE` and `TEST_PASSWORD` at the top of `loadtest.py` to use different credentials. For multi-user testing, subclass `MiskMatchUser` with different credentials or randomize from a list.
