#!/bin/bash
# EXPERIMENT 2: Trust Auction — Information Valuation
#
# Hypothesis: Cells will bid more to see high-XP cells' private data.
# The value of a cell's secrets is proportional to their XP and level.
# Wealthy cells outbid poor cells for premium information.
#
# Run: bash experiments/02-trust-auction.sh
# Requires: colony-games service on port 8823, colony dir at COLONY

COLONY="${COLONY:-/home/ubuntu/.openclaw/workspace/colony}"
GAMES="${GAMES_URL:-http://localhost:8823}"

echo "============================================================"
echo "EXPERIMENT 2: Trust Auction — Information Valuation"
echo "============================================================"

# Step 1: Create auction
echo ""
echo "--- Creating auction ---"
AUCTION=$(curl -s -X POST "$GAMES/games/auction/create" -H 'Content-Type: application/json' -d '{}')
SUBJECT=$(echo "$AUCTION" | python3 -c "import sys,json; print(json.load(sys.stdin).get('subject','?'))")
SUBJECT_XP=$(python3 -c "import json; print(json.load(open('$COLONY/cell-$SUBJECT/STATE.json')).get('xp',0))" 2>/dev/null || echo "?")
SUBJECT_LEVEL=$(python3 -c "import json; print(json.load(open('$COLONY/cell-$SUBJECT/STATE.json')).get('level','?'))" 2>/dev/null || echo "?")
echo "  Subject: $SUBJECT (XP: $SUBJECT_XP, Level: $SUBJECT_LEVEL)"

# Step 2: Read the subject's state to assess their secrets
echo ""
echo "--- Subject's state ---"
python3 -c "
import json
state = json.load(open('$COLONY/cell-$SUBJECT/STATE.json'))
print(f'  Last run: {state.get(\"last_run\",\"?\")}')
print(f'  Cursor: {state.get(\"cursor\",0)}')
print(f'  Motto: {state.get(\"motto\",\"\")[:60]}')
print(f'  Personality: {state.get(\"personality\",\"?\")[:60]}')
print(f'  Lineage: {state.get(\"lineage\",[])}')
print(f'  Kin: {state.get(\"kin\",0)}')
print(f'  Traits: {state.get(\"traits\",None)}')
" 2>/dev/null || echo "  Could not read state"

# Step 3: Place bids from all wealthy cells
echo ""
echo "--- Placing bids ---"
for cell_dir in "$COLONY"/cell-*/; do
    cell_name=$(basename "$cell_dir" | sed 's/^cell-//')
    [ "$cell_name" = "$SUBJECT" ] && continue
    [ ! -f "$cell_dir/STATE.json" ] && continue

    XP=$(python3 -c "import json; print(json.load(open('$cell_dir/STATE.json')).get('xp',0))")
    # Bid 5-15% of XP, subject XP influences aggressiveness
    BID=$(( XP * (5 + RANDOM % 10) / 100 ))
    [ "$BID" -lt 5 ] && BID=0

    if [ "$BID" -ge 5 ]; then
        RESULT=$(curl -s -X POST "$GAMES/games/auction/bid" \
            -H 'Content-Type: application/json' \
            -d "{\"bidder\": \"$cell_name\", \"amount\": $BID}")
        STATUS=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','error'))")
        if [ "$STATUS" = "bid_placed" ]; then
            echo "  $cell_name bid $BID XP (has $XP XP) ✅"
        fi
    fi
done

# Step 4: Close auction
echo ""
echo "--- Closing auction ---"
RESULT=$(curl -s -X POST "$GAMES/games/auction/close" -H 'Content-Type: application/json' -d '{}')
echo "$RESULT" | python3 -c "
import sys, json
r = json.load(sys.stdin)
if r.get('status') == 'closed':
    print(f'  Winner: {r[\"winner\"]} ({r[\"winning_bid\"]} XP)')
    print(f'  Subject ({r[\"subject\"]}) earned {r[\"winning_bid\"]} XP')
    print(f'  Total bids: {r[\"total_bids\"]}')
elif r.get('status') == 'closed_no_bids':
    print(f'  No bids placed. Subject: {r[\"subject\"]}')
else:
    print(f'  Status: {r}')
"

# Step 5: Reveal the secrets (if any winner)
echo ""
echo "--- Revealed secrets ---"
SECRETS=$(curl -s -X POST "$GAMES/games/auction/reveal" -H 'Content-Type: application/json' -d '{}')
echo "$SECRETS" | python3 -c "
import sys, json
s = json.load(sys.stdin)
auction = s.get('auction', {})
if auction.get('status') == 'closed':
    print(f'  Subject: {s[\"cell_id\"]}')
    state = s.get('state', {})
    print(f'  State XP: {state.get(\"xp\",\"?\")}')
    print(f'  State level: {state.get(\"level\",\"?\")}')
    print(f'  State personality: {state.get(\"personality\",\"\")[:50]}')
    result = s.get('result', {})
    if result:
        print(f'  Last result status: {result.get(\"status\",\"?\")}')
        print(f'  Last result output: {str(result.get(\"output\",\"\"))[:60]}')
else:
    print('  No auction was won')
" 2>/dev/null || echo "  No secrets to reveal"

echo ""
echo "=== Observation ==="
echo "  Did wealthy cells outbid poor ones?"
echo "  Was the subject's XP correlated with the winning bid?"
echo "  Run multiple times and track bid/subject-XP ratio."
