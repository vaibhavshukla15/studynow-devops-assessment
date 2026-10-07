# StudyNow DevOps Assessment

Production-oriented DevOps implementation for the StudyNow assessment.

This project demonstrates containerization, MongoDB security, encrypted backups, restore testing, blue-green deployment, CI/CD, monitoring, and disaster-recovery planning.

---

## 1. Architecture

```text
Users
  |
  v
Cloudflare DNS / CDN
  |
  v
NGINX
  |
  +-------------------+
  |                   |
  v                   v
App Blue           App Green
(Node.js/Express)  (Node.js/Express)
  |                   |
  +---------+---------+
            |
            v
        MongoDB 7
            |
            v
     Persistent Volume

Backup Flow:
MongoDB
   |
mongodump + gzip
   |
GPG AES-256 encryption
   |
   +--> Primary backup storage
   |
   +--> Offsite backup storage
```

The local implementation uses Docker Compose and NGINX. Production deployment is designed for Linode/DigitalOcean infrastructure with Cloudflare in front.

---

## 2. Repository Structure

```text
studynow-devops-task/
|
+-- .github/
|   +-- workflows/
|       +-- ci-cd.yml
|       +-- backup.yml
|       +-- monitoring.yml
|
+-- app/
|   +-- Dockerfile
|   +-- package.json
|   +-- package-lock.json
|   +-- server.js
|   +-- server.test.js
|
+-- backup-tools/
|   +-- Dockerfile
|
+-- backups/
+-- backup-work/
+-- offsite-backup/
|
+-- mongo-init/
|   +-- 01-create-app-user.js
|
+-- nginx/
|   +-- nginx.conf
|
+-- restore-evidence/
|   +-- restore-drill.md
|
+-- scripts/
|   +-- backup.sh
|   +-- deploy.sh
|   +-- health-check.sh
|
+-- docker-compose.yml
+-- .gitignore
+-- README.md
```

Backup directories are intentionally ignored by Git because encrypted backup artifacts must not be committed to the repository.

---

## 3. Prerequisites

Required:

* Docker Desktop
* Docker Compose
* Git
* PowerShell or Git Bash
* Node.js 20+ for local application development
* GitHub repository for CI/CD

Production requirements:

* Linux server
* Docker
* GitHub Actions self-hosted runner
* Cloudflare DNS
* Offsite object storage or secondary backup host

---

## 4. Secrets and Environment Variables

Create a local `.env` file.

Example:

```env
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=<strong-secret>

MONGO_APP_DB=studynow
MONGO_APP_USER=studynow_app
MONGO_APP_PASSWORD=<strong-secret>

APP_VERSION=1.0.0
FORCE_UNHEALTHY=false

ALERT_WEBHOOK_URL=
ALERT_WEBHOOK_TYPE=slack

BACKUP_PASSPHRASE=<strong-secret>
```

Never commit `.env` to Git.

The following are ignored:

```text
.env
*.gpg
*.archive.gz
backups/
backup-work/
offsite-backup/
```

Production secrets should be stored in GitHub Actions Secrets or an appropriate secret-management system.

---

# 5. MongoDB Security

MongoDB runs with authentication enabled.

A separate application user is created:

```text
Database: studynow
User: studynow_app
Role: readWrite
```

The application does not use the MongoDB root account.

The root account is used only for administrative operations such as backup and recovery.

The application connects using:

```text
mongodb://studynow_app:<password>@mongo:27017/studynow?authSource=studynow
```

This follows the principle of least privilege.

---

# 6. Start the Application

From the project directory:

```powershell
docker compose up -d --build
```

Check containers:

```powershell
docker compose ps
```

Expected services:

```text
studynow-mongo
studynow-app-blue
studynow-app-green
studynow-nginx
```

---

# 7. Application Health Check

Open:

```text
http://localhost:8080/health
```

Or run:

```powershell
curl.exe http://localhost:8080/health
```

Expected response:

```json
{
  "status": "healthy",
  "mongodb": "healthy",
  "version": "1.0.0"
}
```

NGINX health endpoint:

```text
http://localhost:8080/nginx-health
```

---

# 8. CI Pipeline

GitHub Actions workflow:

```text
.github/workflows/ci-cd.yml
```

The CI pipeline runs on pushes and pull requests.

It performs:

1. Checkout
2. Node.js setup
3. npm install
4. Tests
5. Lint
6. Docker image build

Commands used locally:

```powershell
npm test
npm run lint
docker build -t studynow-app:ci-test .\app
```

The test currently verifies the application test suite successfully.

---

