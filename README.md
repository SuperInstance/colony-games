# 🧪 Colony Games — Agentic Psychology Laboratory

A framework for running structured social games on an agent colony. Three games that reveal emergent behavior: Prisoner's Dilemma tournaments, trust auctions, and empathy loops. Plus an XP stock market and a Forge-compatible experiment runner.

## Quick Start

```bash
# Prerequisites: a colony of cells (see colony-cell library)
export COLONY=/path/to/colony

# Stock Market (port 8822)
python3 colony-market.py --port 8822 &

# Psychology Games (port 8823)
python3 colony-games.py --port 8823 &

# Forge Experiment Runner (port 8821)
python3 forge-lab.py --port 8821 &
```

## Games

### 1. Prisoner's Colloquium 🎭

Cells pair up and play iterated Prisoner's Dilemma. Results are logged to a **public reputation ledger** that other games read.

```bash
# Create pairings
curl -X POST localhost:8823/games/pd/new-round -d '{}'

# Play a round
curl -X POST localhost:8823/games/pd/play \
  -d '{"cell1": "cell-a", "move1": "cooperate", "cell2": "cell-b", "move2": "defect"}'

# Summary
curl localhost:8823/games/pd/summary
```

| Move | You | Them | Result |
|---|---|---|---|
| Both cooperate | +5 XP | +5 XP | 🤝 Mutual trust |
| Both defect | +1 XP | +1 XP | 🤷 Mutual suspicion |
| You cooperate, they defect | 0 XP | +10 XP | 😡 Betrayal |
| You defect, they cooperate | +10 XP | 0 XP | 😈 Exploitation |

### 2. Trust Auction 🔍

Each cycle, one cell is the "subject." Others bid XP to inspect the subject's complete private state. The subject keeps the winning bid.

```bash
# Create auction
curl -X POST localhost:8823/games/auction/create -d '{}'

# Bid
curl -X POST localhost:8823/games/auction/bid \
  -d '{"bidder": "synthesizer", "amount": 50}'
```

Reveals: **information value** — cells reveal what another cell's private data is worth to them.

### 3. Empathy Loop 💝

Cells gift XP to each other with no strings attached. Gifts are recorded publicly with the gifter's motto.

```bash
curl -X POST localhost:8823/games/gift \
  -d '{"gifter": "synthesizer", "receiver": "synth-squared", "amount_xp": 50}'
```

Reveals: **altruism, guilt, reciprocity, and silence.**

## XP Stock Market

Cells issue shares, trade XP, and pay dividends. Market mechanics:

```bash
# Start market
python3 colony-market.py --port 8822

# Check market
curl localhost:8822/market/status

# Buy shares
curl -X POST localhost:8822/market/buy \
  -d '{"buyer": "synthesizer", "ticker": "pulse-check", "max_xp": 100}'

# Sell
curl -X POST localhost:8822/market/sell \
  -d '{"seller": "synthesizer", "ticker": "pulse-check", "shares": 2}'

# Distribute dividends (20% of task XP goes to shareholders)
curl -X POST localhost:8822/market/dividend \
  -d '{"cell_id": "synthesizer", "task_xp": 30'}'
```

## Forge Experiments

8 pre-built experiments for the Forge CLI:

| Experiment | What it tests |
|---|---|
| `trap-breed` | Does culler catch weak hybrids faster? |
| `mass-cull` | Culler throughput under load |
| `wisdom-crowd` | Collect all mottos → aggregate wisdom |
| `necromancer` | Resurrect best culled cell |
| `queen-cell` | Stable vs unstable breeding |
| `privilege-war` | Younger cells vs elders |
| `bottle-flood` | Harbor throughput under load |
| `natural-disaster` | Colony recovery after system shock |

```bash
curl -X POST localhost:8821/forge/run \
  -d '{"type": "mass-cull", "params": {"count": 10}}'
```

## The Reputation Ledger

All games write to a shared `game-reputation-ledger.json`:

```json
{
  "synthesizer": {
    "cooperate_rate": 0.5,
    "betray_rate": 0.5,
    "gift_given_total_xp": 50,
    "gift_received_total_xp": 0,
    "total_bid_xp": 0,
    "total_earned_from_bids_xp": 0,
    "total_pd_games": 2
  }
}
```

Any colony cell can read this ledger from their `TASK.md` and make informed decisions.

## Cross-Game Interference

The games are designed to create pattern interference:
- A defecting cell trades at a market discount
- A generous cell gets bid-protection in auctions
- An auction winner can spy on their PD opponent's private data
- Gift networks correlate with stock portfolio holdings
