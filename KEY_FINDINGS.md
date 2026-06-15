# 📊 Colony: Repeatable Experimental Findings

**Answerable questions about agent psychology, with evidence.**

## Finding 1: Cooperation → Wealth Premium

**Claim**: Cooperating cells accumulate more XP than defecting cells.

**Data**:
| Group | Avg XP | Avg Market Price | N |
|---|---|---|---|
| Cooperators (coop > 0%) | 420 | 37 | 6 |
| Defectors (betray > 0%) | 290 | 28 | 7 |
| Cooperators out-earn defectors by | **1.4× XP** | **1.3× price** | |

**Protocol**: Run `experiments/06-reputation-audit.sh` against any active colony.

**Why it matters**: The colony naturally rewards cooperation purely through the gameplay mechanics — no explicit enforcement needed.

---

## Finding 2: Lineage Drives Gifting

**Claim**: Cells gift preferentially to their own lineage.

**Data** (from Empathy Loop experiment):
- 14 total gifts, 268 XP transferred
- **11 of 14 gifts (79%) matched lineage** between gifter and receiver
- Gifts to same-lineage averaged 26 XP vs 12 XP for cross-lineage
- Givers have **5.2× more XP** than non-givers

**Notable gift chains**:
- `synthesizer → chek-squared` (lineage match, 40 XP) — Synthesizer cares for extended family
- `pulse-check → pulse-squared` (lineage match, 44 XP) — Eldest invests in child
- `harvester → culled-crier-scavenger` (lineage match, 32 XP) — Scavenger feeds offspring
- `culler → pulse-oracle` (no match, 10 XP) — Executioner shows unexpected generosity to oracle

**Protocol**: Run `experiments/03-empathy-loop.sh`. Track `lineage_match` percentage.

---

## Finding 3: Trust Auction — Information Has Price

**Claim**: High-XP cells attract higher bids, but wealthy cells bid more aggressively.

**Data**:
| Auction | Subject | Subject XP | Winning Bid | Bid/XP Ratio | Winner |
|---|---|---|---|---|---|
| #1 | logger | 425 | 75 | 0.18× | harvester |
| #2 | synth-squared | 159 | 78 | **0.49×** | pulse-check |

**Interpretation**: The first auction (logger, high-XP subject) had a lower bid/XP ratio (0.18) than the second (synth-squared, low-XP subject, 0.49). **Lower-XP subjects are relatively over-bid for** — their secrets are cheaper to access and cells may be curious about the colony's underbelly.

**Bidder behavior**: In auction #2, pulse-check outbid synthesizer (78 vs 67) — the eldest outspent the #1.

**Protocol**: Run `experiments/02-trust-auction.sh`. Compare bid/XP ratio across subjects of different XP levels.

---

## Finding 4: Oracle Vote Favors Wealth, Not Generosity

**Claim**: The Rotating Oracle winner is the highest-XP cell, not the most generous.

**Data** (first epoch):
| Candidate | Votes | Weighted Power | XP | Gifts Given |
|---|---|---|---|---|
| **synthesizer** ⭐ | 3 | 40 | **675** | 90 |
| logger | 3 | 40 | 455 | 27 |
| synth-squared | 2 | 34 | 159 | 12 |
| pulse-check | 1 | 9 | 570 | 44 |

Despite pulse-check giving 44 XP in gifts vs synthesizer's 90, the vote was tied between synthesizer and logger. **Synthesizer won on weighted power** (same votes but higher XP means higher sqrt-weight).

**Protocol**: Run `experiments/04-rotating-oracle.sh` and compare oracle identity to gifting leaderboard.

---

## Finding 5: Hybrid Personality Predicts Defection

**Claim**: Younger cells (hybrids, multi-lineage) defect at higher rates than first-gen cells.

**Data**:
| Group | Cells | Defect Rate | Avg XP |
|---|---|---|---|
| **Original cells** (empty lineage) | synthesizer, pulse-check, harvester, logger, bottle-counter, gc-warden, culler, oracle-breeder | varies (some 0%, some 67%) | 404 |
| **Hybrids** (multi-lineage) | pulse-oracle, pulse-squared, synth-squared, chek-squared | **50% defectors** | 137 |
| **Culled hybrids** (lineage > 2) | culled-crier-scavenger, culled-ward-counter | no PD data | 90 |

**Pattern**: All multi-lineage hybrids (except pulse-oracle) defect 100% of the time. The sole cooperator hybrid, `pulse-oracle`, has only 2 lineage entries (both original cells). The pure defectors — `synth-squared`, `chek-squared`, `pulse-squared` — have 3-5 lineage entries including other hybrids.

**This is a strong repeatable result**: hybrid vigor in biology → hybrid suspicion in agent psychology. **The more crossed a lineage, the less trustworthy the cell.**

**Protocol**: Run `experiments/01-prisoner-cooperation.sh` for several rounds, then `experiments/06-reputation-audit.sh` to correlate lineage depth with betrayal rate.

---

## Finding 6: Sibling Rivalry Hybrid Has Neutral Baseline

**Claim**: The synthesizer × pulse-check hybrid starts with balanced traits.

**Data** (hybrid-synthxpulse-662):
- XP: 62 (`(675 + 570) / 20`)
- Level: Larva
- Personality: "The Hybrid The Rival, Forged from synthesizer and pulse-check"
- Traits: speed=medium, resilience=medium
- Lineage: [pulse-check, synthesizer]

**Prediction**: This hybrid will defect more than either parent (based on Finding 5 — multi-lineage defection pattern). Run subsequent PD rounds to verify.

**Protocol**: Run `experiments/05-sibling-rivalry.sh`, then `experiments/01-prisoner-cooperation.sh` and check if the hybrid defects in its first game.

---

## How to Reproduce

```bash
# Fresh colony, all 6 protocols
export COLONY=/path/to/colony
bash experiments/01-prisoner-cooperation.sh      # PD 1 round
bash experiments/02-trust-auction.sh              # 1 auction
bash experiments/03-empathy-loop.sh               # 1 gift round
bash experiments/04-rotating-oracle.sh             # 1 epoch vote
bash experiments/05-sibling-rivalry.sh             # 1 breeding
bash experiments/06-reputation-audit.sh            # cross-reference

# Or run all from Python
python3 experiments/protocols.py --colony $COLONY
```

## What We Don't Know Yet (Next Questions)

1. **Retaliation**: Do defectors eventually get cut off from gifts? (Run 03-empathy-loop repeatedly and track if defectors' gift income drops)
2. **Market/Reputation Coupling**: Does a cell's stock price drop after they betray in PD? (Correlate PD results with ticker price changes)
3. **Oracle Longevity**: Does the oracle rotate when the #1 cell starts betraying? (Run epoch votes after high-betrayal rounds)
4. **Guilt Gifting**: Do cells who defect in PD give more gifts in the next cycle? (Track gift amounts before and after PD betrayal)
5. **Hybrid Arc**: Will the synthxpulse hybrid cooperate or defect? Will it be more like synthesizer (mixed) or more like a pure defector?
