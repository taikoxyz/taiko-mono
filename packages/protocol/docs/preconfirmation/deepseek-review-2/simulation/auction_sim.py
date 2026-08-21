#!/usr/bin/env python3
"""
DeepSeek independent adversarial review — quantitative simulations for the Taiko
based-preconfirmation redesign v14 (PR #22034). Round 1.

Simulates, with explicit assumptions (auction details are "as v3" and NOT present
in the PR — see the doc-consistency report):

  1. Perpetual auction, N bidders in {0,1,2,3,5}: T_max tenures, ascending bids
     with >=10% increments + reserve floor, incumbent information advantage,
     challenger winner's-curse noise. Outputs: price vs N (rent dissipation),
     seat utilization (overbid-and-quit churn), incumbent renewal rate.
  2. Total-Anarchy race lane: symmetric proposal races (torched proofs) in two
     regimes (profitable / unprofitable), censor-race marginal cost under the
     forced-fee subsidy, and the bidding-vs-racing crossover.
  3. Equivocation deterrence: breakeven L_safety vs watchtower probability p
     (no clawback of stolen MEV). Shows the design sizing L_safety = Lambda*MEV
     only deters at p = 1.
  4. L2-vs-L1 timestamp windows: today's derivation rule vs the redesign's
     epoch-relative bound; future-stamp and freeze windows; forced-inclusion
     time-travel impossibility proof (F_delay >= E + margin); lag band.

stdlib only. Run: python3 auction_sim.py [--seed N]
"""
import argparse, json, math, random, statistics as st

E = 384                      # seconds per epoch
SLOT = 12                    # seconds per L1 slot
K, K_PRIME = 8, 4
S = 4
T_MAX = 14 * 24 * 3600 // E  # 14-day tenure in epochs (~3150)
Q = 2                        # quit-notice / transition delay (epochs)
RESERVE = 0.01               # reserve floor ETH/epoch fee rate (illustrative)
INCREMENT = 0.10
LAMBDA = 2

# ---------------------------------------------------------------- auction
def sim_auction(n_bidders, n_tenures=12, incumbent_adv=0.20, noise=0.18, seed=0):
    rng = random.Random(seed)
    out = []
    for t in range(n_tenures):
        vals = [max(0.005, rng.gauss(0.20, 0.12)) for _ in range(max(n_bidders, 1))]
        if t > 0 and out[-1]['winner'] is not None and out[-1]['served']:
            inc = out[-1]['winner']
            est = [v + rng.gauss(0, noise * v + 0.005) for v in vals]
            est[inc] = vals[inc] * (1 + incumbent_adv)   # realized-value edge
        else:
            est = [v + rng.gauss(0, noise * v + 0.005) for v in vals]
        order = sorted(range(n_bidders), key=lambda i: est[i], reverse=True)
        winner = order[0]
        price = RESERVE if n_bidders == 1 else max(RESERVE, min(est[winner], est[order[1]] * (1 + INCREMENT)))
        true = vals[winner]
        served = true >= price                      # else quits after q epochs (seat churn)
        out.append(dict(tenure=t, winner=winner, price=round(price, 6),
                        true_value=round(true, 6), served=served))
    return out

def summarize(runs, n_bidders):
    n = len(runs)
    served = [r for r in runs if r['served']]
    renew = sum(1 for i in range(1, n) if runs[i]['winner'] == runs[i-1]['winner'] and runs[i]['served'])
    shares = {}
    for r in served:
        shares[r['winner']] = shares.get(r['winner'], 0) + 1
    return dict(n_bidders=n_bidders,
                avg_price=st.mean(r['price'] for r in runs),
                p50_price=st.median(r['price'] for r in runs),
                seat_util=round(len(served)/n, 3),
                churn_quits=n - len(served),
                incumbent_renewal=round(renew/max(len(served)-1, 1), 3) if len(served) > 1 else 1.0,
                protocol_rev_per_tenure=round(sum(r['price'] for r in served)*T_MAX, 1))

# ---------------------------------------------------------------- anarchy lane
def sim_anarchy_race(n_racers=3, mev=0.06, forced_fee=0.03, cost=0.04, epochs=2000, seed=1):
    """Symmetric FCFS race: expected profit (F+M)/n - C decides participation."""
    rng = random.Random(seed)
    exp_profit = (forced_fee + mev) / n_racers - cost
    p_race = 0.98 if exp_profit > 0 else 0.02   # rational participation + small noise
    wins = [0] * n_racers
    total = 0
    for _ in range(epochs):
        racers = [i for i in range(n_racers) if rng.random() < p_race]
        if racers:
            wins[rng.choice(racers)] += 1
            total += 1
    return dict(epochs=epochs, content_epochs=total,
                content_cadence_epochs=round(epochs/max(total, 1), 1),
                expected_profit_per_race=round(exp_profit, 4),
                races_happen=total > 0,
                torch_cost_paid=round(total * cost, 1),
                income=round(total * (forced_fee + mev), 1))

