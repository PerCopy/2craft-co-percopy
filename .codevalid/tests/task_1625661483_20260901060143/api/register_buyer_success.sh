#!/usr/bin/env bash
set -euo pipefail

# Source shared infra (exports DATABASE_URL, APP_BASE_URL, etc.)
. .codevalid/_infra.sh

# ── Mappings ────────────────────────────────────────────────────────────────
TEST_EMAIL="buyer_success@example.com"
TEST_PASSWORD="Passw0rd!"
TEST_ROLE="BUYER"
# Use port 6713 as configured in docker-compose.yml (app container PORT=6713)
APP_BASE_URL="${APP_BASE_URL:-http://app:6713}"

# ── Seed: idempotent teardown ────────────────────────────────────────────────
echo "[SEED] Removing any pre-existing user with email $TEST_EMAIL..."
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  "DELETE FROM users WHERE email = 'buyer_success@example.com';"

# ── Seed: confirm clean state ────────────────────────────────────────────────
echo "[SEED] Confirming clean state..."
COUNT=$(psql "$DATABASE_URL" -tAc \
  "SELECT COUNT(*) FROM users WHERE email = 'buyer_success@example.com';")
[ "$COUNT" = "0" ] || { echo "SEED ERROR: user already exists (count=$COUNT)"; exit 1; }
echo "[SEED] Clean state confirmed."

# ── When: HTTP call ──────────────────────────────────────────────────────────
echo "[WHEN] POST $APP_BASE_URL/auth/register"
RESPONSE=$(curl -s -w '
%{http_code}' -X POST "$APP_BASE_URL/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"role\":\"$TEST_ROLE\"}")

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
echo "[WHEN] HTTP status: $HTTP_STATUS"
echo "[WHEN] HTTP body: $HTTP_BODY"

# ── Then: assertions ─────────────────────────────────────────────────────────

# 1. HTTP status is 201
echo "[THEN] Checking HTTP status is 201..."
[ "$HTTP_STATUS" = "201" ] || \
  { echo "FAIL: expected 201, got $HTTP_STATUS. Body: $HTTP_BODY"; exit 1; }
echo "[THEN] HTTP 201 OK"

# 2. Response body contains a non-empty token
echo "[THEN] Checking token is present..."
TOKEN=$(echo "$HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || { echo "FAIL: token missing or empty. Body: $HTTP_BODY"; exit 1; }
echo "TOKEN OK: ${TOKEN:0:20}..."

# 3. user.email matches submitted email
echo "[THEN] Checking user.email..."
RES_EMAIL=$(echo "$HTTP_BODY" | jq -r '.user.email // empty')
[ "$RES_EMAIL" = "$TEST_EMAIL" ] || \
  { echo "FAIL: user.email expected $TEST_EMAIL, got $RES_EMAIL"; exit 1; }
echo "[THEN] user.email OK: $RES_EMAIL"

# 4. user.role is BUYER
echo "[THEN] Checking user.role..."
RES_ROLE=$(echo "$HTTP_BODY" | jq -r '.user.role // empty')
[ "$RES_ROLE" = "BUYER" ] || \
  { echo "FAIL: user.role expected BUYER, got $RES_ROLE"; exit 1; }
echo "[THEN] user.role OK: $RES_ROLE"

# 5. user.status is ACTIVE
echo "[THEN] Checking user.status..."
RES_STATUS=$(echo "$HTTP_BODY" | jq -r '.user.status // empty')
[ "$RES_STATUS" = "ACTIVE" ] || \
  { echo "FAIL: user.status expected ACTIVE, got $RES_STATUS"; exit 1; }
echo "[THEN] user.status OK: $RES_STATUS"

# 6. user.id is non-empty
echo "[THEN] Checking user.id..."
RES_ID=$(echo "$HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$RES_ID" ] || { echo "FAIL: user.id is empty. Body: $HTTP_BODY"; exit 1; }
echo "[THEN] user.id OK: $RES_ID"

# 7. user.sellerProfile is null (BUYER has no seller profile)
echo "[THEN] Checking user.sellerProfile is null..."
RES_PROFILE=$(echo "$HTTP_BODY" | jq '.user.sellerProfile')
[ "$RES_PROFILE" = "null" ] || \
  { echo "FAIL: sellerProfile should be null, got $RES_PROFILE"; exit 1; }
echo "[THEN] user.sellerProfile OK: null"

# 8. Verify row persisted in database
echo "[THEN] Checking DB persistence..."
DB_ROW=$(psql "$DATABASE_URL" -tAc \
  "SELECT role || '|' || status FROM users WHERE email = 'buyer_success@example.com';")
[ "$DB_ROW" = "BUYER|ACTIVE" ] || \
  { echo "FAIL: DB row not as expected, got: $DB_ROW"; exit 1; }
echo "DB persistence OK: $DB_ROW"

# ── Teardown (idempotency) ────────────────────────────────────────────────────
echo "[TEARDOWN] Removing test user..."
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  "DELETE FROM users WHERE email = 'buyer_success@example.com';"
echo "Teardown complete"

# ── Pass ──────────────────────────────────────────────────────────────────────
echo "CODEVALID_TEST_ASSERTION_OK:register_buyer_success"
