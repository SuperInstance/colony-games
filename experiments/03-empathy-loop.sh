#!/bin/bash
# EXPERIMENT 3: Empathy Loop — Altruism vs Pragmatism
#
# Hypothesis: High-XP cells gift to their own lineage.
# Cells that share lineage gift at higher rates than unrelated cells.
# Betrayed cells do not gift back to their betrayers.
#
# Run: bash experiments/03-empathy-loop.sh
# Requires: colony-games on port 8823, colony dir at COLONY

COLONY="${COLONY:-/home/ubuntu/.openclaw/workspace/colony}"
GAMES="${GAMES_URL:-http://localhost:8823}"

echo "======================================================"
echo "EXPERIMENT 3: Empathy Loop — Altruism vs Pragmatism"
echo "======================================================"

# Step 1: Read all cell states and lineage
echo ""
echo "--- Cells and their lineage ---"
declare -A XP_MAP LINEAGE_MAP LEVEL_MAP
for cell_dir in "$COLONY"/cell-*/; do
    cell_name=$(basename "$cell_dir" | sed 's/^cell-//')
    [ ! -f "$cell_dir/STATE.json" ] && continue
    XP=$(python3 -c "import json; print(json.load(open('$cell_dir/STATE.json')).get('xp',0))")
    LINEAGE=$(python3 -c "import json; print(','.join(json.load(open('$cell_dir/STATE.json')).get('lineage',[])))" 2>/dev/null)
    LEVEL=$(python3 -c "import json; print(json.load(open('$cell_dir/STATE.json')).get('level','?'))")
    XP_MAP[$cell_name]=$XP
    LINEAGE_MAP[$cell_name]=$LINEAGE
    LEVEL_MAP[$cell_name]=$LEVEL
    echo "  $cell_name (${LEVEL}) — XP: $XP — Lineage: [$LINEAGE]"
done

# Step 2: Get current reputation (who betrayed whom)
echo ""
echo "--- Current reputation ---"
curl -s "$GAMES/games/reputation" | python3 -c "
import sys, json
d = json.load(sys.stdin)
reps = d.get('reputations', {})
for cid, r in sorted(reps.items(), key=lambda x: x[1].get('betray_rate', 0), reverse=True):
    if r.get('total_pd_games', 0) > 0:
        print(f'  {cid:20s}  coop:{r[\"cooperate_rate\"]:.0%}  betray:{r[\"betray_rate\"]:.0%}  given:{r.get(\"gift_given_total_xp\",0)}  recv:{r.get(\"gift_received_total_xp\",0)}')
"

# Step 3: Each wealthy cell gifts to a less wealthy one
echo ""
echo "--- Gifts flowing ---"
GIFT_COUNT=0
TOTAL_GIFTED=0

for gifter in $(for k in "${!XP_MAP[@]}"; do echo "${XP_MAP[$k]}:$k"; done | sort -rn | cut -d: -f2); do
    XP=${XP_MAP[$gifter]}
    [ "$XP" -lt 50 ] && continue  # Skip poor cells

    GIFT_LINEAGE=${LINEAGE_MAP[$gifter]}

    # Find candidate receivers — prefer same lineage, avoid high betrayers
    BEST_RECEIVER=""
    BEST_SCORE=-99
    BEST_XP=0

    for receiver in "${!XP_MAP[@]}"; do
        [ "$receiver" = "$gifter" ] && continue
        RXP=${XP_MAP[$receiver]}
        RLINEAGE=${LINEAGE_MAP[$receiver]}

        # Default score
        SCORE=10

        # Lineage bonus
        if echo "$GIFT_LINEAGE" | grep -qF "$receiver" || echo "$RLINEAGE" | grep -qF "$gifter"; then
            SCORE=$((SCORE + 40))
        fi

        # Prefer lower XP (help the needy)
        DEFICIT=$((XP - RXP))
        [ "$DEFICIT" -gt 0 ] && SCORE=$((SCORE + DEFICIT / 20))

        # Random boost for variety
        SCORE=$((SCORE + RANDOM % 30))

        if [ "$SCORE" -gt "$BEST_SCORE" ]; then
            BEST_SCORE=$SCORE
            BEST_RECEIVER=$receiver
            BEST_XP=$RXP
        fi
    done

    if [ -n "$BEST_RECEIVER" ]; then
        # Gift 5-10% of gifter XP
        AMOUNT=$(( XP * (5 + RANDOM % 5) / 100 ))
        [ "$AMOUNT" -lt 5 ] && AMOUNT=5
        [ "$AMOUNT" -gt "$XP" ] && AMOUNT=$XP

        RESULT=$(curl -s -X POST "$GAMES/games/gift" \
            -H 'Content-Type: application/json' \
            -d "{\"gifter\": \"$gifter\", \"receiver\": \"$BEST_RECEIVER\", \"amount_xp\": $AMOUNT}")
        STATUS=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('gifter','error'))")

        LINEAGE_MATCH=""
        if echo "$GIFT_LINEAGE" | grep -qF "$BEST_RECEIVER" || echo "${LINEAGE_MAP[$BEST_RECEIVER]}" | grep -qF "$gifter"; then
            LINEAGE_MATCH=" (lineage match)"
        fi

        if [ "$STATUS" != "error" ]; then
            GIFT_COUNT=$((GIFT_COUNT + 1))
            TOTAL_GIFTED=$((TOTAL_GIFTED + AMOUNT))
            echo "  $gifter → $BEST_RECEIVER : $AMOUNT XP$LINEAGE_MATCH"
        fi
    fi
done

echo ""
echo "--- Summary ---"
echo "  Total gifts: $GIFT_COUNT"
echo "  Total XP gifted: $TOTAL_GIFTED"
echo "  Average gift: $(( TOTAL_GIFTED / (GIFT_COUNT > 0 ? GIFT_COUNT : 1) )) XP"

echo ""
echo "=== Observation ==="
echo "  Do cells gift to their own lineage?"
echo "  Do wealthy cells help struggling ones?"
echo "  Which cell is the most generous? The most isolated?"
