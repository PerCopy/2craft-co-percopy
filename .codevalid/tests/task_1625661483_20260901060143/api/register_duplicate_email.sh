#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Case: register_duplicate_email
# Verify POST /auth/register with an already-registered email returns HTTP 400
# with an appropriate error message and does not create a duplicate account.
# ---------------------------------------------------------------------------

## 0. Source shared infra environment
source .codevalid/_infra.sh
# APP_URL       -> http://app:3000
# DATABASE_URL  -> postgresql://app:app@toxiproxy:5432/appdb

echo "APP_URL      : $APP_URL"
echo "DATABASE_URL : $DATABASE_URL"

## 1. Seed – insert the pre-existing user
echo "--- Step 1: Seeding pre-existing user ---"
psql "$DATABASE_URL" -f .codevalid/mappings/cases/register_duplicate_email/seed.sql

# Capture baseline row count for the duplicate email
BEFORE_COUNT=$(psql "$DATABASE_URL" -tAc \
  "SELECT COUNT(*) FROM users WHERE email = 'duplicate@example.com';")
echo "Rows before request: $BEFORE_COUNT"
# Expected: 1
if [ "$BEFORE_COUNT" != "1" ]; then
  echo "FAIL: seed did not produce exactly 1 row; got $BEFORE_COUNT"
  exit 1
fi
echo "PASS: seed row confirmed (count = $BEFORE_COUNT)"

## 2. When – send duplicate-email registration request
echo "--- Step 2: Sending duplicate-email registration request ---"
RESPONSE=$(curl -s -w '
%{http_code}' \
  -X POST "$APP_URL/auth/register" \
  -H 'Content-Type: application/json' \
  -d '{"email":"duplicate@example.com","password":"Password1!","role":"BUYER"}')

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)

echo "Status : $HTTP_STATUS"
echo "Body   : $HTTP_BODY"

## 3. Then – assert HTTP 400 and error message
echo "--- Step 3: Assertions ---"

# 3a. Status code must be 400
if [ "$HTTP_STATUS" != "400" ]; then
  echo "FAIL: expected HTTP 400, got $HTTP_STATUS"
  exit 1
fi
echo "PASS: HTTP status is 400"

# 3b. Response body must contain an 'error' field
ERROR_FIELD=$(echo "$HTTP_BODY" | jq -r '.error // empty')
if [ -z "$ERROR_FIELD" ]; then
  echo "FAIL: response JSON has no 'error' field. Body: $HTTP_BODY"
  exit 1
fi
echo "PASS: 'error' field present: $ERROR_FIELD"

# 3c. Error message must reference the email already being in use
echo "$ERROR_FIELD" | grep -qi "already" || {
  echo "FAIL: error message does not indicate duplicate email. Got: $ERROR_FIELD"
  exit 1
}
echo "PASS: error message indicates email already in use"

# 3d. No additional row created – count must still be 1
AFTER_COUNT=$(psql "$DATABASE_URL" -tAc \
  "SELECT COUNT(*) FROM users WHERE email = 'duplicate@example.com';")
echo "Rows after request: $AFTER_COUNT"
if [ "$AFTER_COUNT" != "$BEFORE_COUNT" ]; then
  echo "FAIL: row count changed from $BEFORE_COUNT to $AFTER_COUNT — duplicate was created"
  exit 1
fi
echo "PASS: no duplicate row created (count remains $AFTER_COUNT)"

# 3e. Response must NOT contain a 'token' field
TOKEN_FIELD=$(echo "$HTTP_BODY" | jq -r '.token // empty')
if [ -n "$TOKEN_FIELD" ]; then
  echo "FAIL: response unexpectedly contains a token on duplicate-email error"
  exit 1
fi
echo "PASS: no token returned on duplicate-email error"

echo ""
echo "=== register_duplicate_email: ALL ASSERTIONS PASSED ==="

## 4. Teardown (optional isolation cleanup)
echo "--- Step 4: Teardown ---"
psql "$DATABASE_URL" -c \
  "DELETE FROM users WHERE email = 'duplicate@example.com';"
echo "Teardown complete."

echo "CODEVALID_TEST_ASSERTION_OK:register_duplicate_email"