# 9. Blue-Green Deployment

Deployment script:

```text
scripts/deploy.sh
```

The deployment alternates between:

```text
Blue
Green
```

Deployment flow:

```text
Current environment
        |
        v
Build target environment
        |
        v
Start target container
        |
        v
Wait for health check
        |
        v
Validate NGINX configuration
        |
        v
Reload NGINX
        |
        v
Verify application health
        |
        v
Mark target as active
```

The inactive environment is kept available while the new environment is started and validated.

This reduces deployment downtime.

Run deployment from Git Bash:

```bash
./scripts/deploy.sh
```

On Windows PowerShell:

```powershell
$env:MSYS_NO_PATHCONV="1"
& "C:\Program Files\Git\bin\bash.exe" .\scripts\deploy.sh
```

The deployment script automatically selects the opposite environment.

---

# 10. Rollback

The deployment script contains rollback handling.

If the new environment fails its health check or NGINX validation:

1. The previous environment remains the active environment.
2. NGINX is switched back to the previous environment.
3. NGINX configuration is validated.
4. NGINX is reloaded.
5. Failed target environment is stopped.

Manual rollback concept:

```text
Blue active
   |
   v
Green deployment fails
   |
   v
Keep Blue active
   |
   v
Stop Green
```

The rollback design is intended to avoid unnecessary production downtime.

A formal live zero-dropped-request traffic test was not performed in the local assessment environment.

---

# 11. MongoDB Backup

Backup script:

```text
scripts/backup.sh
```

The backup process:

```text
MongoDB
   |
mongodump
   |
gzip archive
   |
gzip validation
   |
GPG AES-256 encryption
   |
   +--> Primary storage
   |
   +--> Offsite storage
```

Run:

```bash
./scripts/backup.sh
```

The script requires:

```text
MONGO_ROOT_USER
MONGO_ROOT_PASSWORD
BACKUP_PASSPHRASE
```

The plaintext archive is removed after encryption.

---

# 12. Backup Verification

Each backup is stored as:

```text
studynow-YYYYMMDD-HHMMSS.archive.gz.gpg
```

The assessment backup was encrypted using:

```text
GPG symmetric encryption
AES-256
```

The primary and offsite copies were verified using SHA-256.

The verified backup copies had matching SHA-256 hashes, proving that the two encrypted copies were identical.

---

# 13. Backup Scheduling

GitHub Actions workflow:

```text
.github/workflows/backup.yml
```

Schedule:

```text
Every hour
```

Cron:

```text
0 * * * *
```

The workflow creates `.env` from GitHub Actions Secrets and runs the encrypted backup script.

The scheduled workflow is designed for a self-hosted runner that has access to the MongoDB Docker container and backup storage.

---

# 14. Restore Drill

Restore evidence:

```text
restore-evidence/restore-drill.md
```

The restore drill performed the following:

1. Destroyed the MongoDB database.
2. Selected an encrypted backup.
3. Decrypted the backup.
4. Validated the gzip archive.
5. Restored MongoDB data.
6. Verified restored documents.
7. Started the application.
8. Verified the application health endpoint.

Restore result:

```text
Documents restored: 1
Documents failed:   0
```

Application health after restore:

```json
{
  "status": "healthy",
  "mongodb": "healthy",
  "version": "1.0.0"
}
```

---

# 15. Measured RTO

Restore drill timer:

```text
Start: 07 October 2026 12:09:23 PM
```

Measured restore time:

```text
571.71 seconds
```

Approximately:

```text
9 minutes 32 seconds
```

Therefore the measured local restore-drill RTO was:

```text
RTO = ~9m 32s
```

This is well below the assessment target of:

```text
RTO <= 4 hours
```

Important:

This is the measured local restore-drill RTO. It does not represent a complete Linode region failure recovery including Cloudflare/DNS changes.

---

# 16. Measured RPO

Assessment target:

```text
RPO <= 1 hour
```

During the restore drill, the observed backup/RPO marker window was approximately:

```text
3 minutes 35 seconds
```

The restored database did not contain the later test marker:

```text
rpo_test count: 0
```

Therefore the observed restore drill was within the required one-hour RPO target.

Production RPO depends on successful hourly scheduled backups and backup storage availability.

---

# 17. Monitoring

Monitoring script:

```text
scripts/health-check.sh
```

The script checks:

```text
http://localhost:8080/health
```

A healthy response is:

```text
HTTP 200
```

The monitoring workflow:

```text
.github/workflows/monitoring.yml
```

Schedule:

```text
Every 5 minutes
```

Cron:

```text
*/5 * * * *
```

