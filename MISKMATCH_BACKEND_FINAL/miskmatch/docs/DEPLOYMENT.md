# MiskMatch — Deployment Guide

## Infrastructure Overview

```
                    ┌─────────────┐
                    │  CloudFlare  │  CDN + DDoS protection
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   AWS ALB   │  Application Load Balancer
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        ┌─────▼─────┐ ┌───▼───┐ ┌─────▼─────┐
        │  FastAPI   │ │  ...  │ │  FastAPI   │  ECS Fargate (4 workers each)
        │ Container  │ │       │ │ Container  │
        └─────┬──────┘ └───┬───┘ └─────┬──────┘
              │            │            │
     ┌────────┴────────────┴────────────┴────────┐
     │                                            │
┌────▼─────┐  ┌───────────┐  ┌──────────┐  ┌────▼────┐
│ Postgres │  │   Redis   │  │  Celery  │  │   S3    │
│  (RDS)   │  │ ElastiC.  │  │ Workers  │  │ + CFront│
└──────────┘  └───────────┘  └──────────┘  └─────────┘
```

---

## Prerequisites

- AWS account with ECS, RDS, ElastiCache, S3, CloudFront
- Domain: `miskmatch.app` with DNS on CloudFlare or Route 53
- Docker image pushed to ECR
- Third-party accounts: Twilio, OpenAI, Stripe, Agora, Onfido, Sentry, Firebase

---

## Step 1: Database (PostgreSQL on RDS)

```
Engine:         PostgreSQL 16
Instance:       db.t4g.medium (start), scale to db.r6g.large
Storage:        100 GB gp3, auto-scaling enabled
Multi-AZ:       Yes (production)
Region:         me-south-1 (Bahrain) — closest to MENA users
Backup:         7-day retention, daily snapshots
```

After creating the RDS instance:

```bash
# Run migrations against production database
DATABASE_URL=postgresql+asyncpg://user:pass@rds-endpoint:5432/miskmatch \
  alembic upgrade head
```

---

## Step 2: Redis (ElastiCache)

```
Engine:         Redis 7.x
Node:           cache.t4g.micro (start)
Cluster mode:   Disabled (single node is fine initially)
Region:         me-south-1
```

Used for: JWT blacklist, rate limiting, caching (profiles, discovery).

---

## Step 3: S3 + CloudFront

Create two S3 buckets in `me-south-1`:

| Bucket | Purpose | Public |
|---|---|---|
| `miskmatch-profiles` | Profile photos, gallery, voice | No (CloudFront) |
| `miskmatch-media` | Quran recitations, game media | No (CloudFront) |

Create a CloudFront distribution:
- Origin: S3 buckets (OAI/OAC)
- Cache policy: CachingOptimized
- HTTPS only
- Set `CLOUDFRONT_URL` in environment

---

## Step 4: Container (ECS Fargate)

### Build and push

```bash
# Build production image
docker build -t miskmatch-api .

# Tag and push to ECR
aws ecr get-login-password --region me-south-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.me-south-1.amazonaws.com
docker tag miskmatch-api:latest <account>.dkr.ecr.me-south-1.amazonaws.com/miskmatch-api:latest
docker push <account>.dkr.ecr.me-south-1.amazonaws.com/miskmatch-api:latest
```

### ECS Task Definition

```json
{
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [{
    "name": "miskmatch-api",
    "image": "<account>.dkr.ecr.me-south-1.amazonaws.com/miskmatch-api:latest",
    "portMappings": [{ "containerPort": 8000 }],
    "environment": [
      { "name": "ENVIRONMENT", "value": "production" }
    ],
    "secrets": [
      { "name": "SECRET_KEY", "valueFrom": "arn:aws:ssm:..." },
      { "name": "DATABASE_URL", "valueFrom": "arn:aws:ssm:..." }
    ],
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
      "interval": 30,
      "timeout": 5,
      "retries": 3
    }
  }]
}
```

### ECS Service

```
Desired count:  2 (minimum)
Auto-scaling:   Target tracking on CPU (60%) and request count
Min/Max:        2 / 10
Health check:   /health endpoint
```

---

## Step 5: Celery Workers

Deploy as a separate ECS service using the same Docker image but different command:

```bash
celery -A app.core.celery worker --loglevel=info --concurrency=4
```

For Celery Beat (scheduled tasks):

