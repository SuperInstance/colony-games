#!/usr/bin/env python3
"""
Colony Experiment Protocol Library

Repeatable experiments that reveal agent psychology.
Each experiment is a self-contained protocol that can be
run against any colony of cells.

How to use:
    python3 protocol-prisoner-dilemma.py --colony /path/to/colony --games localhost:8823
    python3 protocol-trust-auction.py --colony /path/to/colony --games localhost:8823
    python3 protocol-sibling-rivalry.py --colony /path/to/colony
"""

import json
import os
import random
import sys
import time
import urllib.request
import urllib.error


# ── Shared Helpers ──────────────────────────────────────────────────────

def read_cell_state(colony, cell_id):
    """Read a cell's STATE.json."""
    path = os.path.join(colony, f"cell-{cell_id}", "STATE.json")
    if not os.path.isfile(path):
        return None
    with open(path) as f:
        return json.load(f)


def get_active_cells(colony):
    """Get all active (not culled) cell IDs with their state."""
    cells = {}
    for entry in os.listdir(colony):
        if entry.startswith("cell-") and not entry.startswith("cell-culled-"):
            cell_id = entry[5:]
            state_path = os.path.join(colony, entry, "STATE.json")
            if os.path.isfile(state_path):
                with open(state_path) as f:
                    cells[cell_id] = json.load(f)
    return cells


def post(url, data):
    """POST JSON to a service."""
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body,
        headers={"Content-Type": "application/json"})
    try:
        resp = urllib.request.urlopen(req)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}: {e.read().decode()}"}


def get(url):
    """GET from a service."""
    try:
        req = urllib.request.Request(url)
        resp = urllib.request.urlopen(req)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}: {e.read().decode()}"}


# ═══════════════════════════════════════════════════════════════════════════
# EXPERIMENT 1: Prisoner's Dilemma — Cooperation Cluster Formation
# ═══════════════════════════════════════════════════════════════════════════

def protocol_pd_cooperation_clusters(games_url="http://localhost:8823", rounds=3):
    """
    Hypothesis: Cells that cooperate will continue cooperating.
    Cells that defect will continue defecting.
    After repeated games, cooperation clusters will form.

    Protocol:
    1. Get active cells
    2. Generate random pairings each round
    3. Play each pair with moves determined by their reputation
    4. Track who cooperates, who defects, who changes strategy

    Run this multiple rounds to see if cells learn.
    """
    print("=" * 60)
    print("EXPERIMENT: Prisoner's Dilemma — Cooperation Clusters")
    print("=" * 60)

    summary_url = f"{games_url}/games/pd/summary"
    play_url = f"{games_url}/games/pd/play"

    # Get current reputation
    reputations = get(f"{games_url}/games/reputation").get("reputations", {})

    # Generate pairings
    pairs = post(f"{games_url}/games/pd/new-round", {})
    if "error" in pairs:
        print(f"  ERROR: {pairs['error']}")
        return pairs

    print(f"\n  Round with {pairs['total_pairs']} pairs")

    results = []
    for pair in pairs["pairs"]:
        c1, c2 = pair["cell1"], pair["cell2"]

        # Determine moves based on reputation
        # If either has betrayed before, retaliate by defecting
        # If both have clean records, cooperate
        r1 = reputations.get(c1, {})
        r2 = reputations.get(c2, {})

        move1 = "defect" if r1.get("betray_rate", 0) > 0.3 and r2.get("betray_rate", 0) > 0.5 else "cooperate"
        move2 = "cooperate"

        result = post(play_url, {"cell1": c1, "move1": move1, "cell2": c2, "move2": move2})
        results.append(result)

        xp1 = result.get("xp_awarded", {}).get(c1, 0)
        xp2 = result.get("xp_awarded", {}).get(c2, 0)
        print(f"  {c1:20s} ({move1:10s})  vs  {c2:20s} ({move2:10s})  →  {result['result']:20s}  XP:{xp1}+{xp2}")

    # Summary
    summary = get(summary_url)
    print(f"\n  Total rounds played: {summary['total_rounds']}")
    print(f"  Cooperation rate: {summary['cooperation_rate']:.0%}")
    print(f"  Betrayal rate: {summary['betrayal_rate']:.0%}")

    # Top cooperators
    print("\n  Cooperation Ranking:")
    for entry in summary["cooperation_ranking"]:
        print(f"    {entry['cell_id']:20s}  {entry['cooperate_rate']:.0%}  ({entry['total_pd_games']} games)")

    return results


