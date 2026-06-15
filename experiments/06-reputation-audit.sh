#!/bin/bash
# EXPERIMENT 6: Colony-Wide Reputation Audit — Cross-Reference
#
# Hypothesis: There are measurable correlations between:
# - PD cooperation rate and stock price premium
# - Betrayal rate and gift-giving (guilt-driven)
# - XP and auction bidding aggressiveness
#
# Run: bash experiments/06-reputation-audit.sh
# Requires: colony-games on 8823, colony-market on 8822, colony dir at COLONY

COLONY="${COLONY:-/home/ubuntu/.openclaw/workspace/colony}"
GAMES="${GAMES_URL:-http://localhost:8823}"
MARKET="${MARKET_URL:-http://localhost:8822}"

echo "============================================================"
echo "EXPERIMENT 6: Colony-Wide Reputation Audit"
echo "============================================================"

# Gather data from all three sources
echo ""
echo "--- Data sources ---"
echo "  Colony: $(ls -d "$COLONY"/cell-*/ 2>/dev/null | grep -v culled | wc -l) cells"
echo "  Games: $(curl -s "$GAMES/games/health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('games_lab','?'))" 2>/dev/null)"
echo "  Market: $(curl -s "$MARKET/market/health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('market_alive','?'))" 2>/dev/null)"
echo ""

# Step 1: Build cross-reference table
echo "╔════════════════════╦═══════╦══════════════╦═══════╦════════╦═══════╦════════╦═══════╗"
echo "║ Cell               ║ XP    ║ Level        ║ Coop% ║ Betray%║ Gifts ║ Bid XP║ Mkt $ ║"
echo "╠════════════════════╬═══════╬══════════════╬═══════╬════════╬═══════╬════════╬═══════╣"

for cell_dir in "$COLONY"/cell-*/; do
    cell_name=$(basename "$cell_dir" | sed 's/^cell-//')
    [ ! -f "$cell_dir/STATE.json" ] && continue

    XP=$(python3 -c "import json; print(json.load(open('$cell_dir/STATE.json')).get('xp',0))")
    LEVEL=$(python3 -c "import json; print(json.load(open('$cell_dir/STATE.json')).get('level','?'))")

    # Get reputation
    REP=$(curl -s "$GAMES/games/reputation?cell_id=$cell_name" 2>/dev/null)
    COOP=$(echo "$REP" | python3 -c "import sys,json; d=json.load(sys.stdin).get('reputation',{}); print(d.get('cooperate_rate',0))" 2>/dev/null)
    BETRAY=$(echo "$REP" | python3 -c "import sys,json; d=json.load(sys.stdin).get('reputation',{}); print(d.get('betray_rate',0))" 2>/dev/null)
    GIFT_GIVEN=$(echo "$REP" | python3 -c "import sys,json; d=json.load(sys.stdin).get('reputation',{}); print(d.get('gift_given_total_xp',0))" 2>/dev/null)
    BID_XP=$(echo "$REP" | python3 -c "import sys,json; d=json.load(sys.stdin).get('reputation',{}); print(d.get('total_bid_xp',0))" 2>/dev/null)

    # Get market data
    MKT=$(curl -s "$MARKET/market/price?ticker=$cell_name" 2>/dev/null)
    MKT_PRICE=$(echo "$MKT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('price_xp',0))" 2>/dev/null)

    COOP_PCT=$(echo "scale=0; $COOP * 100" | bc 2>/dev/null)
    [ -z "$COOP_PCT" ] && COOP_PCT="-"
    BETRAY_PCT=$(echo "scale=0; $BETRAY * 100" | bc 2>/dev/null)
    [ -z "$BETRAY_PCT" ] && BETRAY_PCT="-"

    printf "║ %-18s ║ %5d ║ %-12s ║ %5s ║ %6s ║ %5s ║ %6s ║ %5s ║\n" \
        "$cell_name" "$XP" "$LEVEL" "$COOP_PCT" "$BETRAY_PCT" "$GIFT_GIVEN" "$BID_XP" "$MKT_PRICE"
done

echo "╚════════════════════╩═══════╩══════════════╩═══════╩════════╩═══════╩════════╩═══════╝"

# Step 2: Correlations
echo ""
echo "--- Correlations ---"
echo ""

# Use python3 for proper stats
python3 << 'PYEOF'
import json, os, subprocess, sys

colony = os.environ.get('COLONY', '/home/ubuntu/.openclaw/workspace/colony')
games = os.environ.get('GAMES_URL', 'http://localhost:8823')
market = os.environ.get('MARKET_URL', 'http://localhost:8822')

import urllib.request

