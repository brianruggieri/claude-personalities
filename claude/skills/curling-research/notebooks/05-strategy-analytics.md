# Strategy & Analytics

Tactical decision-making and quantitative analytics for curling: hammer/no-hammer
playbooks, end-by-end strategy, expected-points (EP) and win-probability (WP)
models, force/steal/blank/hammer-efficiency metrics, free-guard-zone (FGZ) tactics
across the 4-rock and 5-rock eras, mixed doubles power-play timing, and the
published curling analytics literature plus credentialed analyst blogs.

This notebook is the *coaching/analytics* lens — what humans should do and how
researchers measure whether they did it well. Implementation of any of this
inside a search algorithm (MCTS, rollouts, value heads) belongs in Notebook 12.

## Scope

**In scope:**
- Hammer strategy: aggressive-with, defensive-without, blanking, forcing 1, stealing
- End-by-end framework: early ends (guard play, FGZ jockeying), mid-game
  (positioning, scoreboard management), late-end conversion (8/9/10 decision
  trees, "1-down hammer" canonical situations)
- Expected-points and win-probability models (Markov, empirical state-space,
  multiclass classifiers); steal/force/blank/hammer-efficiency metric
  definitions
- The "value of a deuce" — why scoring 2 with hammer dominates scoring 1, and
  why blanking is sometimes mathematically preferred to taking 1
- Free-guard-zone era effects: 3-rock → 4-rock → 5-rock; published rule-impact
  studies and federation responses; Grand Slam blank-end experiment (2024–25)
- "Miss up not down" / weight-bias heuristics; risk-vs-reward shot selection
- Mixed doubles strategic differences: positional stones, power-play timing
  research, single-shot blank dynamics
- Pre-game opponent prep (style, line preferences) and ice-tracking adjustment
  through a game
- Curling Canada NTP / WCF / national-program analytics infrastructure
  (Curling Canada Shot Tracker, CurlingZone TAP)

**Excludes:**
- Rule text and FGZ rule mechanics — see Notebook 1 (Rules)
- Stone physics, curl coefficients, friction — see Notebook 2 (Physics)
- Sweep-vs-no-sweep tactical microdecisions — see Notebook 3 (Sweeping)
- Shot taxonomy and definitions ("come-around", "hit-and-roll", "tap-back")
  — see Notebook 4 (Shot Taxonomy)
- Roles and shot-call protocol per position — see Notebook 6 (Player Roles)
- AI/MCTS/search-algorithm implementations of strategy — see Notebook 12
  (AI Opponent Design); this notebook is the *human framework* AI mimics

## Coverage Outline

### 1. Foundational analytics literature (Markov / state-space)
- Willoughby & Kostuk's foundational 2001/2004/2005/2006 series — first
  rigorous treatment of "blank vs. take 1" and "1-down hammer 9th" canonical
  decisions; the academic anchor for everything downstream.
- Brenzel/Shock/Yang 3-D Markov model (2019, J. Sports Analytics) on 10,933
  ends from the Brier — current canonical empirical state-space.
- Kostuk/Willoughby/Saedt 2001 European J. Operational Research paper —
  earliest Markov treatment, expected-point-differential framework.
- Fry et al. 2024 arXiv — maximum-entropy argument that scoring-end point
  distributions follow constrained geometric.
- "Curling Analysis based on the Possession of the Last Stone Per End" —
  binary logistic regression, hammer-as-explanatory-variable framing.