```bash
celery -A app.core.celery beat --loglevel=info
```

---

## Step 6: Environment Variables

Store all secrets in AWS Systems Manager Parameter Store or Secrets Manager.

**Required for production:**

```
ENVIRONMENT=production
SECRET_KEY=<random-64-char-string>
ADMIN_PASSWORD=<strong-password>

DATABASE_URL=postgresql+asyncpg://user:pass@rds-endpoint:5432/miskmatch
DATABASE_URL_SYNC=postgresql://user:pass@rds-endpoint:5432/miskmatch
REDIS_URL=redis://elasticache-endpoint:6379/0

TWILIO_ACCOUNT_SID=<sid>
TWILIO_AUTH_TOKEN=<token>
TWILIO_PHONE=<phone>

OPENAI_API_KEY=<key>

AWS_ACCESS_KEY_ID=<key>
AWS_SECRET_ACCESS_KEY=<secret>
AWS_REGION=me-south-1
S3_BUCKET_PROFILES=miskmatch-profiles
S3_BUCKET_MEDIA=miskmatch-media
CLOUDFRONT_URL=https://cdn.miskmatch.app

AGORA_APP_ID=<id>
AGORA_APP_CERT=<cert>

STRIPE_SECRET_KEY=<key>
STRIPE_WEBHOOK_SECRET=<secret>

ONFIDO_API_KEY=<key>
ONFIDO_WEBHOOK_SECRET=<secret>

FIREBASE_CREDENTIALS_PATH=/app/firebase-credentials.json

SENTRY_DSN=<dsn>

ALLOWED_HOSTS=["api.miskmatch.app"]
ALLOWED_ORIGINS=["https://miskmatch.app","https://admin.miskmatch.app"]
PRODUCTION_ORIGINS=https://miskmatch.app,https://admin.miskmatch.app
```

---

## Step 7: Load Balancer + SSL

### ALB Configuration

```
Listener:       443 (HTTPS) → Target Group (port 8000)
Certificate:    ACM cert for *.miskmatch.app
Health check:   GET /health, 200 OK, interval 30s
Stickiness:     Disabled (stateless JWT auth)
```

WebSocket support is built into ALB — no special config needed for `/api/v1/messages/ws/*` and `/api/v1/games/ws/*`.

---

## Step 8: DNS

```
api.miskmatch.app     → ALB DNS (CNAME or Alias)
cdn.miskmatch.app     → CloudFront distribution
```

---

## Step 9: Monitoring

### Sentry
- Set `SENTRY_DSN` in environment
- Captures all unhandled exceptions automatically
- Performance tracing enabled

### Health Check
- `GET /health` — returns API, database, and Redis status
- Use for ALB health checks and uptime monitoring

### Flower (Celery monitoring)
- Deploy as separate container on internal network
- Access via VPN or bastion host (not public)

---

## Scaling Guidelines

| Metric | Action |
|---|---|
| **100 users** | 1 API container, db.t4g.micro, cache.t4g.micro |
| **1,000 users** | 2 API containers, db.t4g.medium, 1 Celery worker |
| **10,000 users** | 4 API containers, db.r6g.large, 2 Celery workers, read replica |
| **100,000 users** | Auto-scaling (2-10), db.r6g.xlarge + read replicas, Redis cluster |

---

## Rollback

```bash
# ECS: roll back to previous task definition
aws ecs update-service --cluster miskmatch --service api --task-definition miskmatch-api:<previous-revision>

# Database: roll back one migration
DATABASE_URL=<prod-url> alembic downgrade -1
```

---

## Checklist Before Go-Live

- [ ] All environment variables set in production
- [ ] `SECRET_KEY` is unique, random, 64+ characters
- [ ] `ADMIN_PASSWORD` changed from default
- [ ] Database migrations applied (`alembic upgrade head`)
- [ ] SSL certificate active on ALB
- [ ] Twilio phone number configured and tested
- [ ] Stripe webhook endpoint registered (`/api/v1/webhooks/stripe`)
- [ ] Onfido webhook endpoint registered (`/api/v1/webhooks/onfido`)
- [ ] Firebase credentials file deployed
- [ ] Sentry DSN configured
- [ ] CloudFront distribution active
- [ ] Health check passing (`/health`)
- [ ] Rate limiting verified (Redis connected)
- [ ] CORS origins set for production domains
- [ ] Test login + OTP flow end-to-end