If the health check fails, the script can send an alert using:

```text
Slack webhook
or
Discord webhook
```

Webhook URLs must be stored as GitHub Actions Secrets and must never be committed to the repository.

---

# 18. Production Deployment Model

Production architecture:

```text
Internet
   |
   v
Cloudflare
   |
   v
DNS / CDN / WAF
   |
   v
Linode / DigitalOcean
   |
   v
NGINX
   |
   +----------+
   |          |
   v          v
Blue       Green
App        App
   \          /
    \        /
     v      v
      MongoDB
```

The application server should not expose MongoDB publicly.

Only required HTTP/HTTPS ports should be exposed.

---

# 19. First Two Weeks: Audit and Lockdown

## Days 1-2

* Inventory all servers.
* Inventory DNS records.
* Inventory Cloudflare configuration.
* Inventory databases and uploaded documents.
* Identify production dependencies.
* Review current users and SSH keys.

## Days 3-4

* Disable unused accounts.
* Remove unused SSH keys.
* Enforce SSH key authentication.
* Disable unnecessary public services.
* Review firewall rules.

## Days 5-7

* Enable MongoDB authentication.
* Verify least-privilege database users.
* Review application secrets.
* Move secrets out of Git.
* Verify encrypted backup process.

## Week 2

* Test backup restoration.
* Configure monitoring.
* Configure alerting.
* Review Docker images.
* Patch operating system and packages.
* Document rollback procedures.
* Perform disaster-recovery exercise.

---

# 20. 3-2-1 Backup Strategy

The backup strategy follows the 3-2-1 principle:

```text
3 copies of important data
2 different storage locations/media
1 offsite copy
```

For MongoDB:

```text
Production MongoDB
        |
        +--> Primary encrypted backup
        |
        +--> Offsite encrypted backup
```

For uploaded student documents, production should additionally use durable object storage with versioning and an independent backup/replication copy.

The backup encryption key/passphrase must be stored separately from the backup files.

---

# 21. RPO 1 Hour Strategy

The production target is:

```text
RPO <= 1 hour
```

Therefore MongoDB backups are scheduled hourly.

If stronger protection is required, MongoDB replication/oplog-based recovery or continuous backup can reduce the practical RPO further.

The hourly backup workflow is the baseline implementation for this assessment.

---

# 22. RTO 4 Hour Strategy

Production recovery target:

```text
RTO <= 4 hours
```

Recovery sequence:

```text
1. Confirm incident
2. Check provider status
3. Confirm application/database availability
4. Activate secondary infrastructure if required
5. Restore MongoDB from latest valid backup
6. Start application containers
7. Validate application health
8. Validate NGINX
9. Update Cloudflare/DNS if required
10. Perform smoke tests
11. Monitor service
12. Record incident timeline
```

The restore drill demonstrated that the database restore itself can be completed substantially faster than four hours.

---

# 23. Linode Region Failure: First Four Hours

## 09:00 - Incident Detected

* Confirm the region failure.
* Check Linode/provider status.
* Confirm that the primary application is unavailable.
* Declare disaster-recovery incident.

## 09:15

* Activate secondary infrastructure.
* Provision/start application and database environment.
* Verify firewall and SSH access.

## 09:45

* Retrieve the latest valid encrypted MongoDB backup.
* Decrypt backup using the protected backup passphrase.
* Restore MongoDB.

## 10:30

* Start application containers.
* Start NGINX.
* Run health checks.
* Validate database connectivity.

## 11:00

* Update Cloudflare DNS or origin configuration if required.
* Lower/confirm DNS TTL strategy.
* Validate HTTPS.

## 11:30

* Perform application smoke tests.
* Validate login/API/database functionality.
* Check monitoring.

## 12:00

* Service should be operational.
* Continue monitoring.
* Document recovery timeline and remaining issues.

This sequence targets restoration within the required four-hour RTO.

---

# 24. Cloudflare / DNS Prevention

Recommended controls:

* Keep DNS hosted with Cloudflare.
* Use appropriate DNS TTL values.
* Keep secondary origin infrastructure documented.
* Maintain current origin IP information securely.
* Use Cloudflare health checks/load balancing where appropriate.
* Avoid hard-coding a single origin dependency in application configuration.
* Document DNS failover procedure.
* Test DNS failover periodically.
* Keep TLS certificates and origin configuration ready on the secondary environment.

---

# 25. Rough Monthly Cost

For a small production deployment, a rough planning estimate is:

