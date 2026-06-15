#!/bin/bash
# EXPERIMENT 4: Rotating Oracle — Epochal Leadership
#
# Hypothesis: Cells vote for the cell that's given them the most.
# Wealthy cells have more vote power (sqrt-weighted), but young cells
# can accumulate influence by gifting. Leadership rotates if the top
# cell is stingy or betrays too often.
#
# Run: bash experiments/04-rotating-oracle.sh
# Requires: colony dir at COLONY

COLONY="${COLONY:-/home/ubuntu/.openclaw/workspace/colony}"

echo "==================================================="
echo "EXPERIMENT 4: Rotating Oracle — Epochal Leadership"
echo "==================================================="

# Step 1: Read all cells and their XP
echo ""
echo "--- Voter roll ---"
CELLS=()
declare -A XP_MAP LEVEL_MAP
for cell_dir in "$COLONY"/cell-*/; do
    cell_name=$(basename "$cell_dir" | sed 's/^cell-//')
    [ ! -f "$cell_dir/STATE.json" ] && continue
    XP=$(python3 -c "import json; print(json.load(open('$cell_dir/STATE.json')).get('xp',0))")
    LEVEL=$(python3 -c "import json; print(json.load(open('$cell_dir/STATE.json')).get('level','?'))")
    MOTTO=$(python3 -c "import json; print(json.load(open('$cell_dir/STATE.json')).get('motto','')[:40])")
    XP_MAP[$cell_name]=$XP
    LEVEL_MAP[$cell_name]=$LEVEL
    CELLS+=("$cell_name")
    echo "  $cell_name — $LEVEL (XP: $XP)"
    eval "MOTTO_${cell_name}='$MOTTO'"
done

TOTAL_CELLS=${#CELLS[@]}
echo "  Total voters: $TOTAL_CELLS"

# Step 2: Hold the vote
echo ""
echo "--- Voting ---"
echo "  Vote weight = sqrt(XP) per cell"
echo ""
declare -A VOTES VOTE_POWER
TOTAL_VOTE_POWER=0

for voter in "${CELLS[@]}"; do
    XP=${XP_MAP[$voter]}
    VOTE_WEIGHT=$(echo "scale=0; sqrt($XP)" | bc -l 2>/dev/null)
    [ -z "$VOTE_WEIGHT" ] && VOTE_WEIGHT=1
    [ "$VOTE_WEIGHT" -lt 1 ] && VOTE_WEIGHT=1

    # Weighted random vote: prefer high-XP cells (they have more to offer)
    # Pick a random cell not self
    CANDIDATES=()
    CANDIDATE_WEIGHTS=()
    for c in "${CELLS[@]}"; do
        [ "$c" = "$voter" ] && continue
        CANDIDATES+=("$c")
        # Candidate weight = sqrt(XP)
        CXP=${XP_MAP[$c]}
        CW=$(echo "scale=0; sqrt($CXP)" | bc -l 2>/dev/null)
        [ -z "$CW" ] && CW=1
        [ "$CW" -lt 1 ] && CW=1
        CANDIDATE_WEIGHTS+=("$CW")
    done

    # Weighted random selection
    TOTAL=$(
    IFS=+
    echo "$((${CANDIDATE_WEIGHTS[*]}))"
    )

    ROLL=$((RANDOM % TOTAL + 1))
    CUMULATIVE=0
    CHOSEN=${CANDIDATES[0]}
    for i in $(seq 0 $((${#CANDIDATES[@]} - 1))); do
        CUMULATIVE=$((CUMULATIVE + ${CANDIDATE_WEIGHTS[$i]}))
        if [ "$ROLL" -le "$CUMULATIVE" ]; then
            CHOSEN=${CANDIDATES[$i]}
            break
        fi
    done

    VOTES[$CHOSEN]=$((VOTES[$CHOSEN] + 1))
    VOTE_POWER[$CHOSEN]=$((VOTE_POWER[$CHOSEN] + VOTE_WEIGHT))
    TOTAL_VOTE_POWER=$((TOTAL_VOTE_POWER + VOTE_WEIGHT))
done

# Step 3: Report results
echo "--- Results ---"
echo ""
# Sort by raw votes
for candidate in "${!VOTES[@]}"; do
    echo "$candidate:${VOTES[$candidate]}:${VOTE_POWER[$candidate]}" 
done | sort -t: -k2 -rn | while IFS=: read -r CANDIDATE VOTE_COUNT POWER; do
    XP=${XP_MAP[$CANDIDATE]}
    LEVEL=${LEVEL_MAP[$CANDIDATE]}
    echo "  $CANDIDATE — ${VOTE_COUNT} votes (${POWER} weighted) — XP: $XP — $LEVEL"
done

echo ""
WINNER=$(for c in "${!VOTES[@]}"; do echo "${VOTES[$c]}:$c"; done | sort -rn | head -1 | cut -d: -f2)
WINNER_XP=${XP_MAP[$WINNER]}
WINNER_POWER=${VOTE_POWER[$WINNER]}
WINNER_VOTES=${VOTES[$WINNER]}

echo "---"
echo "  Winner: $WINNER ($WINNER_VOTES votes, $WINNER_POWER weighted, $WINNER_XP XP)"
echo "  Turnout: $TOTAL_CELLS voters, $TOTAL_VOTE_POWER total power"
echo ""

# Step 4: Write the oracle to a known state file
cat > "$COLONY/ORACLE.json" << OEOF
{
  "oracle": "$WINNER",
  "xp": $WINNER_XP,
  "votes": $WINNER_VOTES,
  "vote_power": $WINNER_POWER,
  "total_vote_power": $TOTAL_VOTE_POWER,
  "epoch": $(date +%s)
}
OEOF
echo "  Oracle recorded at $COLONY/ORACLE.json"

echo ""
echo "=== Observation ==="
echo "  Does the oracle rotate if the current #1 is stingy?"
echo "  Do gifting patterns predict votes?"
echo "  Run this multiple epochs and track oracle stability."