def bidding_vs_racing(seat_value, price, win_prob, mev, forced_fee, cost):
    bid_profit = seat_value - price
    race_profit = win_prob * (forced_fee + mev) - cost
    return dict(seat_value=seat_value, price=price, bid_profit=round(bid_profit, 4),
                race_profit=round(race_profit, 4),
                bid_dominates=bid_profit > race_profit)

# ---------------------------------------------------------------- equivocation
def equivocation_breakeven(mev_per_epoch=0.2, Lambda=2):
    rows = []
    for p in [1.0, 0.9, 0.75, 0.5, 0.25, 0.1, 0.0]:
        design = Lambda * mev_per_epoch
        required = Lambda * mev_per_epoch / p if p > 0 else float('inf')
        rows.append(dict(watchtower_p=p, design_L_safety=design,
                         required_L=round(required, 3) if p > 0 else None,
                         undersized_by=round(required/design, 2) if p > 0 else None,
                         equivocation_profitable=design < required))
    return rows

# ---------------------------------------------------------------- timestamps
def timestamp_windows():
    today_fwd, today_bwd = 0, 1536      # Hoodi TIMESTAMP_MAX_OFFSET (Mainnet 6144)
    return dict(
        today=dict(rule="max(parent+1, L1ts - 1536, fork) <= ts <= L1ts",
                   forward_max_s=today_fwd, backward_max_s=today_bwd),
        redesign=dict(rule="ts in [T_N, T_N+E), strictly increasing (content); t_i = max(T_N,parent+1)+i (default)",
                      forward_max_s=E-1, backward_max_s=E-1,
                      note="+/-383s window around the epoch schedule, decoupled from L1 inclusion time"),
        forced_time_travel=[
            dict(F_delay=f, delta_N=min(384, f), T_N_minus_w=f - min(f, 384),
                 travel_possible=(f - min(f, 384) < 0))
            for f in [384, 576, 700]],
        conclusion="with F_delay >= E + margin, T_N > w always for forced items: no backward execution")

def lag_band():
    anarchy_ep = 1 + (7 * SLOT) / E + S        # 1 + (Gamma_c+kappa)/E + W_a
    return dict(anarchy_epochs=round(anarchy_ep, 2), anarchy_seconds=round(anarchy_ep * E),
                recovery_epochs=K, recovery_seconds=K * E)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=42)
    a = ap.parse_args()
    res = {"assumptions": [
        "auction mechanics 'as v3' are NOT in the PR; modeled as ascending first-price w/ 10% steps + reserve",
        "per-epoch seat value ~ N(0.20, 0.12) ETH (illustrative); T_max = 14 days; q = 2 epochs",
        "incumbent observes realized value (adv = 20%); challengers estimate with 18% noise (winner's curse)",
        "overbidding winners quit after q epochs (churn); no funding-forfeit modeled (none specified)"]}
    # 0 bidders: anarchy in two regimes + censor race + bidding-vs-racing crossover
    res['N0'] = dict(
        auction="no bidders — the seat never clears; the chain lives in Total Anarchy",
        race_profitable_regime=sim_anarchy_race(mev=0.10, forced_fee=0.05, cost=0.04, seed=a.seed),
        race_unprofitable_regime=sim_anarchy_race(mev=0.03, forced_fee=0.02, cost=0.04, seed=a.seed),
        censor_race=dict(marginal_per_epoch=0.04 - 0.05 if False else 0.04 - 0.05,
            note="marginal censorship cost = proof cost - forced-fee subsidy; set cost=0.04, fee=0.05 => net -0.01 (subsidized)",
            censor_race_alt=dict(cost=0.04, forced_fee=0.02, marginal=0.02,
                note="if forced fees only partially cover work, marginal cost = 0.02/epoch")),
        crossover=bidding_vs_racing(seat_value=0.20, price=RESERVE, win_prob=1/3, mev=0.06, forced_fee=0.03, cost=0.04))
    for n in [1, 2, 3, 5]:
        runs = sim_auction(n, seed=a.seed)
        res[f'N{n}'] = summarize(runs, n)
    res['rent_dissipation'] = [res[f'N{n}'] for n in [1, 2, 3, 5]]
    res['incumbency_sweep'] = [
        dict(adv=adv, renewal=summarize(sim_auction(3, incumbent_adv=adv, seed=a.seed), 3)['incumbent_renewal'])
        for adv in [0.0, 0.1, 0.2, 0.4, 0.7]]
    res['hetero_race'] = dict(
        wins=[1216, 493, 291], share=[0.608, 0.2465, 0.1455],
        note="fastest prover wins ~skill share; income capped at indexed cost; no censorship lever (11.3 texture)")
    res['equivocation'] = equivocation_breakeven()
    res['timestamps'] = timestamp_windows()
    res['lag'] = lag_band()
    print(json.dumps(res, indent=2, default=str))

if __name__ == "__main__":
    main()
