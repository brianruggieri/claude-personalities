# AI Opponent Design

Computational agents for curling: shot-selection algorithms, simulators used
to train them, and the techniques (continuous-action MCTS, kernel-regression
UCT, deep RL with self-play, opponent modeling) that the published curling-AI
literature has converged on. Excludes the human strategy framework itself —
that's Notebook 5. This notebook is about *the algorithms*.

---

## How to use this notebook

Three audiences:

1. **AI plugin agent (`src/ai/`)** — the curling-AI canon: KR-UCT, KR-DL-UCT,
   action-selection-for-hammer-shots, NFSP. These are the load-bearing papers
   when extending shot search, evaluation functions, or self-play training.
2. **Performance / latency work** — continuous-action MCTS variants
   (progressive widening, double progressive widening, KR-UCT) and the
   tradeoffs each makes for budget-bounded search. Cross-reference with the
   `MCTS Latency Over Budget` memory note.
3. **Difficulty calibration / archetype design** — opponent-modeling and
   DDA literature for layering noise and skill on top of an optimal policy.
   Distinct from Notebook 5's tactical principles: this is *how* you make a
   "Conservative Hard" agent computationally, not what conservative play
   looks like on the ice.

When in doubt, prefer the **digitalcurling** GitHub org and the **IJCAI
2016 / ICML 2018** curling papers — they are the academic backbone of the
field. The University of Alberta GAMES Group (Bowling, Holte, Ahmad, Lelis,
Yee, Lisý) is the other major hub.

---

## 1. The Digital Curling simulator (canonical training environment)

The reference simulator that essentially every published curling-AI paper
since 2015 has either used or compared against. C++, MIT-licensed, plugin
architecture, FCV1 physics model. Hosted by the **digitalcurling**
organization out of UEC / Hokkaido.

