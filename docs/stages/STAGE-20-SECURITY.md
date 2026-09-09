# STAGE 20 — SECURITY HARDENING SPECIFICATION

## Security Architecture

### 1. Storage & Hashing
- PIN hashes are derived using `SHA-256(salt:pin:salt)` with a high-entropy timestamp salt stored in `FlutterSecureStorage`.
- Constant-time XOR string comparison (`_constantTimeCompare`) is used to prevent side-channel timing attacks during verification.

### 2. Brute-Force Rate Limiting
- Tracked failed PIN attempts in `SecurityService`.
- 5 consecutive failures trigger an automated lockout delay:
  - 5th attempt: 30-second lockout.
  - 6th attempt: 60-second lockout.
  - Subsequent attempts increment exponentially.
- During active lockout, PIN verification immediately returns `false` without evaluating input.

### 3. Re-Authentication Guards
- Modifying or disabling security PIN/biometrics requires entering the current valid PIN.
- Data reset requires explicit confirmation dialog.