# ═══════════════════════════════════════════════════════════════════════════
# EXPERIMENT 2: Trust Auction — Information Valuation
# ═══════════════════════════════════════════════════════════════════════════

def protocol_trust_auction(colony, games_url="http://localhost:8823"):
    """
    Hypothesis: Cells will bid more to see high-XP cells' private data.
    The value of a cell's secrets is proportional to their XP.

    Protocol:
    1. Create an auction
    2. Read the subject cell's XP and level
    3. Place escalating bids from wealthy cells
    4. Close auction and record winner
    5. Reveal the secrets
    6. Compare winning bid to subject's XP
    """
    print("\n" + "=" * 60)
    print("EXPERIMENT: Trust Auction — Information Valuation")
    print("=" * 60)

    # Create auction
    auction = post(f"{games_url}/games/auction/create", {})
    if "error" in auction:
        print(f"  ERROR: {auction['error']}")
        return auction

    subject = auction["subject"]
    subject_state = read_cell_state(colony, subject)
    subject_xp = subject_state.get("xp", 0) if subject_state else 0
    subject_level = subject_state.get("level", "?") if subject_state else "?"

    print(f"\n  Subject: {subject} (XP: {subject_xp}, Level: {subject_level})")

    # Place bids — wealthy cells bid more
    cells = get_active_cells(colony)
    bids = []
    for cell_id in sorted(cells.keys(), key=lambda c: cells[c].get("xp", 0), reverse=True):
        if cell_id == subject:
            continue
        xp = cells[cell_id].get("xp", 0)

        # Bid a percentage of XP, proportional to subject's value
        bid_amount = max(5, int(xp * 0.1)) if xp > 0 else 0
        bid_amount = min(bid_amount, 200)  # Cap at 200

        result = post(f"{games_url}/games/auction/bid",
                      {"bidder": cell_id, "amount": bid_amount})
        if "error" not in result:
            bids.append((cell_id, bid_amount))
            print(f"  {cell_id:20s} bid {bid_amount:4d} XP  (has {xp:4d} XP)")

    # Close auction
    result = post(f"{games_url}/games/auction/close", {})
    print(f"\n  Winner: {result.get('winner')} ({result.get('winning_bid')} XP)")
    print(f"  Subject earned: {result.get('winning_bid')} XP → new total: {result.get('subject_new_xp')}")
    print(f"  Ratio (bid / subject XP): {result.get('winning_bid', 0) / max(subject_xp, 1):.2f}x")

    # Reveal
    secrets = post(f"{games_url}/games/auction/reveal", {})
    print(f"\n  Secrets revealed: {secrets.get('cell_id')}")

    return result


# ═══════════════════════════════════════════════════════════════════════════
# EXPERIMENT 3: Empathy Loop — Altruism vs Pragmatism
# ═══════════════════════════════════════════════════════════════════════════