### 2. Modern descriptive metrics
- **Hammer Efficiency:** % of hammer ends scoring ≥2 (or "non-stolen
  multi-point"). Definitions vary (CurlingZone vs. doubletakeout); document
  both.
- **Steal Efficiency:** stolen ends / (ends without hammer including blanks).
- **Force Efficiency:** % of opponent-hammer ends held to ≤1.
- **Blank Rate / Blank Frequency:** by end, by score state, by team.
- **Hammer Factor** (Curl With Math) — alternative single-statistic capture
  of the hammer-game value.

### 3. Win-probability surfaces (the "WP grid")
- Canonical published values: tied 10th with hammer ≈ 75–80% W; 1-down
  hammer 9th ≈ 35% W (lowest WP for the trailing-with-hammer team in the
  game); tied with hammer to start ≈ 60.3% W.
- Live-WP systems: CurlingZone TAP, doubletakeout's "true win probability",
  Model 284's curling WP model — all use end-state empirical distributions.
- The 1-down-hammer-late-end blank-or-take debate — Willoughby/Kostuk show
  blanking the 9th dominates; Curl With Math reproduces this with WCT data.

### 4. Hammer / no-hammer playbook (the human framework)
- **With hammer, ahead:** safe, peel guards, force opponent to take 1.
- **With hammer, tied:** play for 2; the deuce dominates the take-1.
- **With hammer, down:** controlled risk; build a multi-stone end without
  giving up a steal.
- **Without hammer, ahead:** force opponent to 1; consider keeping the
  4-foot clean.
- **Without hammer, tied:** centerline guards, force a 1-point game (which
  flips the hammer to you tied).
- **Without hammer, down:** all guards, all ports, manufacture chaos —
  "losing by 1 or by 4 is the same."
- **Tied last end without hammer:** maximally aggressive — every guard, all
  centerline, accept risk.

### 5. Free Guard Zone era effects (rule-change analytics)
- 4-rock era (1991–2018, WCF): peeling guards on stones 3–4 was viable;
  defensive end-openings dominated.
- 5-rock era (2018–): cannot peel any front-of-tee stone until stone 6.
  doubletakeout: ends-opening-with-guard rose 42% → 57%; stone-5 hit rate
  dropped 64% → 42%; stones 6 and 8 hit rate rose to 68%.
- Tactical responses: delayed corner guards, double corner guards, "tick"
  shots, attack-the-side opening (Havercroft's four-strategy taxonomy).
- Grand Slam blank-end rule (2024–25 experiment): 1 blank max per team
  before hammer transfers — radically reshapes 1-down-hammer-9th decision.

### 6. Mixed doubles strategy
- Positional stones change the optimization completely; the game starts in
  a "shoot scoring" not "build position" frame.
- Power-play option: once-per-game, shifts the two pre-placed stones; +0.29
  EP on the end on average but real option value to deferring it.
- Wharton 2024 XGBoost study (Elder/Hossain/Pipping): optimal usage is
  saved through end 6, deployed in 7–8; observed Olympic-level usage
  ranges from near-optimal (Canada) to substantially sub-optimal (others).
- MIT Sloan 2018 power-play paper — earlier WP-based treatment.

### 7. Coaching-tradition heuristics (cross-checked against analytics)
- **"Miss up, not down":** missing heavy on a draw is recoverable; missing
  light leaves a guard for the opponent. Confirmed empirically by
  Curl With Math's takeout-weight error analysis.
- **"Don't make the hard shot when an easy one will do":** Curl Tech and
  USCA Level I Instructor Manual. Top teams differentiate by *not missing
  easy shots*, not by making more hard ones.
- **"Skip's first job is to know what their team can throw":** matches the
  weight/finesse demand shift seen empirically under the 5-rock rule.

### 8. National-program analytics infrastructure
- **Curling Canada NTP** — Renee Sonnenberg as Performance Analyst; Curling
  Canada Shot Tracker is the standard in-event capture tool.
- **CurlingZone TAP** (Tracking Analytics Platform) — manually entered
  live shot tracking; the public-facing data pipe behind most analyst
  blogs.
- **WCF/World Curling** results database — championship-level results and
  shot-percentage stats; force/steal rate available per championship.

### 9. Coaching books and accessible references
- Russ Howard, *Curl to Win* — strategy chapters covering hammer
  management, end-by-end thinking, the deuce vs. blank logic. The most
  cited mass-market strategy book.
- USA Curling Level I Instructor Manual — basic-strategy chapter is the
  shared baseline used by club coaches in North America.
- NBC Olympics' curling-strategy explainer — the canonical broadcast-level
  framing for casual fans (useful for UI/coaching-line copy).

### 10. Practical implications for our sim
- The deuce vs. take-1 vs. blank decision must be modeled correctly: this
  is the highest-signal strategic test for any AI.
- Force/steal/hammer-efficiency metrics are cheap to compute from our
  game logs and let us A/B AI difficulty in published-stat language.
- The 5-rock FGZ rule is *the* current rule context; 4-rock-era papers
  remain valid for math but their tactical conclusions about peeling
  guards on stone 3–4 do not transfer.
- Mixed doubles is a separate optimization problem — do not assume
  4-stone-team strategy generalizes.

## Sources

Quality-tier preferences applied: peer-reviewed analytics first, then
credentialed analyst blogs, then federation/coaching publications, with
high-end journalism only where it documents otherwise-unpublished rule
changes. URLs spot-checked via WebFetch are marked [verified].

### Peer-reviewed / academic
1. **Brenzel, Shock & Yang (2019)** — "An analysis of curling using a
   three-dimensional Markov model," *J. Sports Analytics* 5: 101–119.
   <https://journals.sagepub.com/doi/10.3233/JSA-180279>
2. **Willoughby & Kostuk (2005)** — "An Analysis of a Strategic Decision
   in the Sport of Curling," *Decision Analysis*, INFORMS.
   <https://pubsonline.informs.org/doi/abs/10.1287/deca.1050.0032>
3. **Willoughby & Kostuk (2004)** — "Preferred Scenarios in the Sport of
   Curling," *Interfaces*, INFORMS.
   <https://pubsonline.informs.org/doi/10.1287/inte.1030.0049>
4. **Kostuk, Willoughby & Saedt (2001)** — "Modelling curling as a Markov
   process," *European J. Operational Research*.
   <https://www.sciencedirect.com/science/article/abs/pii/S0377221700002022>
5. **Clément (2012)** — "An Analysis of Curling Strategy," *J. Quantitative
   Analysis in Sports*.
   <https://www.degruyterbrill.com/document/doi/10.1515/1559-0410.1500/html>
6. **Fry, Lundh & Fry (2024)** — "Elementary econometric and strategic
   analysis of curling matches," arXiv:2406.18601.
   <https://arxiv.org/abs/2406.18601>
7. **"Curling Analysis based on the Possession of the Last Stone Per
   End"** — binary-logistic-regression treatment of hammer value.
   <https://www.sciencedirect.com/science/article/pii/S1877705813010795/pdf>
8. **Palmer & Geurts** — "The Evolution of Curling Analytics," MIT Sloan
   Sports Analytics Conference 2019. [verified] Reviews datasets, WP, and
   in-game decision evaluation (~16 decision points/end).
   <https://www.sloansportsconference.com/research-papers/the-evolution-of-curling-analytics>
9. **"Opening the House: Datasets for Mixed Doubles Curling"** — arXiv
   2025; CSAS-2026-data-challenge curated mixed-doubles dataset paper.
   <https://arxiv.org/html/2512.16574v2>
10. **Elder, Hossain & Pipping (Wharton SABI, 2024)** — "Pulling the Power
    Play: A Win Probability Strategy for Mixed Doubles Curling." [verified]
    XGBoost over CSAS-2026 mixed-doubles dataset; optimal deploy ends 7–8.
    <https://wsb.wharton.upenn.edu/pulling-the-power-play-a-win-probability-strategy-for-mixed-doubles-curling/>
11. **MIT Sloan 2018** — "More Effective Use of The Power Play in Mixed
    Doubles Curling."
    <https://www.sloansportsconference.com/event/more-effective-use-of-the-power-play-in-mixed-doubles-curling>
12. **"An examination of studies related to the sport of curling: a
    scoping review"** (PMC) — meta-overview of curling research streams,
    useful for finding less-cited analytics papers.
    <https://pmc.ncbi.nlm.nih.gov/articles/PMC10898248/>
13. **Springer (2019)** — "Study on Game Information Analysis for Support
    to Tactics and Strategies in Curling."
    <https://link.springer.com/chapter/10.1007/978-3-030-14526-2_9>

### Credentialed analyst blogs / Substacks
14. **DoubleTakeout.com — "The effect of the 5-rock rule"** (Ken Pomeroy).
    [verified] Quantifies the rule's tactical reshaping: guard openings
    42→57%, stone-5 hit rate 64→42%.
    <https://doubletakeout.com/blog/the-effect-of-the-5-rock-rule/>
15. **DoubleTakeout.com — "True win probability"** — methodology behind
    their live WP model.
    <https://doubletakeout.com/blog/true-win-probability/>
16. **DoubleTakeout.com — "13: Down 1 with or up 1 without?"** — empirical
    revisit of Willoughby/Kostuk's foundational question.
    <https://doubletakeout.com/blog/13-down-1-with-or-up-1-without/>
17. **Curl With Math (Kevin Palmer)** [verified] — long-running blog with
    closed-form analyses of "1-down hammer 9th," hammer factor, and the
    blank-vs-take-1 question.
    <http://curlwithmath.blogspot.com/>
18. **Curl With Math — "What strategy should I employ when one down with
    hammer in 9th end?"** — canonical reference for that decision.
    <http://curlwithmath.blogspot.com/2009/12/what-strategy-should-i-employ-when-one.html>
19. **Curl With Math — "Hammer Factor"** — proposes the unified
    hammer-value statistic.
    <http://curlwithmath.blogspot.com/2018/11/a-new-statistic-hammer-factor.html>
20. **Curling by the Numbers (Dale Neufeld, Substack)** — current,
    actively-updated team-level analytics columns on top men's and
    women's WCT teams.
    <https://curlingrocks.substack.com/>
21. **Jonathan Havercroft — "Five-Rock FGZ Strategies"** [verified]
    Four-strategy taxonomy for the 5-rock era opening.
    <https://www.jonathanhavercroft.com/curling/2018/8/10/five-rock-fgz-strategies>
22. **Model 284 — "Curling Win Probability Model"** — reproducible WP
    model write-up.
    <https://model284.com/my-model-monday-curling-win-probability-model/>

### Federation, coaching, broadcast
23. **Curling Canada NTP page** — National Team Program structure, naming
    Renee Sonnenberg as Performance Analyst and the Curling Canada Shot
    Tracker as the in-event capture tool.
    <https://www.curling.ca/becoming-team-canada/athlete-programs/national-team-program/>
24. **CurlingZone Analytics** — TAP shot-tracking platform, hammer/steal/
    force-efficiency definitions, "How Analytics Helped Win Olympic Gold"
    (KISS / Team Brad Gushue).
    <https://www.curlingzone.com/analytics.php>
    <https://www.curlingzone.com/post.php?postid=1660>
25. **Curling Canada — "Thiessen Blog: Five-rock FGZ a positive change for
    curling"** (2018) — federation-published rule-change rationale.
    <https://www.curling.ca/blog/2018/06/15/thiessen-blog-five-rock-fgz-a-positive-change-for-curling/>
26. **Russ Howard, *Curl to Win* (HarperCollins, 2007)** — most-cited
    mass-market strategy book; covers hammer management, deuce-vs-blank,
    end-by-end thinking. Author is a 2-time world champion + Olympic gold.
    <https://www.amazon.com/Curl-Win-Russ-Howard/dp/1443437476>
27. **USA Curling Level I Instructor Manual — Basic Curling Strategy
    chapter** — shared club-coach baseline.
    <https://southshorecurling.com/wp-content/uploads/2013/03/USA_Curling-basic_curling_strategy.pdf>
28. **Grand Slam of Curling — "How the GSOC is working to curtail blank
    ends"** (and follow-on "Eight Ends" analytics columns by Gerry
    Geurts/Devin Heroux) — primary documentation of the 2024–25
    blank-end-cap rule experiment, with first-event statistics.
    <https://www.thegrandslamofcurling.com/news/how-the-grand-slam-of-curling-is-working-to-curtail-blank-ends>
    <https://www.thegrandslamofcurling.com/news/eight-ends-intriguing-stats-from-gsocs-rule-changes>
29. **NBC Olympics — "Curling 101: Strategy and Techniques"** — broadcast-
    level synthesis; useful as a UI/copy reference for surfacing strategy
    explanations to casual players.
    <https://www.nbcolympics.com/news/curling-101-strategy-and-techniques>
30. **Wikipedia — "Curling" (strategy section)** — single allowed
    Wikipedia link; baseline definitions of hammer, FGZ, blank end.
    <https://en.wikipedia.org/wiki/Curling>

## Supplementary Sources (5)

*Scrape-tested additions, 2026-04-26. These cover gaps left by paywalled
INFORMS / Springer items in the main list — particularly open-access
analyst write-ups of the 5-rock-rule's empirical impact, recent (2024–26)
team-level analytics columns, and federation-adjacent coaching
frameworks. All five returned HTTP 200 and rendered substantive content
under WebFetch with no login wall.*

### S1. DoubleTakeout.com — "The effect of the 5-rock rule II" (Ken Pomeroy)
- **URL:** <https://doubletakeout.com/blog/the-effect-of-the-5-rock-rule-ii/>
- **Type:** analyst-blog
- **Why it matters:** Direct follow-up to source #14 (5-rock-rule Part I).
  Quantifies *scoring outcomes* of the rule change rather than just
  strategy shifts: blank ends ↓, big ends (≥3 hammer / ≥2 non-hammer)
  ↑, hammer-2 frequency ↓, steal frequency ≈ hammer-2; men's hammer
  win % rose to 63.8% post-rule while women's dropped to 60.0%. Useful
  cross-check against any AI rollout that claims to "play correctly
  under the 5-rock rule" — these are the empirical aggregates the AI's
  end-state distribution must reproduce.
- **Pre-flight:** verified HTTP 200 via WebFetch.

### S2. Glenn Paulley — "A Case Study with Scoring Metrics" (Throwing Rocks)
- **URL:** <https://glennpaulley.ca/curling/2026/01/22/a-case-study-with-scoring-metrics/>
- **Type:** analyst-blog (coach + ex-Waterloo CS PhD)
- **Why it matters:** Open-access, citation-style write-up of the four
  canonical metrics (hammer efficiency, steal defence, steal efficiency,
  force efficiency) plus the Combined Team Index, applied to the 2025
  OUA Women's University Curling Championship. Worked example we can
  mirror when we build our own per-game analytics dump from the sim's
  game logs. Explicitly traces metric provenance back to Linda Moore /
  Gerry Geurts / Dallas Bittle — fills the gap left by the paywalled
  CurlingZone definitions in source #24.
- **Pre-flight:** verified HTTP 200 via WebFetch.

### S3. Glenn Paulley — Strategy index (Throwing Rocks)
- **URL:** <https://glennpaulley.ca/curling/strategy/>
- **Type:** analyst-blog (index)
- **Why it matters:** Hub for Paulley's strategy archive — distinguishes
  "strategy" (game plan + shot called in light of it) from "tactics"
  (shot execution), which is the cleanest definitional split we've seen
  in the public coaching literature. Sibling articles cover game
  charting, *What's Your Call?* scenario reviews, and the
  metrics-vs-video-analysis seam. Useful as a coverage map: any topic
  Paulley's archive treats but our notebook hasn't is a candidate
  research gap.
- **Pre-flight:** verified HTTP 200 via WebFetch.

### S4. Curling by the Numbers — "Comparing the analytics of the top men's Curling Teams in the World" (Dale Neufeld, Feb 2025)
- **URL:** <https://curlingrocks.substack.com/p/comparing-the-analytics-of-the-top>
- **Type:** analyst-blog (Substack)
- **Why it matters:** Concrete worked example of source #20's framework
  applied to the top-15 men's WCT teams as of the 2024–25 season. Lists
  the With-Hammer Index, Without-Hammer Index, and Team Efficiency
  composite for each team with Mouat as the empirical ceiling
  (WHI .469 / WiHI .994 / TE 2.313). These are the realistic upper-end
  numbers our "Hard" AI tier should approach; anything above them in
  AI vs AI logs is a sign the metric is being gamed or the difficulty
  is mis-calibrated.
- **Pre-flight:** verified HTTP 200 via WebFetch.

### S5. CurlingPool.com — Live Win-Probability Analytics
- **URL:** <https://www.curlingpool.com/analytics>
- **Type:** analyst-blog / public stat dump
- **Why it matters:** Open-access live-WP service computed as
  P(win) = games_won_at_(point_diff, hammer) / games_at_(point_diff,
  hammer) over post-2018 (5-rock-era) Brier / Scotties / Worlds /
  Canada Cup data. Independent third-party confirmation of the
  empirical WP grid we cite from doubletakeout (#15) and Model 284
  (#22) — when three independent sources agree on tied-10th-with-hammer
  ≈ 0.78–0.80 W, that's the value our AI's terminal evaluation should
  match.
- **Pre-flight:** verified HTTP 200 via WebFetch.
