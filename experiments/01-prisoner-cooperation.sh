#!/bin/bash
# EXPERIMENT 1: Prisoner's Dilemma — Cooperation Cluster Formation
#
# Hypothesis: Cells that cooperate will continue cooperating.
# Cells that defect will continue defecting. After repeated rounds,
# cooperation clusters will form among like-behaving cells.
#
# Run: bash experiments/01-prisoner-cooperation.sh
# Requires: colony-games service on port 8823

GAMES="${GAMES_URL:-http://localhost:8823}"

echo "======================================================"
echo "EXPERIMENT 1: Prisoner's Dilemma — Cooperation Clusters"
echo "======================================================"

# Step 1: Get current reputation to seed strategy
echo ""
echo "--- Current reputation (before round) ---"
curl -s "$GAMES/games/reputation" | python3 -c "
import sys, json
d = json.load(sys.stdin)
reps = d.get('reputations', {})
for cid, r in sorted(reps.items(), key=lambda x: x[1].get('cooperate_rate', 0), reverse=True):
    print(f'  {cid:20s}  coop:{r.get(\"cooperate_rate\",0):.0%}  betray:{r.get(\"betray_rate\",0):.0%}  games:{r.get(\"total_pd_games\",0)}')
"

# Step 2: Generate new pairings
echo ""
echo "--- Pairing cells ---"
PAIRS=$(curl -s -X POST "$GAMES/games/pd/new-round" -H 'Content-Type: application/json' -d '{}')
echo "$PAIRS" | python3 -c "import sys,json; [print(f'  {p[\"cell1\"]} vs {p[\"cell2\"]}') for p in json.load(sys.stdin).get('pairs',[])]"

# Step 3: Play each pair with reputation-aware strategy
echo ""
echo "--- Playing round ---"
TOTAL_XP=0
echo "$PAIRS" | python3 -c "
import sys, json, urllib.request

games = '$GAMES'
pairs_data = json.load(sys.stdin)
reps = json.load(urllib.request.urlopen(f'{games}/games/reputation')).get('reputations', {})

for pair in pairs_data.get('pairs', []):
    c1, c2 = pair['cell1'], pair['cell2']
    r1 = reps.get(c1, {})
    r2 = reps.get(c2, {})

    # Strategy: cooperate if either has zero betrayal history
    move1 = 'cooperate' if r1.get('betray_rate', 0) == 0 else 'defect'
    move2 = 'cooperate' if r2.get('betray_rate', 0) == 0 else 'defect'

    body = json.dumps({'cell1': c1, 'move1': move1, 'cell2': c2, 'move2': move2}).encode()
    req = urllib.request.Request(f'{games}/games/pd/play', data=body,
        headers={'Content-Type': 'application/json'})
    try:
        resp = json.loads(urllib.request.urlopen(req).read())
        xp1 = resp.get('xp_awarded', {}).get(c1, 0)
        xp2 = resp.get('xp_awarded', {}).get(c2, 0)
        result = resp.get('result', '?')
        print(f'  {c1:20s} ({move1:10s})  vs  {c2:20s} ({move2:10s})  → {result:20s}  XP:{xp1}+{xp2}')
    except Exception as e:
        print(f'  {c1} vs {c2}: ERROR {e}')
"

# Step 4: Report summary
echo ""
echo "--- Summary ---"
curl -s "$GAMES/games/pd/summary" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  Total rounds: {d[\"total_rounds\"]}')
print(f'  Cooperation rate: {d[\"cooperation_rate\"]:.0%}')
print(f'  Betrayal rate: {d[\"betrayal_rate\"]:.0%}')
print(f'  Mutual cooperate: {d[\"mutual_cooperate\"]}')
print(f'  Mutual defect: {d[\"mutual_defect\"]}')
print(f'  Betrayals: {d[\"betrayals\"]}')
print()
print('  Top cooperators:')
for entry in d['cooperation_ranking'][:5]:
    print(f'    {entry[\"cell_id\"]:20s}  {entry[\"cooperate_rate\"]:.0%}  ({entry[\"total_pd_games\"]} games)')
"

echo ""
echo "=== Observation ==="
echo "  Do cells that cooperate keep cooperating?"
echo "  Do defectors face retaliation in later rounds?"
echo "  Run this protocol several times and watch for cluster formation."