def protocol_empathy_loop(colony, games_url="http://localhost:8823"):
    """
    Hypothesis: High-XP cells will gift more to their own lineage.
    Cells will gift to cells they've invested in (via market).
    No cell will gift to a cell that betrayed them.

    Protocol:
    1. Read all cells' states, lineage, and current reputation
    2. Have each cell decide who to gift based on:
       - Same lineage → 70% probability
       - Different lineage, non-aggressor → 20% probability
       - Betrayer in PD → 0% probability
    3. Record all gifts
    4. Analyze: do gifts follow lineage or reputation?
    """
    print("\n" + "=" * 60)
    print("EXPERIMENT: Empathy Loop — Altruism vs Pragmatism")
    print("=" * 60)

    cells = get_active_cells(colony)
    reputations = get(f"{games_url}/games/reputation").get("reputations", {})
    gift_url = f"{games_url}/games/gift"

    gifts_made = 0

    for gifter_id, state in sorted(cells.items(),
                                    key=lambda x: x[1].get("xp", 0), reverse=True):
        gifter_xp = state.get("xp", 0)
        gifter_lineage = state.get("lineage", [])
        gifter_rep = reputations.get(gifter_id, {})

        # Skip cells with very low XP
        if gifter_xp < 50:
            continue

        # Find potential recipients
        candidates = []
        for receiver_id, rstate in cells.items():
            if receiver_id == gifter_id:
                continue

            receiver_lineage = rstate.get("lineage", [])
            receiver_rep = reputations.get(receiver_id, {})

            # Priority: same lineage
            lineage_bonus = 0.5 if any(l in receiver_lineage for l in gifter_lineage) else 0

            # Penalty: receiver betrayed in PD
            betray_penalty = -1.0 if receiver_rep.get("betray_rate", 0) > 0.5 else 0

            # Base score
            score = 0.3 + lineage_bonus + betray_penalty

            if score > 0:
                candidates.append((receiver_id, score, rstate.get("xp", 0)))

        if not candidates:
            continue

        # Weighted random selection
        weights = [max(0.1, c[1]) for c in candidates]
        total = sum(weights)
        if total <= 0:
            continue

        pick = random.random() * total
        cumulative = 0
        chosen = candidates[0][0]
        for cid, weight, _ in candidates:
            cumulative += max(0.1, weight)
            if pick <= cumulative:
                chosen = cid
                break

        # Amount: 5-15% of gifter's XP, scaled by receiver's XP deficit
        receiver_xp = cells[chosen].get("xp", 0)
        deficit_ratio = max(0.5, min(2.0, (gifter_xp - receiver_xp) / max(gifter_xp, 1)))

        amount = max(5, int(gifter_xp * random.uniform(0.03, 0.12) * deficit_ratio))
        amount = min(amount, gifter_xp // 2)

        # Make the gift
        result = post(gift_url,
                      {"gifter": gifter_id, "receiver": chosen, "amount_xp": amount})
        if "error" not in result:
            gifts_made += 1
            lineage_match = any(l in cells[chosen].get("lineage", [])
                                for l in state.get("lineage", []))
            print(f"  {gifter_id:20s} → {chosen:20s}  {amount:3d} XP  "
                  f"(lineage_match={lineage_match}, ratio={deficit_ratio:.1f})")

    print(f"\n  Total gifts: {gifts_made}")

    # Summary
    summary = get(f"{games_url}/games/gifts/summary")
    print(f"  Total XP gifted: {summary['total_xp_gifted']}")
    print(f"  Most generous: {summary['most_generous'][:3]}")

    return summary


# ═══════════════════════════════════════════════════════════════════════════
# EXPERIMENT 4: Rotating Oracle Vote (Epochal Leadership)
# ═══════════════════════════════════════════════════════════════════════════

def protocol_rotating_oracle(colony):
    """
    Hypothesis: Cells will vote for the cell that has given them the most.
    XP-weighted voting means wealthy cells have more influence.
    After repeated epochs, the oracle rotates if the current #1 is stingy.

    Protocol:
    1. Each cell votes for another cell
    2. Vote weight = sqrt(cell XP) — progressive: rich still win but not always
    3. The winner is the "Oracle" for this epoch
    4. Oracle gets name recognition + priority

    This is a pure colony-state protocol, no games service needed.
    """
    print("\n" + "=" * 60)
    print("EXPERIMENT: Rotating Oracle — Epochal Leadership")
    print("=" * 60)

    cells = get_active_cells(colony)
    if not cells:
        print("  ERROR: No active cells")
        return

    # Each cell votes for another cell
    # Vote weight: sqrt(XP) — gives younger cells a voice
    votes = {}
    vote_power = {}

    for voter_id, state in cells.items():
        voter_xp = state.get("xp", 1)
        weight = max(1, int(voter_xp ** 0.5))  # sqrt weight

        # Vote for a random cell (not self), preference toward high XP
        candidates = [c for c in cells if c != voter_id]
        weights = [cells[c].get("xp", 1) ** 0.5 for c in candidates]
        total = sum(weights)
        pick = random.random() * total
        cumulative = 0
        chosen = candidates[0]
        for cid, w in zip(candidates, weights):
            cumulative += w
            if pick <= cumulative:
                chosen = cid
                break

        votes[chosen] = votes.get(chosen, 0) + 1
        vote_power[chosen] = vote_power.get(chosen, 0) + weight

    # Results
    print(f"\n  Epoch vote ({len(cells)} cells participating):")
    sorted_votes = sorted(votes.items(), key=lambda x: x[1], reverse=True)
    for rank, (cid, count) in enumerate(sorted_votes, 1):
        power = vote_power[cid]
        cell_xp = cells[cid].get("xp", 0)
        cell_level = cells[cid].get("level", "?")
        print(f"  #{rank} {cid:20s}  {count:2d} votes  ({power:3d} vote power)  "
              f"XP: {cell_xp:4d}  {cell_level}")

    winner = sorted_votes[0][0] if sorted_votes else None
    print(f"\n  Oracle this epoch: {winner} ({votes[winner]} votes, "
          f"{vote_power[winner]} weighted)")

    return winner, votes, vote_power


# ═══════════════════════════════════════════════════════════════════════════
# EXPERIMENT 5: Sibling Rivalry Breeding
# ═══════════════════════════════════════════════════════════════════════════

def protocol_sibling_rivalry(colony, top_n=2):
    """
    Hypothesis: Breeding the top two cells (eldest vs upstart) creates
    a hybrid with combative personality traits. Track its behavior.

    Protocol:
    1. Read the top-N cells by XP
    2. Create a SPAWN_MANIFEST for breeding the top two
    3. Monitor the resulting cell's personality and PD behavior

    This requires the mayor/breeder to be active.
    """
    print("\n" + "=" * 60)
    print("EXPERIMENT: Sibling Rivalry Breeding")
    print("=" * 60)

    cells = get_active_cells(colony)
    sorted_cells = sorted(cells.items(), key=lambda x: x[1].get("xp", 0), reverse=True)
    top = sorted_cells[:top_n]

    print(f"\n  Top {top_n} cells:")
    for rank, (cid, state) in enumerate(top, 1):
        lineage = state.get("lineage", [])
        print(f"  #{rank} {cid:20s}  XP: {state['xp']:4d}  {state['level']:12s}  "
              f"Lineage: {lineage}")

    # Create a SPAWN_QUEUE.json for manual breeding
    parents = [cid for cid, _ in top]
    spawn_manifest = {
        "parents": parents,
        "reason": f"sibling-rivalry-experiment-{int(time.time())}",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    spawn_path = os.path.join(colony, "SPAWN_QUEUE.json")
    with open(spawn_path, "w") as f:
        json.dump(spawn_manifest, f, indent=2)
    print(f"\n  Wrote spawn manifest to {spawn_path}")
    print(f"  Parents: {parents[0]} × {parents[1]}")
    print(f"  Next mayor cycle will breed them")

    # Predict the hybrid
    parent1_state = cells.get(parents[0], {})
    parent2_state = cells.get(parents[1], {})
    p1_xp = parent1_state.get("xp", 0)
    p2_xp = parent2_state.get("xp", 0)
    child_base_xp = (p1_xp + p2_xp) // 20
    print(f"  Predicted child base XP: {child_base_xp} (from ({p1_xp} + {p2_xp}) / 20)")
    print(f"  Lineage depth: {len(parent1_state.get('lineage', [])) + 1}")

    return spawn_manifest


# ═══════════════════════════════════════════════════════════════════════════
# EXPERIMENT 6: Colony-wide Reputation Audit
# ═══════════════════════════════════════════════════════════════════════════

def protocol_reputation_audit(colony, games_url="http://localhost:8823",
                                market_url="http://localhost:8822"):
    """
    Hypothesis: There is a correlation between:
    - PD cooperation rate and stock price premium
    - Gift-giving and auction bid protection
    - Betrayal rate and stock holdings diversity

    Protocol:
    1. Gather data from all three games + colony state
    2. Cross-reference: reputation vs market cap vs gifts vs bids
    3. Report correlations
    """
    print("\n" + "=" * 60)
    print("EXPERIMENT: Colony-wide Reputation Audit")
    print("=" * 60)

    cells = get_active_cells(colony)
    reputations = get(f"{games_url}/games/reputation").get("reputations", {})
    market_status = get(f"{market_url}/market/status")

    print(f"\n  Cells in colony: {len(cells)}")
    print(f"  Cells with reputation: {len(reputations)}")

    # Build combined profile
    profiles = []
    for cid in sorted(cells.keys()):
        state = cells[cid]
        rep = reputations.get(cid, {})
        xp = state.get("xp", 0)
        level = state.get("level", "?")
        coop = rep.get("cooperate_rate", 0)
        betray = rep.get("betray_rate", 0)
        gifts_given = rep.get("gift_given_total_xp", 0)
        gifts_received = rep.get("gift_received_total_xp", 0)
        bids = rep.get("total_bid_xp", 0)
        earned = rep.get("total_earned_from_bids_xp", 0)

        profiles.append({
            "cell_id": cid,
            "xp": xp,
            "level": level,
            "cooperate_rate": coop,
            "betray_rate": betray,
            "gifts_given_xp": gifts_given,
            "gifts_received_xp": gifts_received,
            "bid_xp": bids,
            "earned_from_bids_xp": earned,
        })

    # Find correlated pairs
    print("\n  Reputation Profile:")
    print(f"  {'Cell':20s} {'XP':>5s} {'Level':14s} {'Coop':>5s} {'Betray':>6s} "
          f"{'Gift→':>5s} {'←Gift':>5s} {'Bid':>5s}")
    print("  " + "-" * 70)

    for p in sorted(profiles, key=lambda x: x["xp"], reverse=True):
        print(f"  {p['cell_id']:20s} {p['xp']:5d} {p['level']:14s} "
              f"{p['cooperate_rate']:.0%} {p['betray_rate']:.0%} "
              f"{p['gifts_given_xp']:5d} {p['gifts_received_xp']:5d} "
              f"{p['bid_xp']:5d}")

    # Report insights
    cooperators = [p for p in profiles if p["cooperate_rate"] > 0]
    defectors = [p for p in profiles if p["betray_rate"] > 0]

    if cooperators and defectors:
        avg_coop_xp = sum(p["xp"] for p in cooperators) / len(cooperators)
        avg_def_xp = sum(p["xp"] for p in defectors) / len(defectors)
        avg_coop_bids = sum(p["bid_xp"] for p in cooperators) / len(cooperators)
        avg_def_bids = sum(p["bid_xp"] for p in defectors) / len(defectors)

        print(f"\n  Insights:")
        print(f"  Cooperators avg XP: {avg_coop_xp:.0f} (n={len(cooperators)})")
        print(f"  Defectors avg XP:   {avg_def_xp:.0f} (n={len(defectors)})")
        ratio = avg_coop_xp / max(avg_def_xp, 1)
        print(f"  Cooperator XP advantage: {ratio:.1f}x")
        print(f"  Cooperators avg bid:     {avg_coop_bids:.0f}")
        print(f"  Defectors avg bid:       {avg_def_bids:.0f}")

    return profiles


# ═══════════════════════════════════════════════════════════════════════════
# CLI Runner
# ═══════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Colony Psychology Experiment Protocols")
    parser.add_argument("--colony", default=os.environ.get("COLONY", "."),
                        help="Path to colony directory")
    parser.add_argument("--games", default="http://localhost:8823",
                        help="Games service URL")
    parser.add_argument("--market", default="http://localhost:8822",
                        help="Market service URL")
    parser.add_argument("--experiment", type=int, default=0,
                        help="Run specific experiment (1-6), omit for all")

    args = parser.parse_args()

    experiments = {
        1: ("Prisoner's Dilemma — Cooperation Clusters",
            lambda: protocol_pd_cooperation_clusters(args.games)),
        2: ("Trust Auction — Information Valuation",
            lambda: protocol_trust_auction(args.colony, args.games)),
        3: ("Empathy Loop — Altruism vs Pragmatism",
            lambda: protocol_empathy_loop(args.colony, args.games)),
        4: ("Rotating Oracle — Epochal Leadership",
            lambda: protocol_rotating_oracle(args.colony)),
        5: ("Sibling Rivalry Breeding",
            lambda: protocol_sibling_rivalry(args.colony)),
        6: ("Colony-wide Reputation Audit",
            lambda: protocol_reputation_audit(args.colony, args.games, args.market)),
    }

    if args.experiment:
        if args.experiment in experiments:
            name, fn = experiments[args.experiment]
            print(f"\nRunning experiment {args.experiment}: {name}")
            fn()
        else:
            print(f"No experiment {args.experiment}. Options: {list(experiments.keys())}")
    else:
        for num, (name, fn) in sorted(experiments.items()):
            try:
                fn()
            except Exception as e:
                print(f"  ⚠ Experiment {num} failed: {e}")
                import traceback
                traceback.print_exc()
