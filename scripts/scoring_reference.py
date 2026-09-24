#!/usr/bin/env python3
"""Reference implementation of the league scoring rules (PRD section 6).

Generates RivaliftTests/Fixtures/scoring_vectors.json. The Swift domain tests
(LeagueScoreEstimator, StrengthScorer, CustomCategoryScorer) and, from M5, the SQL
scoring tests must all reproduce these expected values.

Usage: python3 scripts/scoring_reference.py
"""
import json
from datetime import datetime, timedelta
from pathlib import Path

CFG = dict(session_pts=10, max_sessions=5, pr_pts=5, max_prs_session=5, max_prs_week=10,
           target_bonus=20, min_target=2, streak_pts=5, max_streak=4, min_duration=900, min_sets=6)
WEIGHT_TOL = 0.05


def iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ")


def eligible(s):
    start, sub = parse(s["startedAt"]), parse(s["submittedAt"])
    if (start - sub).total_seconds() > 5 * 60:
        return False
    if (sub - start).total_seconds() > 48 * 3600:
        return False
    return True


def consistency(week):
    valid = [s for s in week["sessions"]
             if s["durationSec"] >= CFG["min_duration"] and s["workingSets"] >= CFG["min_sets"] and eligible(s)]
    days = len({s["localDate"] for s in valid})
    prs = min(sum(min(max(s["leaguePRs"], 0), CFG["max_prs_session"]) for s in valid), CFG["max_prs_week"])
    target_met = week["weeklyTarget"] >= CFG["min_target"] and days >= week["weeklyTarget"]
    streak = min(max(week["streakWeeks"], 0), CFG["max_streak"])
    out = dict(validSessions=days,
               sessionPoints=min(days, CFG["max_sessions"]) * CFG["session_pts"],
               prPoints=prs * CFG["pr_pts"],
               targetPoints=CFG["target_bonus"] if target_met else 0,
               streakPoints=streak * CFG["streak_pts"])
    out["total"] = out["sessionPoints"] + out["prPoints"] + out["targetPoints"] + out["streakPoints"]
    return out


def within(v, best, limit):
    return best is None or best <= 0 or v <= best * (1 + limit) + 1e-9


def strength(lifts, comparison):
    def best(l):
        vals = [v for v in l["weekE1RMsKg"] if within(v, l["baselineE1RMKg"], 0.25)]
        return max(vals) if vals else None
    if comparison == "absolute":
        return dict(score=round(sum(best(l) or 0 for l in lifts), 6), baselineLifts=[])
    gains, baseline = [], []
    for l in lifts:
        b = l["baselineE1RMKg"]
        if not b:
            baseline.append(l["exerciseKey"])
            continue
        w = best(l)
        w = b if w is None else w
        gains.append(max(0.0, (w - b) / b * 100))
    return dict(score=round(sum(gains) / len(gains), 6) if gains else None, baselineLifts=baseline)


def rank_category(values, weight_based):
    logged = sorted([(u, v) for u, v in values.items() if v is not None], key=lambda x: (-x[1], x[0]))
    n = len(logged)
    out, prev, rank = [], None, 0
    for i, (u, v) in enumerate(logged):
        tied = prev is not None and (abs(prev - v) <= WEIGHT_TOL if weight_based else prev == v)
        if not tied:
            rank = i + 1
        prev = v
        out.append(dict(userID=u, value=v, rank=rank, points=n - rank + 1))
    for u, v in sorted(values.items()):
        if v is None:
            out.append(dict(userID=u, value=None, rank=None, points=0))
    return out


def overall(placements):
    totals = {}
    for idx, cat in enumerate(placements):
        for p in cat:
            t = totals.setdefault(p["userID"], [0, 0, 0])
            t[0] += p["points"]
            if p["rank"] == 1:
                t[1] += 1
            if idx == 0:
                t[2] = p["points"]
    order = sorted(totals.items(), key=lambda kv: (-kv[1][0], -kv[1][1], -kv[1][2], kv[0]))
    out = []
    for i, (u, t) in enumerate(order):
        rank = i + 1
        if out and totals[out[-1]["userID"]] == t:
            rank = out[-1]["rank"]
        out.append(dict(userID=u, points=t[0], categoryWins=t[1], rank=rank))
    return out


WEIGHT_METRICS = {"heaviest_weight", "e1rm", "best_set_volume"}


def session(i, day, minutes=45, sets=12, prs=0, submit_delay_h=1, start_hour=18):
    start = datetime(2026, 9, 21 + day, start_hour, 0, 0)
    return dict(id=f"s{i}", localDate=start.strftime("%Y-%m-%d"), durationSec=minutes * 60, workingSets=sets,
                leaguePRs=prs, startedAt=iso(start), submittedAt=iso(start + timedelta(hours=submit_delay_h)))