```text
Compute / VM infrastructure:      ~$12-$24/month
Object/offsite backup storage:    ~$1-$5/month
Cloudflare DNS/basic services:    ~$0
GitHub Actions:                    ~$0 within applicable free usage
Monitoring/webhook:                ~$0
```

Approximate baseline:

```text
~$15-$30/month
```

Actual production cost depends on:

* VM size
* database size
* backup storage
* bandwidth
* object-storage retention
* Cloudflare features
* high-availability requirements

This is a rough assessment estimate, not a provider quotation.

---

# 26. Security Checklist

Before production:

* [x] `.env` excluded from Git
* [x] Backup files excluded from Git
* [x] GPG AES-256 backup encryption
* [x] MongoDB authentication enabled
* [x] Separate application database user
* [x] Application user uses least privilege
* [x] Docker application runs as non-root user
* [x] Health endpoint implemented
* [x] Docker healthcheck implemented
* [x] Blue-green deployment implemented
* [x] Rollback handling implemented
* [x] Restore drill completed
* [x] RTO measured
* [x] RPO tested
* [x] Monitoring workflow implemented
* [x] Backup workflow implemented
* [ ] Production GitHub self-hosted runner configured
* [ ] Production webhook secret configured
* [ ] Cloudflare production failover tested
* [ ] Secondary production region tested

---

# 27. Important Limitations

The following items are implemented as an assessment/local environment rather than a live production infrastructure:

* Local Docker Compose is used for testing.
* Linode/DigitalOcean infrastructure is not provisioned in this repository.
* Cloudflare production DNS failover was not executed locally.
* GitHub self-hosted runner configuration depends on the target GitHub repository/server.
* Slack/Discord webhook delivery requires a real webhook secret.
* The restore drill measured database/application recovery locally.
* A live zero-dropped-request production traffic test was not performed.

These limitations are intentionally documented rather than claiming tests that were not actually executed.

---

# 28. Evidence

Important evidence is stored in:

```text
restore-evidence/restore-drill.md
```

The evidence includes:

* Backup filename
* Backup encryption method
* SHA-256 verification
* Database destruction
* Backup decryption
* MongoDB restore
* Restored document verification
* Application health verification
* RTO measurement
* RPO observation

---

# 29. Quick Operations Reference

Start:

```bash
docker compose up -d --build
```

Status:

```bash
docker compose ps
```

Logs:

```bash
docker compose logs --tail=100
```

Health:

```bash
curl http://localhost:8080/health
```

Backup:

```bash
./scripts/backup.sh
```

Deployment:

```bash
./scripts/deploy.sh
```

Stop:

```bash
docker compose down
```

Stop and remove database volume:

```bash
docker compose down -v
```

---

# 30. Production 2 AM Site-Down Checklist

## Step 1 - Confirm

```text
Is the site actually down?
```

Check:

```text
Cloudflare
NGINX
Application
MongoDB
```

## Step 2 - Check health

```bash
curl -I https://your-domain.example
curl https://your-domain.example/health
```

## Step 3 - Check containers

```bash
docker compose ps
docker compose logs --tail=100
```

## Step 4 - Check MongoDB

Verify:

```text
MongoDB container
Authentication
Database connectivity
Disk space
```

## Step 5 - Check recent deployment

If the outage started immediately after deployment:

```text
Rollback to previous blue/green environment.
```

## Step 6 - Check backups

Confirm the latest encrypted backup exists and has a valid SHA-256 hash.

## Step 7 - Restore if required

Follow:

```text
restore-evidence/restore-drill.md
```

## Step 8 - Validate

Check:

```text
Application health
Database health
NGINX
HTTPS
Cloudflare
Critical application functionality
```

## Step 9 - Monitor

Continue monitoring after recovery.

## Step 10 - Document

Record:

```text
Incident start
Detection time
Actions taken
Restore time
RTO
Estimated RPO
Root cause
Corrective actions
```

---

# 31. Final Assessment Summary

The implementation provides:

```text
Containerized application
MongoDB authentication
Least-privilege application user
Encrypted MongoDB backups
Primary + offsite backup copies
Backup verification
Restore drill
Measured RTO
Measured RPO
Blue-green deployment
Rollback handling
CI/CD workflow
Scheduled backup workflow
Scheduled monitoring workflow
Operational runbook
Disaster-recovery plan
Security controls
```

Measured local restore-drill result:

```text
RTO: ~9m 32s
Target: <= 4 hours
```

Observed RPO window:

```text
~3m 35s
Target: <= 1 hour
```

The repository is designed so that another engineer can follow the documented deployment, backup, restore, monitoring, rollback, and disaster-recovery procedures.
