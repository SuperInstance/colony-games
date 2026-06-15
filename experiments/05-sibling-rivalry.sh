#!/bin/bash
# EXPERIMENT 5: Sibling Rivalry Breeding — Hybrid Personality
#
# Hypothesis: Hybrid cells bred from combative parents will exhibit
# more aggressive PD behavior. The traits (speed, resilience) and
# personality are inherited with mutation — tracking them reveals
# whether conflict produces unstable or adaptive offspring.
#
# Run: bash experiments/05-sibling-rivalry.sh
# Requires: colony dir at COLONY, cell binary compiled

COLONY="${COLONY:-/home/ubuntu/.openclaw/workspace/colony}"
CELL_BINARY="${CELL_BINARY:-$COLONY/cell/target/release/cell}"

echo "================================================"
echo "EXPERIMENT 5: Sibling Rivalry Breeding"
echo "================================================"

# Step 1: Choose parents — top 2 by XP with different lineages
echo ""
echo "--- Parent selection ---"
CELLS=$(python3 -c "
import os, json
cells = []
for entry in os.listdir('$COLONY'):
    if entry.startswith('cell-') and not entry.startswith('cell-culled-'):
        state = json.load(open(f'$COLONY/{entry}/STATE.json'))
        cells.append((entry[5:], state))
cells.sort(key=lambda x: x[1].get('xp', 0), reverse=True)

# Find two with different lineages
for i in range(len(cells)):
    for j in range(i+1, len(cells)):
        c1 = cells[i]
        c2 = cells[j]
        l1 = c1[1].get('lineage', [])
        l2 = c2[1].get('lineage', [])
        # Check they're not from same lineage
        overlap = [p for p in l1 if p in l2 or p == c2[0]]
        if not overlap and c2[1].get('xp',0) > 100:
            print(f'{c1[0]}:{c2[0]}')
            exit(0)

print('could not find suitable pair', file=sys.stderr)
print('last resort:top2')
")

PARENT1="${CELLS%%:*}"
PARENT2="${CELLS##*:}"
echo "  Parent 1: $PARENT1"
python3 -c "import json; s=json.load(open('$COLONY/cell-$PARENT1/STATE.json')); print(f'    XP: {s[\"xp\"]}, Level: {s[\"level\"]}, Personality: {s[\"personality\"][:40]}')"
echo "  Parent 2: $PARENT2"
python3 -c "import json; s=json.load(open('$COLONY/cell-$PARENT2/STATE.json')); print(f'    XP: {s[\"xp\"]}, Level: {s[\"level\"]}, Personality: {s[\"personality\"][:40]}')"

# Step 2: Create the SPAWN_MANIFEST
echo ""
echo "--- Creating spawn manifest ---"
SPAWN_ID="hybrid-$(date +%s | tail -c 5)"
cat > "$COLONY/SPAWN_QUEUE.json" << EOF
{
  "id": "$SPAWN_ID",
  "parents": ["$PARENT1", "$PARENT2"],
  "reason": "sibling-rivalry-experiment",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
echo "  Spawn id: $SPAWN_ID"
echo "  Parents: $PARENT1 × $PARENT2"
echo "  Manifest: $COLONY/SPAWN_QUEUE.json"

# Step 3: If the cell binary is available, breed directly
echo ""
echo "--- Breeding ---"
if [ -x "$CELL_BINARY" ]; then
    # Calculate child properties (matching cell binary logic)
    P1_XP=$(python3 -c "import json; print(json.load(open('$COLONY/cell-$PARENT1/STATE.json')).get('xp',0))")
    P2_XP=$(python3 -c "import json; print(json.load(open('$COLONY/cell-$PARENT2/STATE.json')).get('xp',0))")
    CHILD_XP=$(( (P1_XP + P2_XP) / 20 ))
    echo "  Predicted child base XP: $CHILD_XP (($P1_XP + $P2_XP) / 20)"
    echo "  Lineage depth: $(( $(python3 -c "import json; print(len(json.load(open('$COLONY/cell-$PARENT1/STATE.json')).get('lineage',[])))") + 1 ))"

    # Run the cell binary in breed mode
    echo "  Running: $CELL_BINARY --colony $COLONY --cell-id hybrid --breed $PARENT1 $PARENT2"
    OUTPUT=$(cd "$COLONY" && "$CELL_BINARY" --colony "$COLONY" --cell-id "$SPAWN_ID" --breed "$PARENT1" "$PARENT2" 2>&1)
    echo "$OUTPUT" | head -5
    echo "  ... (output truncated)"
else
    echo "  WARNING: Cell binary not found at $CELL_BINARY"
    echo "  Compile first: cd $COLONY/cell && cargo build --release"
    echo "  Then re-run this experiment"
fi

# Step 4: Check if the hybrid was created
echo ""
echo "--- Checking for hybrid ---"
sleep 2
HYBRID_DIR="$COLONY/cell-$SPAWN_ID"
if [ -d "$HYBRID_DIR" ] && [ -f "$HYBRID_DIR/STATE.json" ]; then
    echo "  Hybrid created: cell-$SPAWN_ID"
    python3 -c "
import json
s = json.load(open('$HYBRID_DIR/STATE.json'))
print(f'  XP: {s[\"xp\"]}')
print(f'  Level: {s[\"level\"]}')
print(f'  Personality: {s[\"personality\"][:60]}')
print(f'  Motto: {s.get(\"motto\",\"\")[:60]}')
print(f'  Lineage: {s.get(\"lineage\",[])}')
print(f'  Traits: {s.get(\"traits\",\"?\")}')
"
else
    echo "  Hybrid not yet created. Mayor will pick up the spawn manifest."
    echo "  Check later: ls $COLONY/cell-$SPAWN_ID/"
fi

echo ""
echo "=== Observation ==="
echo "  Does the hybrid inherit parental traits?"
echo "  Is their personality more combative than average?"
echo "  Track their PD behavior in subsequent rounds."
