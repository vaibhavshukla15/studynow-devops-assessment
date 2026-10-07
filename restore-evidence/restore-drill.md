# StudyNow MongoDB Restore Drill
## Drill Date
2026-10-07
## Backup Used
studynow-20261007-061457.archive.gz.gpg
## Backup Security
- Backup encrypted using GPG AES-256.
- Encrypted backup stored in primary backup storage.
- Identical encrypted copy stored in offsite backup storage.
- SHA256 of primary and offsite backup:
447e16e04053c8cdcdc3117fb27bde16ed101f36dac94497cade90d035d42d3b
## Restore Procedure
1. Application containers were stopped.
2. The studynow database was destroyed.
3. Encrypted backup was decrypted using the backup passphrase.
4. Decrypted gzip archive passed integrity validation.
5. MongoDB backup was restored using mongorestore.
6. Application containers were started.
7. Application health endpoint was verified successfully.
## Database Destruction
Result: SUCCESS
The studynow database was destroyed before the restore drill.
## Backup Decryption
Result: SUCCESS
The encrypted GPG backup was successfully decrypted.
## Archive Validation
Result: SUCCESS
The decrypted gzip archive passed gzip -t validation.
## MongoDB Restore
Result: SUCCESS
Documents restored: 1
Documents failed: 0
Restored collection:
studynow.backup_test
## Restored Data Verification
The restored document was successfully verified:
- student: StudyNow Demo
- document: important-student-file
- createdAt: 2026-10-06T12:10:56.934Z
## RPO Verification
The rpo_test marker was created after the backup was completed.
Backup completion:
2026-10-07T06:14:57Z
RPO marker creation:
2026-10-07T06:18:32.355Z
Observed backup-to-marker interval:
Approximately 3 minutes 35 seconds
After restore:

rpo_test document count: 0
This demonstrates that data created after the selected backup was not present after restoration.
Target RPO:
1 hour
Observed drill window:
Approximately 3 minutes 35 seconds
## Application Verification
Health endpoint:
http://localhost:8080/health
Result:
{"status":"healthy","mongodb":"healthy","version":"1.0.0"}
Application status: HEALTHY
## Measured RTO
RTO start:
2026-10-07 12:09:23 PM
RTO end:
2026-10-07 12:19:54 PM
Measured RTO:
571.71 seconds
Approximately:
9 minutes 32 seconds
Target RTO:
4 hours
## Restore Status
SUCCESS
The database was destroyed, restored from the encrypted backup, verified, and the application was returned to a healthy state.
## Important RTO Qualification
The measured 9 minute 32 second RTO represents this local restore drill. It does not represent the complete production recovery time for a Linode regional failure, Cloudflare/DNS changes, infrastructure provisioning, or cross-region recovery.
## Security Note
Secrets and backup passphrases are not stored in this evidence file.



## Zero-Downtime Deployment Validation
- Deployment tested: Green to Blue
- Continuous health requests during deployment: 1,579
- Successful requests: 1,579
- Failed requests: 0
- Result: PASS
- This was validated locally using Docker Compose and NGINX; it does not represent a production Linode/Cloudflare failover test.