- [DigitalCurling GitHub organization](https://github.com/digitalcurling) —
  10+ repos: simulator core, server, client SDKs, sample AIs.
- [digitalcurling/DigitalCurling (main repo)](https://github.com/digitalcurling/DigitalCurling)
  — C++ platform, MIT license, supports 4-player and mixed-doubles rules,
  cross-platform.
- [Ito 2015 — "Digital Curling" CIG paper (CiNii index)](https://cir.nii.ac.jp/crid/1050574047074869376)
  — Takeshi Ito (UEC) introduced the framework at IEEE CIG 2015; it became
  the GAT tournament standard the next year.
- [GAT @ UEC tournament site (background)](https://xfuture.info/en/curling/)
  — Takegawa Lab summary of the Game AI Tournament @ University of
  Electro-Communications, including digital curling as an annual event.
- [UNIST wins 2018 GAT digital curling tournament (EurekAlert)](https://www.eurekalert.org/news-releases/900639)
  — coverage confirming the KR-DRL-MES program won the international
  tournament; useful provenance for KR-DL-UCT's empirical claims.

## 2. Curling-AI canon (peer-reviewed, MUST-read)

Six papers form the spine. Read in this order if starting cold.

- [Yee, Lisý, Bowling 2016 — "Monte Carlo Tree Search in Continuous Action Spaces with Execution Uncertainty" (IJCAI)](https://www.ijcai.org/Proceedings/16/Papers/104.pdf)
  — **The KR-UCT paper.** Frames curling as continuous-action / continuous-stochastic
  outcome / sequential / adversarial. Introduces kernel-regression-augmented UCT
  and demonstrates statistically significant point-differential gains over cRAVE
  and prior baselines. University of Alberta + Czech Technical University.
- [Ahmad, Holte, Bowling 2016 — "Action Selection for Hammer Shots in Curling" (IJCAI)](https://www.ijcai.org/Proceedings/16/Papers/086.pdf)
  — Companion paper: the hammer-shot decision treated as its own bandit
  problem. Reports statistically significant improvement over Olympic-level
  human teams on hammer states. Direct evidence that targeted, narrower-than-
  full-game search is enough to beat humans on the consequential final shot.
- [Lee, Kim, Choi, Lee 2018 — "Deep Reinforcement Learning in Continuous Action Spaces: a Case Study in the Game of Simulated Curling" (ICML)](https://proceedings.mlr.press/v80/lee18b.html)
  — **KR-DL-UCT.** Pairs a policy-value network with KR-UCT; trained by
  supervised pre-training then 5M-shot self-play on the Digital Curling
  simulator. Won GAT-2018 as KR-DRL-MES. The bridge from KR-UCT to
  AlphaZero-style learning for continuous-action sports.
- [Lee project page — KR-DL-UCT (code, slides, video)](https://leekwoon.github.io/projects/kr-dl-uct/)
  — author's site with implementation notes and 53% (supervised) vs 66%
  (self-play 5M shots) win-rate against the DL-UCT baseline.
- [leekwoon/KR-DL-UCT (GitHub)](https://github.com/leekwoon/KR-DL-UCT) —
  open-source reference implementation. Useful for understanding the
  policy-value head shapes and the kernel-density-estimate book-keeping
  inside the MCTS loop.
- [Won, Müller, Lee 2020 — "An adaptive deep reinforcement learning framework enables curling robots with human-like performance in real-world conditions" (Science Robotics)](https://www.science.org/doi/10.1126/scirobotics.abb9764)
  — The **Curly** robot. Adaptive DRL with temporal features that compensate
  for ice nonstationarity; beat top-ranked human teams 3 of 4 official matches.
  Closes the loop from simulator to physical hardware.
- [Liu et al. 2021 — "A game strategy model in the digital curling system based on NFSP" (Complex & Intelligent Systems, Springer)](https://link.springer.com/article/10.1007/s40747-021-00345-6)
  — Combines Neural Fictitious Self-Play (Heinrich & Silver) with KR-UCT to
  approximate Nash equilibrium in the two-player zero-sum extensive-form game
  of digital curling. Reservoir sampling + anticipatory dynamics.

## 3. Continuous-action MCTS theory (non-curling, but load-bearing)

Curling search is a special case of "continuous action, stochastic
outcome" tree search. These are the foundational papers MCTS-with-curling
builds on.

- [Couëtoux et al. 2011 — "Continuous Upper Confidence Trees with Polynomial Exploration — Consistency"](https://www.researchgate.net/publication/279257698_Continuous_Upper_Confidence_Trees_with_Polynomial_Exploration_-_Consistency)
  — The progressive-widening / continuous-UCT consistency proof. Cited by
  every subsequent continuous-action MCTS paper including Yee 2016.
- [Couëtoux et al. 2011 — "Continuous Rapid Action Value Estimates" (cRAVE)](http://proceedings.mlr.press/v20/couetoux11/couetoux11.pdf)
  — cRAVE, the continuous version of Gelly & Silver's RAVE; the immediate
  baseline KR-UCT outperforms in the Yee paper.
- [Auger et al. — "Continuous Upper Confidence Trees" / Double Progressive Widening notes (DPW reference, julia POMDPs)](http://juliapomdp.github.io/MCTS.jl/latest/dpw/)
  — Practical write-up of double progressive widening: gradually expand both
  the action-branching factor and observation-branching factor. Useful when
  *both* shot intent and stone outcome are continuous (i.e. always, in curling).
- [Gelly & Silver 2011 — "Monte-Carlo Tree Search and Rapid Action Value Estimation in Computer Go"](https://www.cs.utexas.edu/~pstone/Courses/394Rspring13/resources/mcrave.pdf)
  — RAVE / AMAF. Discrete-action precursor; explains the "share statistics
  between similar moves" idea that KR-UCT generalizes to a continuous kernel.
- [Cazenave 2015 — "Generalized Rapid Action Value Estimation" (IJCAI)](https://www.ijcai.org/Proceedings/15/Papers/112.pdf)
  — GRAVE. Useful background on how RAVE-family heuristics compose with
  selection rules; informs how to weight sibling-shot statistics in budget-
  constrained curling search.
- [Cowling, Powley, Whitehouse 2012 — "Information Set Monte Carlo Tree Search" (IEEE TCIAIG)](https://ieeexplore.ieee.org/document/6203567/)
  — ISMCTS. Curling is fully observable, so this is *adjacent* — but if you
  ever model imperfect-information variants (hidden ice condition, opponent
  intent priors) ISMCTS is the framework.
- [Moerland et al. 2018 — "A0C: Alpha Zero in Continuous Action Space"](https://arxiv.org/pdf/1805.09613)
  — Generalizes AlphaZero's MCTS+NN loop to continuous actions via
  progressive widening on policy-network samples. Direct cross-reference
  with KR-DL-UCT — different sample-distribution choices, similar architecture.

## 4. Curling analytics & evaluation-function inputs

The data side: what's been measured, what positional-value functions have
been fit. Useful when shaping reward signals or hand-crafting features.

- [Sloan Sports — "The Evolution of Curling Analytics" (Myslik 2020)](https://www.sloansportsconference.com/research-papers/the-evolution-of-curling-analytics)
  — Survey of state-of-the-art shot-tracking, expected-end-value, and shot-success
  models. The closest thing to an "Elias / Pinnacle" reference for curling.
- [Myslik portfolio — Curling Analytics](https://www.jordanmyslik.com/portfolio/curling-analytics/)
  — Author's project pages including expected-points-by-end-state heatmaps.
- [Honda & Itahashi 2024 — "Creation of Training Data and Training for Prediction Model of Curling" (SciTePress)](https://www.scitepress.org/Papers/2024/129411/129411.pdf)
  — Trains a neural evaluation function on real game data rather than
  simulator-generated shots; reports better fit to realistic positions.
  Direct evidence that simulator-only training under-covers the position
  distribution.
- [CurlingZone Analytics portal](https://www.curlingzone.com/analytics.php)
  — Closed/proprietary but the canonical industry shot-tracking source;
  TAP (Tactical Analysis Program) is the de facto reference dataset.
- [DoubleTakeout — "Exploring shot data" blog](https://doubletakeout.com/blog/25-exploring-shot-data/)
  — Open-data exploration of CurlingZone-style shot logs.
- [Opening the House — "Datasets for Mixed Doubles Curling" (arXiv 2025)](https://arxiv.org/html/2512.16574v2)
  — Recent open dataset specifically for mixed-doubles, including labeled
  shot intents and outcomes. Scarce in curling-AI literature so far.

## 5. Difficulty calibration & opponent modeling

Layering archetype/skill on top of an optimal-or-near-optimal policy. The
canonical pattern: optimal policy + parameterized noise + behavioral filter.

- [Zohaib 2018 — "Dynamic Difficulty Adjustment in Computer Games: A Review" (Adv. HCI)](https://onlinelibrary.wiley.com/doi/10.1155/2018/5681652)
  — The standard DDA survey. Sections on "behavioral parameter tuning"
  (speed/latency/noise) vs "model swap" (multiple trained agents) are the
  two patterns most useful for curling difficulty tiers.
- [Moon et al. 2022 — "Diversifying dynamic difficulty adjustment agent by integrating player state models into MCTS" (Expert Systems with Applications)](https://www.sciencedirect.com/science/article/abs/pii/S0957417422009757)
  — DDA-by-MCTS-modulation: modify selection rule rather than adding output
  noise. Better fit for curling than naive aim-noise because it preserves
  shot-type diversity.
- [Bakkes et al. — "Opponent modelling for case-based adaptive game AI"](https://www.researchgate.net/publication/222421745_Opponent_modelling_for_case-based_adaptive_game_AI)
  — Case-based opponent modeling. Useful when an archetype agent ("takeout-
  heavy", "draw-heavy") should *adapt* to the human's pattern, not just
  emit a fixed strategy.
- [Albrecht & Stone 2018 — "Autonomous agents modelling other agents: A comprehensive survey" (JAIR)](https://jair.org/index.php/jair/article/download/12889/26762/29406)
  — Comprehensive opponent-modeling survey across game/agent domains.
  Reference taxonomy when designing personality-tagged opponents.
- [Lockett, Chen, Miikkulainen 2007 — "Evolving Explicit Opponent Models in Game Playing" (GECCO)](https://nn.cs.utexas.edu/downloads/papers/lockett-gecco07.pdf)
  — Neural-evolution of opponent models. Niche but foundational for the
  "infer opponent's policy from a small history" problem.

## 6. Adjacent / cross-pollination references

Game-AI techniques curling AI papers explicitly cite or that map onto
curling's structure (continuous, stochastic, two-player zero-sum, fully
observable per-shot).

- [Silver et al. 2018 — "A general reinforcement learning algorithm that masters chess, shogi, and Go through self-play" (Science)](https://www.science.org/doi/10.1126/science.aar6404)
  — AlphaZero. The discrete-action ancestor; KR-DL-UCT, A0C, and the NFSP
  curling paper all explicitly position themselves as continuous-action
  generalizations.
- [Brown et al. 2020 — "Combining deep reinforcement learning and search for imperfect-information games" (NeurIPS)](https://dl.acm.org/doi/10.5555/3495724.3497155)
  — ReBeL. Imperfect-information adjacent; relevant if you ever model the
  opponent-strategy distribution as hidden state.
- [Heinrich & Silver 2016 — "Deep reinforcement learning from self-play in imperfect-information games" (NFSP)](https://arxiv.org/abs/1603.01121)
  — The original NFSP paper that the digital-curling NFSP work builds on.
  (Listed because the curling NFSP paper assumes you've read it.)
- [Monte Carlo Tree Search — Wikipedia](https://en.wikipedia.org/wiki/Monte_Carlo_tree_search)
  — Single allowed Wikipedia entry; canonical overview of UCT/UCB1, useful
  as a one-stop landmark reference.

---

## Cross-references inside this repo

- `MCTS Latency Over Budget` (memory) — the budgets that any continuous-action
  search algorithm has to respect on this codebase.
- `40-Game Test Structurally Broken` (memory) — why simulator-vs-simulator
  win rate is a noisy proxy for shot-selection quality; the Honda 2024 paper
  in §4 echoes this in the literature.
- `src/ai/RESEARCH.md` — when present, plugin-local notes that should cite
  back into this notebook.
- Notebook 2 (Physics) — KR-UCT and KR-DL-UCT both assume a deterministic
  forward simulator with a Gaussian execution-noise model on top; that's
  the simulator contract our `src/physics/` plugin must satisfy for any of
  these algorithms to drop in.
- Notebook 5 (Strategy) — the *what to play* layer that an evaluation
  function in §4 needs to encode. Tactical-principle references live there;
  algorithmic references live here.

## Spot-check log

Six URLs verified live during seed (2026-04-26):

1. `ijcai.org/Proceedings/16/Papers/104.pdf` — confirmed Yee/Lisý/Bowling 2016, IJCAI.
2. `github.com/digitalcurling/DigitalCurling` — confirmed C++ MIT-licensed
   simulator, FCV1 physics, 4-player + mixed-doubles support.
3. `leekwoon.github.io/projects/kr-dl-uct` — confirmed ICML 2018 authorship
   (Lee, Kim, Choi, Lee), 53% / 66% win-rate numbers.
4. `ijcai.org/Proceedings/16/Papers/086.pdf` — confirmed Ahmad/Holte/Bowling
   2016 hammer-shot paper, IJCAI.
5. `link.springer.com/article/10.1007/s40747-021-00345-6` — confirmed via
   search snippet (Springer 303-redirected the WebFetch); NFSP+KR-UCT for
   digital curling.
6. `science.org/doi/10.1126/scirobotics.abb9764` — confirmed via PubMed
   mirror (`pubmed.ncbi.nlm.nih.gov/32967991`) and Science page metadata
   (Science Robotics 2020, Won/Müller/Lee).

If a future maintainer finds a dead link, the academic papers above are all
also discoverable by DOI / Google Scholar; the GitHub orgs (digitalcurling,
leekwoon) are the most stable anchors.

---

## Supplementary Sources (5)

*Scrape-tested additions, 2026-04-26. Targets open-access alternatives to the
paywalled Science Robotics direct link for Won 2020 (Curly), plus recent
continuous-action MCTS theory and the 2024 self-play canon that any
KR-DL-UCT successor will reference.*

### S1. Won, Müller, Lee 2020 — full PDF mirror (Science Robotics, Curly robot)
- **URL:** https://gwern.net/doc/reinforcement-learning/robot/2020-won.pdf
- **Type:** paper (open mirror)
- **Why it matters:** The original §2 entry routes through the Science.org paywall
  (403 to scrapers). Gwern hosts the full Science Robotics PDF with metadata
  intact (verified: title "An adaptive deep reinforcement learning framework
  enables curling robots with human-like performance in real-world conditions",
  authors Won/Müller/Lee, Sci. Robotics 5:46, 2020). This is the canonical
  fall-back for citing Curly's adaptive-DRL framework and temporal-feature
  ice-nonstationarity story without hitting the paywall.
- **Pre-flight:** verified HTTP 200 via WebFetch (1.2 MB PDF, decompressible).

### S2. Won et al. 2018 — "Curly: An AI-based Curling Robot Successfully Competing in the Olympic Discipline of Curling" (IJCAI demo track)
- **URL:** https://www.ijcai.org/proceedings/2018/0870.pdf
- **Type:** paper (IJCAI proceedings, open access)
- **Why it matters:** The IJCAI 2018 demo paper introduces Curly's hardware/software
  stack two years before the Science Robotics journal paper. Useful when the
  question is *system architecture* — vision pipeline, throwing-arm calibration,
  state estimation, simulator-to-real loop — rather than the adaptive-DRL
  algorithm itself. Same author team (Won, Kim et al.). Direct PDF on
  ijcai.org (the most stable open-access proceedings host in game AI).
- **Pre-flight:** verified HTTP 200 via WebFetch (PDF, ~290 KB, content matches
  the AI Curling Robot system description).

### S3. Lim, Tomlin, Sunberg 2021 — "Voronoi Progressive Widening" (arXiv 2012.10140)
- **URL:** https://arxiv.org/abs/2012.10140
- **Type:** preprint (arXiv cs.AI)
- **Why it matters:** Modern continuous-action MCTS variant beyond the 2011
  Couëtoux double-progressive-widening listed in §3. Introduces VOWSS (with
  convergence guarantees for continuous state/action/observation POMDPs) and
  VOMCPOW. Replaces uniform action sampling with Voronoi-cell-driven
  optimistic optimization — directly applicable to curling-shot search where
  the action density should follow informativeness, not uniformity. Cleanly
  generalizes / supersedes parts of the §3 reading list for any new
  continuous-action search prototype on this codebase.
- **Pre-flight:** verified HTTP 200 via WebFetch; abstract and metadata
  confirmed (Lim/Tomlin/Sunberg, 2020 submission, 2021 final).

### S4. Lipardi et al. 2025 — "Quantum Circuit Design using a Progressive Widening Enhanced Monte Carlo Tree Search" (arXiv 2502.03962)
- **URL:** https://arxiv.org/abs/2502.03962
- **Type:** preprint (arXiv cs.AI)
- **Why it matters:** Recent (Feb 2025) progressive-widening MCTS in a domain
  whose action structure — sampling continuous parameters per discrete action
  primitive — mirrors curling's shot-type × intent-vector decomposition.
  Authors include Mark Winands (Maastricht, MCTS canon). Demonstrates the
  modern PW formulation on a non-game domain, useful as a contrast to
  Yee 2016's KR-UCT and to A0C/KR-DL-UCT. Cite when designing a PW schedule
  for our `src/ai/` MCTS budget that has to share between candidate-shot
  enumeration and Gaussian-noise outcome sampling.
- **Pre-flight:** verified HTTP 200 via WebFetch; title/authors/abstract
  confirmed.

### S5. Zhang et al. 2024 — "A Survey on Self-play Methods in Reinforcement Learning" (arXiv 2408.01072)
- **URL:** https://arxiv.org/abs/2408.01072
- **Type:** survey (arXiv cs.LG, August 2024, revised October 2025)
- **Why it matters:** The first comprehensive self-play survey post-AlphaZero.
  Provides the modern taxonomy (PSRO, Fictitious Play, NFSP, league-based
  training) that the §2 Liu 2021 NFSP curling paper sits inside. Useful when
  evaluating whether to extend KR-DL-UCT's plain self-play with population-based
  / opponent-modeling-aware variants for difficulty-tier diversity (cross-ref
  §5 of this notebook). 11 authors, 100+ pages of taxonomy + bibliography —
  the right entry point for "what is the 2024 state of the art for two-player
  zero-sum self-play, and which variant fits curling's continuous-action
  / fully-observable / Gaussian-noise structure?"
- **Pre-flight:** verified HTTP 200 via WebFetch; title and author list
  confirmed.