cells = []
for entry in os.listdir(colony):
    if entry.startswith('cell-') and not entry.startswith('cell-culled-'):
        cell_id = entry[5:]
        spath = os.path.join(colony, entry, 'STATE.json')
        if os.path.isfile(spath):
            with open(spath) as f:
                state = json.load(f)
            cells.append((cell_id, state))

# Get reputations
try:
    rep_data = json.loads(urllib.request.urlopen(f'{games}/games/reputation').read())
    reputations = rep_data.get('reputations', {})
except Exception as e:
    print(f'  Could not fetch reputation: {e}')
    reputations = {}

# Get market data
try:
    mkt_data = json.loads(urllib.request.urlopen(f'{market}/market/status').read())
    tickers = {t['ticker']: t for t in mkt_data.get('tickers', [])}
except Exception as e:
    print(f'  Could not fetch market: {e}')
    tickers = {}

# Build profile
profiles = []
for cid, state in cells:
    xp = state.get('xp', 0)
    rep = reputations.get(cid, {})
    ticker = tickers.get(cid, {})

    profiles.append({
        'cell_id': cid,
        'xp': xp,
        'level': state.get('level', '?'),
        'cooperate_rate': rep.get('cooperate_rate', 0),
        'betray_rate': rep.get('betray_rate', 0),
        'gifts_given': rep.get('gift_given_total_xp', 0),
        'gifts_received': rep.get('gift_received_total_xp', 0),
        'bid_xp': rep.get('total_bid_xp', 0),
        'market_price': ticker.get('price_xp', 0),
        'market_cap': ticker.get('market_cap', 0),
    })

# Correlations
cooperators = [p for p in profiles if p['cooperate_rate'] > 0]
defectors = [p for p in profiles if p['betray_rate'] > 0]

if cooperators:
    avg_coop_xp = sum(p['xp'] for p in cooperators) / len(cooperators)
    avg_coop_mkt = sum(p['market_price'] for p in cooperators) / len(cooperators)
    avg_coop_gifts = sum(p['gifts_given'] for p in cooperators) / len(cooperators)
    avg_coop_bids = sum(p['bid_xp'] for p in cooperators) / len(cooperators)
    print(f'  Cooperators (n={len(cooperators)}):')
    print(f'    Avg XP: {avg_coop_xp:.0f}')
    print(f'    Avg market price: {avg_coop_mkt:.0f}')
    print(f'    Avg gifts given: {avg_coop_gifts:.0f}')
    print(f'    Avg bid XP: {avg_coop_bids:.0f}')

if defectors:
    avg_def_xp = sum(p['xp'] for p in defectors) / len(defectors)
    avg_def_mkt = sum(p['market_price'] for p in defectors) / len(defectors)
    avg_def_gifts = sum(p['gifts_given'] for p in defectors) / len(defectors)
    avg_def_bids = sum(p['bid_xp'] for p in defectors) / len(defectors)
    print(f'  Defectors (n={len(defectors)}):')
    print(f'    Avg XP: {avg_def_xp:.0f}')
    print(f'    Avg market price: {avg_def_mkt:.0f}')
    print(f'    Avg gifts given: {avg_def_gifts:.0f}')
    print(f'    Avg bid XP: {avg_def_bids:.0f}')

if cooperators and defectors:
    print()
    ratio = avg_coop_xp / max(avg_def_xp, 1)
    print(f'  🔑 Cooperators out-earn defectors by {ratio:.1f}x XP')
    mkt_ratio = avg_coop_mkt / max(avg_def_mkt, 1)
    print(f'  🔑 Cooperators trade at {mkt_ratio:.1f}x market price')
    gift_ratio = avg_coop_gifts / max(avg_def_gifts, 1)
    print(f'  🔑 Cooperators gift {gift_ratio:.1f}x more XP')
    bid_ratio = avg_coop_bids / max(avg_def_bids, 1)
    print(f'  🔑 Cooperators bid {bid_ratio:.1f}x more in auctions')

# Givers vs non-givers
givers = [p for p in profiles if p['gifts_given'] > 0]
nongivers = [p for p in profiles if p['gifts_given'] == 0]
if givers and nongivers:
    avg_g_xp = sum(p['xp'] for p in givers) / len(givers)
    avg_ng_xp = sum(p['xp'] for p in nongivers) / len(nongivers)
    print(f'\n  Givers avg XP: {avg_g_xp:.0f} (n={len(givers)})')
    print(f'  Non-givers avg XP: {avg_ng_xp:.0f} (n={len(nongivers)})')
    print(f'  🔑 Givers have {avg_g_xp/max(avg_ng_xp,1):.1f}x more XP')

PYEOF

echo ""
echo "=== Observation ==="
echo "  Is there a cooperation premium in the market?"
echo "  Do defectors get lower prices from their own behavior?"
echo "  Does generosity correlate with wealth or innocence?"
echo ""
echo "  Run this audit after each game session to track changes."