def main():
    consistency_cases = [
        ("PRD example: target 3, 4 sessions, 3 PRs, streak 2",
         dict(weeklyTarget=3, streakWeeks=2, sessions=[session(1, 0, prs=2), session(2, 1, prs=1), session(3, 3), session(4, 5)])),
        ("Empty week", dict(weeklyTarget=3, streakWeeks=0, sessions=[])),
        ("Two sessions on one day count once", dict(weeklyTarget=2, streakWeeks=0,
            sessions=[session(1, 0, start_hour=7), session(2, 0, start_hour=18), session(3, 2)])),
        ("Sessions capped at 5, target 7 not met", dict(weeklyTarget=7, streakWeeks=1,
            sessions=[session(i, i) for i in range(7)][:6])),
        ("Short and small sessions are invalid", dict(weeklyTarget=2, streakWeeks=0,
            sessions=[session(1, 0, minutes=14, prs=3), session(2, 1, sets=5, prs=2), session(3, 2, prs=1)])),
        ("PRs capped per session and per week", dict(weeklyTarget=3, streakWeeks=6,
            sessions=[session(1, 0, prs=8), session(2, 1, prs=4), session(3, 2, prs=3)])),
        ("Target of 1 earns no bonus", dict(weeklyTarget=1, streakWeeks=0, sessions=[session(1, 0)])),
        ("Backdated more than 48h is ignored", dict(weeklyTarget=2, streakWeeks=0,
            sessions=[session(1, 0, submit_delay_h=49, prs=2), session(2, 2), session(3, 3)])),
        ("Start in the future (clock tampering) is ignored", dict(weeklyTarget=2, streakWeeks=0,
            sessions=[dict(session(1, 1), submittedAt=iso(datetime(2026, 9, 22, 17, 50))), session(2, 3)])),
        ("Maximum score", dict(weeklyTarget=5, streakWeeks=9,
            sessions=[session(i, i, prs=2) for i in range(5)])),
    ]
    strength_cases = [
        ("PRD example: bench 100→103, squat 120→126", "relative", [
            dict(exerciseKey="barbell_bench_press", baselineE1RMKg=100.0, weekE1RMsKg=[101.0, 103.0]),
            dict(exerciseKey="barbell_back_squat", baselineE1RMKg=120.0, weekE1RMsKg=[126.0])]),
        ("Lift not performed scores 0; drop floored at 0", "relative", [
            dict(exerciseKey="barbell_bench_press", baselineE1RMKg=100.0, weekE1RMsKg=[95.0]),
            dict(exerciseKey="deadlift", baselineE1RMKg=180.0, weekE1RMsKg=[]),
            dict(exerciseKey="barbell_back_squat", baselineE1RMKg=120.0, weekE1RMsKg=[132.0])]),
        ("Baseline week lift is excluded", "relative", [
            dict(exerciseKey="barbell_bench_press", baselineE1RMKg=None, weekE1RMsKg=[90.0]),
            dict(exerciseKey="barbell_back_squat", baselineE1RMKg=100.0, weekE1RMsKg=[110.0])]),
        ("All lifts in baseline week", "relative", [
            dict(exerciseKey="barbell_bench_press", baselineE1RMKg=None, weekE1RMsKg=[90.0])]),
        ("Spike over 25% ignored, next best used", "relative", [
            dict(exerciseKey="barbell_bench_press", baselineE1RMKg=100.0, weekE1RMsKg=[130.0, 104.0])]),
        ("Absolute sums best e1RMs", "absolute", [
            dict(exerciseKey="barbell_bench_press", baselineE1RMKg=100.0, weekE1RMsKg=[103.0, 101.0]),
            dict(exerciseKey="barbell_back_squat", baselineE1RMKg=None, weekE1RMsKg=[140.0]),
            dict(exerciseKey="deadlift", baselineE1RMKg=180.0, weekE1RMsKg=[])]),
    ]
    custom_cases = [
        ("PRD example group: pull-ups, curl volume, plank", [
            dict(metric="max_reps", values=dict(ana=12.0, budi=14.0, citra=None, dimas=10.0)),
            dict(metric="best_set_volume", values=dict(ana=160.0, budi=150.0, citra=175.0, dimas=None)),
            dict(metric="longest_hold", values=dict(ana=90.0, budi=None, citra=120.0, dimas=60.0))]),
        ("Ties share rank; overall tie broken by category wins", [
            dict(metric="max_reps", values=dict(ana=10.0, budi=10.0, citra=8.0)),
            dict(metric="heaviest_weight", values=dict(ana=20.0, budi=22.5, citra=22.52))]),
        ("Nobody logged a category", [
            dict(metric="total_reps", values=dict(ana=None, budi=None)),
            dict(metric="e1rm", values=dict(ana=100.0, budi=110.0))]),
    ]

    vectors = dict(
        description="Shared scoring vectors (PRD section 6). Generated by scripts/scoring_reference.py; do not edit by hand.",
        config=CFG,
        consistency=[dict(name=n, input=w, expected=consistency(w)) for n, w in consistency_cases],
        strength=[dict(name=n, comparison=c, lifts=l, expected=strength(l, c)) for n, c, l in strength_cases],
        custom=[],
    )
    for name, cats in custom_cases:
        placements = [rank_category(c["values"], c["metric"] in WEIGHT_METRICS) for c in cats]
        vectors["custom"].append(dict(
            name=name,
            categories=[dict(metric=c["metric"], values=c["values"], expected=p) for c, p in zip(cats, placements)],
            expectedOverall=overall(placements)))

    out = Path(__file__).resolve().parent.parent / "RivaliftTests" / "Fixtures" / "scoring_vectors.json"
    out.write_text(json.dumps(vectors, indent=2) + "\n")
    print(f"wrote {out}")
    for c in vectors["consistency"]:
        print(f'  consistency: {c["name"]}: {c["expected"]["total"]}')
    for c in vectors["strength"]:
        print(f'  strength: {c["name"]}: {c["expected"]["score"]}')
    for c in vectors["custom"]:
        print(f'  custom: {c["name"]}: {[(o["userID"], o["points"], o["rank"]) for o in c["expectedOverall"]]}')


if __name__ == "__main__":
    main()
