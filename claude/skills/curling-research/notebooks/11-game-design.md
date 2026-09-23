# Game Design: Curling Video Games & Sports-Sim Patterns

Scope: a survey of every notable curling video game (PC sims, motion-control titles, mobile, indie, accessibility-focused) plus the sports-simulation design patterns from neighbouring genres (golf, tennis, pool, bowling, manager sims) that inform the control scheme, onboarding, replay, and arcade-vs-sim tradeoffs for our project. Excludes the AI inside those games (see Notebook 12) and the underlying physics literature (see Notebook 2).

---

## A. Curling video games — primary references

### A1. Take-Out Weight Curling (2002, PC) — the first 3D curling sim
- MobyGames entry — design credits, screenshots, scope: <https://www.mobygames.com/game/8326/take-out-weight-curling/>
- Eli's Software Encyclopedia (Global Star Software 2002 release notes, including the click-and-drag aim/weight UI screenshots): <http://elisoftware.org/w/index.php/Curling:_Take-Out_Weight_(PC,_CD-ROM)_Global_Star_Software_-_2002_USA,_Canada_Release>
- Internet Archive playable build (useful for direct UI study without buying retail media): <https://archive.org/details/TakeOutWeight_Curling>
- Metacritic aggregate (sparse but documents that this title shipped with team creation, tournament play, and GameSpy net play — features later titles dropped): <https://www.metacritic.com/game/take-out-weight-curling/>

### A2. Curling 2010 / Curling 2012 / "Take-Out Weight" 2 (Eldos / DTP / Dadoo lineage)
- Giant Bomb wiki (canonical metadata for the Curling 2010 Xbox Live Indie Games release): <https://giantbomb.com/wiki/Games/Curling_2010>
- GameZone capsule + screenshots (XBLIG release context — the title shipped at the bottom of the indie tier and was widely panned for unforgiving physics calibration): <https://www.gamezone.com/games/curling-2010/>
- Gamepressure — Curling 2012 (Eldos-published successor, useful as a retrospective on the same engine across releases): <https://www.gamepressure.com/games/curling-2012/zd3145>
- Gamereactor "Get some indie curling now!" announcement and post-launch impressions: <https://www.gamereactor.eu/get-some-indie-curling-now/>

### A3. Curling World Cup (Simulators Live, 2018, Steam) — modern dedicated sim
- Steam page: <https://store.steampowered.com/sub/263913>
- Pixel Empire review — key quote on UX and shot-feel: <https://www.thepixelempire.net/curling-world-cup-pc-review.html>
- Gamers Heroes review — physics-broken assessment, "most shots end up feeling like a crapshoot, with no amount of planning helping you get your rock where it needs to go": <https://www.gamersheroes.com/honest-game-reviews/curling-world-cup-review/>
- SteamSpy install/owner data (signal on commercial size of the curling-sim niche on Steam): <https://steamspy.com/app/844310>

### A4. Let's Play Curling!! (Crescent, Switch, 2022)
- WayTooManyGames review — most useful single reference on the motion-sweep problem: praises throw mechanic as "surprisingly intuitive" but says sweeping motion "is painful and exhausting" and the reviewer fell back on button-mashing. Also notes a penguin-themed minigame that effectively turns curling into bowling — a pattern worth stealing for our Hot Shots / puzzle mode: <https://waytoomany.games/2022/11/08/review-lets-play-curling/>
- Metacritic aggregate: <https://www.metacritic.com/game/lets-play-curling/>
- OpenCritic: <https://opencritic.com/game/13966/lets-play-curling-/reviews>

### A5. Curl! (Steam Early Access) — accessibility-first curling
- Steam page (BCI/Emotiv integration, switch-access UI, up to 4 BCI headsets per machine, "first of its kind to enable full BCI integration directly within the game, including headset connection, calibration, training, and direct thought-to-action play"): <https://store.steampowered.com/app/2100970/Curl/>
- Steam Community discussions (active dev presence, control-scheme tuning logs): <https://steamcommunity.com/app/2100970/discussions/>

### A6. Other dedicated curling SKUs (catalog)
- VR Curling (Steam): <https://store.steampowered.com/app/959920/VR_Curling/> — useful study of release-arm mapping when the controller is a literal hand
- Curling On Line (Steam): <https://store.steampowered.com/app/1372840/Curling_On_Line/>
- Pro Stone Curling (Steam): <https://store.steampowered.com/app/4194710/Pro_Stone_Curling/> — small-but-positive Steam review pool
- Curling Multiplayer (Xbox): <https://www.xbox.com/en-US/games/store/curling-multiplayer/9NCW7RZDQ098>
- Curling 3D (Google Play, Giraffe Games): <https://play.google.com/store/apps/details?id=com.giraffegames.curling> — representative of the swipe-to-throw mobile pattern

### A7. Curling inside compilation titles (motion-control era)
- Mario & Sonic at the Olympic Winter Games (Wii) — curling minigame entry: <https://www.mariowiki.com/Curling_(Mario_%26_Sonic_at_the_Olympic_Winter_Games_for_Wii)>
- Mario & Sonic at the Sochi 2014 Olympic Winter Games (Wii U) — Wikipedia: <https://en.wikipedia.org/wiki/Mario_%26_Sonic_at_the_Sochi_2014_Olympic_Winter_Games>
- Deca Sports (Wii) — the "press and hold for power, flick remote to release, shake to sweep" canon, capsule on Siliconera: <https://www.siliconera.com/curling-without-being-cold-deca-sportas-winter-games/>
- Christian Science Monitor "Wii curling: Let the giggle games begin" — contemporaneous mainstream-press write-up of the 2010 Olympic-driven curling-game wave: <https://www.csmonitor.com/Technology/Horizons/2010/0219/Wii-curling-Let-the-giggle-games-begin>

### A8. Single best retrospective on curling-as-video-game
- squareblind, "Winter Olympic Curling: the greatest videogame sport of the motion control era" (2018) — argues curling's role-divided team structure (skip aims, thrower slides, two sweepers flail) is the single best fit anyone ever found for Wii/Wii U motion controllers, and that the cooperative-flailing dynamic is the design lever that makes curling more fun in living-room party form than golf or baseball. Critical reading: <https://squareblind.wordpress.com/2018/02/25/winter-olympic-curling-the-greatest-videogame-sport-of-the-motion-control-era/>

---

## B. Sports-sim design patterns that translate to curling

### B1. The 3-click swing meter (golf canon)
- PGA Tour 2K23 / 2K25 official explainers — the modern reference implementation of "press to start, release at top for power, time the click on the way down for accuracy": <https://pgatour.2k.com/2k23/up-your-game/3-click-swing/> and <https://pgatour.2k.com/2k25/up-your-game/how-to-swing/>
- GameSpot — EA Sports PGA Tour adopting a 3-click option (signal that even cinematic-stick-driven golf games keep the 3-click meter on offer for legacy and accessibility): <https://www.gamespot.com/articles/ea-sports-pga-tour-update-adds-3-click-swing-system-and-tons-more-good-improvements/1100-6513432/>
- Direct relevance to curling: the 3-click loop maps cleanly to (1) commit to throw, (2) release weight, (3) time the rotation/accuracy — and is the strongest baseline for a keyboard or single-button control scheme.

### B2. Mario Golf — power+spin layered onto the meter
- Power Shot mechanic (Super Mario Wiki) — six "power shots" per round, perfect-timed releases get refunded back to the pool: a generous design pattern for letting good play feel rewarding without breaking shot-budget pacing: <https://www.mariowiki.com/Power_Shot_(Mario_Golf_series)>
- Mario Golf: Super Rush controls reference (Game8) — left-stick shot-shape input *before* the swing arc, plus topspin/backspin/super-backspin layered after the power lock: <https://game8.co/games/Mario-Golf-Super-Rush/archives/333996>
- Direct relevance: Mario Golf separates *intent* (shape pre-swing) from *execution* (timing the meter). Curling can do the same: pick handle/weight/line during aiming, then execute with a single timed input.

### B3. Top Spin tennis — timing window as primary skill axis
- Top Spin 2K25 controls guide (GINX) — every shot is a hold-the-shot-button-for-the-right-duration check; the green sweet-spot window on the timing meter *is* the skill curve: <https://www.ginx.tv/en/topspin-2k25/controls>
- WayTooManyGames Top Spin 2K25 review (timing meter as the entire game-feel hinge): <https://waytoomany.games/2024/04/26/review-top-spin-2k25/>
- Top Spin (original, 2003) Wikipedia entry — historical reference for risk-shots that widen power but tighten the timing window (analogous to a heavy take-out vs a draw to the button): <https://en.wikipedia.org/wiki/Top_Spin_(video_game)>

### B4. Wii Sports Bowling — release timing on a gesture controller
- Wii Sports Bowling design (Wii Sports Wiki) — D-pad chooses angle and lateral position *before* the throw; release timing on the swing-up gesture decides spin and direction. This is the same 4-DOF compression curling needs (line, weight, handle, release point): <https://wiisports.fandom.com/wiki/Bowling_(sport)>
- Wikibooks tutorial walkthrough (documents the exact onboarding sequence Nintendo used): <https://en.wikibooks.org/wiki/Wii_Sports/Bowling>
- T-Minus Countdown retrospective on why Wii Bowling broke through to non-gamers (relevant for our accessibility / family-mode plans): <https://www.t-minuscountdown.com/wii-sports-bowling/>

### B5. Pool / billiards aiming UIs
- Dr. Dave Pool Info — comprehensive index of real-world aiming systems (ghost-ball, parallel, CTE) that pool video games translate into UI overlays: <https://drdavepoolinfo.com/tutorial/how-to-aim/>
- Collection Chamber — Virtual Pool (1995) retrospective: still the gold-standard reference for the "drag the cue back, release to strike" mouse-driven control scheme; widely cribbed since: <https://collectionchamber.blogspot.com/p/virtual-pool.html>
- Yakuza 0 / Pirate Yakuza pool minigame — analog-stick draw-and-release; community guides discuss how horizontal-stick over-sensitivity makes the game feel hostile (design lesson: the mapping curve from stick magnitude to power/aim deserves explicit tuning, not just a linear pass-through): <https://gamefaqs.gamespot.com/ps5/487752-like-a-dragon-pirate-yakuza-in-hawaii/faqs/81725/pool> and the Steam guide on rebinding: <https://steamcommunity.com/sharedfiles/filedetails/?id=2389556285>

### B6. Football Manager / Out of the Park Baseball — abstract-presentation sims
- Out of the Park Baseball 25 review (Operation Sports) on managerial depth and how presentation-light sims keep hardcore audiences for years on text + 2D field views: <https://www.operationsports.com/out-of-the-park-baseball-25-review-an-impressively-deep-managerial-experience/>
- InsideHook — actual MLB front-office staff using OOTP for analysis (real-world validation that "abstract presentation + deep simulation" is a viable hardcore tier): <https://www.insidehook.com/sports/mlb-managers-play-video-games-too>
- Direct relevance: a "skip mode" or strategy-only curling experience — pick rock, set ice, AI throws — is a viable second product alongside the realtime sim, not a contradiction of it.

### B7. Ernest Adams, Designer's Notebook — "Designing and Developing Sports Games"
- Game Developer (formerly Gamasutra) — the canonical design-essay reference for sports-game first principles: <https://www.gamedeveloper.com/design/the-designer-s-notebook-designing-and-developing-sports-games>
- Three load-bearing claims to read directly:
  1. Sports games are held to a higher accuracy bar than any other genre because the audience knows the sport. The official rulebook is mandatory reading.
  2. Strict realism causes user frustration — bake in difficulty knobs ("how tough were the referees") rather than choosing one position.
  3. Real-life athletic timing windows are too small for casual control. Adams' baseball example: a fastball is hittable for ~0.04s. Designers must "fudge these numbers" — slower pitches, expanded hit zones — and then layer skill-floor mechanics back on top.
- Adams' broader column index: <http://www.designersnotebook.com/Columns/columns.htm>

### B8. Gamasutra/Game Developer general sports-design references
- Designer's Notebook "Ten Years Of Great Games" retrospective (places sports-sim canon in the broader column lineage): <https://www.gamedeveloper.com/design/the-designer-s-notebook-ten-years-of-great-games>
- Steve Vincent CAP211 sports-game lecture notes — useful sport-by-sport breakdown of which control schemes maps to which sport (golf=meter, tennis=timing, basketball=icon-pass, football=playcalling): <https://stevevincent.info/CAP211_2012GameDesign5.htm>
- gamedesignskills.com — "Sports Game Design (Principles, Examples, Template)" — covers authentic-vs-arcade tradeoffs explicitly: <https://gamedesignskills.com/game-design/sports/>

### B9. O'Reilly — *Fundamentals of Sports Game Design* (Adams)
- Book-length treatment of the same patterns Adams introduced in the Designer's Notebook column. Useful for: control-scheme taxonomy chapter, the chapter on tutorial flows for non-mainstream sports, and the chapter on broadcast-feel cameras (relevant to our `camera` plugin): <https://www.oreilly.com/library/view/fundamentals-of-sports/9780133812572/>

### B10. Academic — "Learning by Design: What Sports Coaches can Learn from Video Game Designs"
- Springer (Sports Medicine - Open) peer-reviewed article on how video games scaffold complex motor-skill onboarding via "preliminary levels or tutorials where players can explore action capabilities in a representative, but simplified, environment." Direct support for graded onboarding (puzzle mode → tutorial sheet → full match): <https://link.springer.com/article/10.1186/s40798-021-00329-3>

### B11. Academic — "Keepin' it Real: Challenges when Designing Sports-Training Games"
- Exertion Games Lab CHI 2015 paper (PDF) — challenges of mapping real sport biomechanics into game inputs without breaking either the realism or the playability budget. Useful framing for our sweep-mechanic decisions: <https://exertiongameslab.org/wp-content/uploads/2011/07/keepin_chi2015.pdf>

### B12. Schell — *The Art of Game Design: A Book of Lenses*
- Notes-by-Lex's chapter notes (the book itself isn't online, but these notes hit the relevant lenses: Lens of Skill, Lens of Chance, Lens of the Curve of Interest as applied to repeated-attempt sports loops): <https://notesbylex.com/the-art-of-game-design-a-book-of-lenses-2nd-edition-by-jesse-schell.html>
- Schell Games' own page on the book: <https://schellgames.com/art-of-game-design>

### B13. Rocket League — replay system as design pillar
- Rocket League Wiki "Saved Replays": <https://rocketleague.fandom.com/wiki/Saved_Replays>
- ballchasing.com replay database (148M+ replays at time of writing — proof that replay infrastructure built once unlocks community ecosystem): <https://ballchasing.com/>
- DivvyCr replay parser (open-source format docs; useful when designing our own replay file): <https://github.com/DivvyCr/RocketLeague-ReplayParser>
- Direct relevance: replays for curling are *strictly easier* than for Rocket League — deterministic physics + small entity count + low input frequency means a per-shot ReleaseEvent stream plus the seed reproduces everything. Match this UX bar.

---

## C. Cross-cutting design themes (how these inform the curling sim)

### C1. Arcade vs simulation slider, not toggle
Adams' "tough referees" knob, Wii Sports' assist defaults, OOTP's strategy-only mode, PGA 2K's three-click vs EvoSwing — every long-running sports franchise ends up with an *adjustable* realism dial rather than a single design point. A curling sim should similarly expose: aim noise, weight noise, sweep effect strength, and AI strictness as runtime configurables.

### C2. Compress 4-DOF input into a single-button rhythm when possible
Bowling, golf, tennis, and pool video games all converged on the same primitive: pre-set the abstract intent (line, spin, club, shot type), then resolve execution with a single rhythmic input (3-click meter, gesture, timing window). Curling's natural inputs — line, weight, handle, sweep — fit this pattern. The squareblind retrospective's argument is that motion control is the most *literal* fit but not the only one; 3-click meter is the strongest fallback.

### C3. Motion sweeping is a known pitfall, not a feature
Every motion-control curling title in the catalog (Deca Sports, Mario & Sonic at Sochi, Let's Play Curling!!) ends up with players who want sweeping but don't want the wrist pain. WayTooManyGames' "I just button-mashed" admission is a representative, not isolated, finding. If we expose sweep-shake as input, also expose a button-equivalent path; do not require gestures.

### C4. Onboarding for an unfamiliar sport
The Springer "Learning by Design" paper, the Schell lenses (Curve of Interest), and the squareblind retrospective converge: scaffold via simplified-but-representative practice tasks before full-rules play. Concrete pattern to steal: Mario Golf's tutorial holes, Wii Sports' training mode, OOTP's spring-training scaffolding. Direct mapping for us is the puzzle/Hot Shots mode (Plugin 12) plus a guided-aim teaching end.

### C5. Replay infrastructure pays compounding dividends
Rocket League's replay file format outlives every individual update and underwrites the third-party ecosystem (ballchasing.com). Curling determinism makes this even easier — deterministic physics + the existing `ReleaseEvent`/seed contract mean a replay file is essentially the input log. The investment converts directly into highlight reels, broadcast cuts, and bug-repro infrastructure.

### C6. Accessibility as design pillar, not afterthought
Curl!'s BCI/switch-first design is the only curling-specific reference for this, but the broader pattern (Mario Golf's button-only fallback, EA PGA's 3-click toggle) is consistent: dedicated curling players skew older, more international, and more disability-inclusive than typical FPS audiences. An accessible-input lane is a market expansion, not a charity feature. <https://store.steampowered.com/app/2100970/Curl/>

### C7. Spectator / free-cam / broadcast modes
Curling is unusual among "minor" sports in that it *already* has a heavily standardized broadcast camera language (overhead house cam, low end-of-sheet cam, slo-mo replay from the back). Our `camera` plugin can lean on this — see Notebook 9 (Broadcast). The Rocket League replay+spectator design is the ports-of-call reference for how to expose this in-engine.

### C8. Modding/sandbox as longevity multiplier
OOTP's user-imported leagues, Football Manager's database editing, and the Rocket League replay community all sustain audience years past initial release. For curling: a sandbox mode that exposes ice condition, stone position, and shot-replay export is cheap to ship (it's just our debug plugin made user-facing) and has outsized longevity ROI.

---

## D. Catalog of representative reviews (quick spot-check index)

- Curling 2010 / 2012 / Take-Out Weight 2 critique pattern: physics calibrated unrealistically tight, no margin for casual play. Pixel Empire on the Curling World Cup successor confirms this lineage continued through 2018: <https://www.thepixelempire.net/curling-world-cup-pc-review.html>
- Let's Play Curling!! — sweep-motion fatigue is the #1 complaint, content-depth-vs-price is #2: <https://waytoomany.games/2022/11/08/review-lets-play-curling/>
- Curling World Cup — physics broken, AI trivial, three championships in an hour. The single most useful negative case-study for our project: <https://www.gamersheroes.com/honest-game-reviews/curling-world-cup-review/>
- Mario & Sonic curling minigame analysis (squareblind, see A8): the genre's sole positive reference. Cooperative role-distribution + simplified rules + no fatigue requirement.

---

Sources cross-checked via WebFetch on 2026-04-26 (squareblind retrospective, Adams Designer's Notebook, WayTooManyGames Let's Play Curling review, Steam Curl! page) and via WebSearch on the remainder. One Wikipedia link used (Sochi 2014 Mario & Sonic) as the canonical metadata reference.

---

## Supplementary Sources (5)

*Scrape-tested additions, 2026-04-26.*

### S1. Mark Wesley — "Implementing a Rewindable Instant Replay System for Temporal Debugging" (GDC 2013, free on Internet Archive)
- **URL:** <https://archive.org/details/GDC2013Wesley>
- **Type:** gdc-talk
- **Why it matters:** The canonical talk on building a video-style replay system as a circular buffer of frame snapshots — debug-draw, transforms, particle handling — with a development-timeline budget ("basics in 2 days, complete version in 1–2 weeks"). Wesley shipped this on Burnout and Skate. Direct prior art for our determinism-replay-debugger story: where we go further (deterministic re-sim), this talk shows the cheaper non-deterministic alternative we should also expose for live debugging. PDF, MP4, OGV, MP3 all freely downloadable from Archive.org.
- **Pre-flight:** verified HTTP 200 via WebFetch; talk and slides confirmed freely available.

### S2. Corey Davis — "Rocket League: The Road From Cult Classic to Surprise Success" (GDC 2016, free on Internet Archive)
- **URL:** <https://archive.org/details/GDC2016Davis>
- **Type:** gdc-talk
- **Why it matters:** Psyonix's design director on how the team avoided "screwing up what evolved into a simple, but deep, experience by maintaining focus and exercising design restraint." For a niche-sport sim with a small team, this is the load-bearing reference on scope discipline — the discipline that lets you ship 60fps deterministic physics + replay infra + community ecosystem instead of shipping yet another Curling World Cup. MP4 + slides freely available.
- **Pre-flight:** verified HTTP 200 via WebFetch; freely viewable on Archive.org.

### S3. Jared Cone — "It IS Rocket Science! The Physics of 'Rocket League' Detailed" (GDC 2018, free on GDC Vault)
- **URL:** <https://www.gdcvault.com/play/1024972/It-IS-Rocket-Science-The>
- **Type:** gdc-talk
- **Why it matters:** Psyonix's lead programmer walks through the bespoke physics layer atop PhysX, fixed-tick determinism, replay-as-input-log, and how networked clients re-simulate the entire physics scene every frame. Direct match for our Bevy `FixedUpdate` + `ReleaseEvent` replay design. Tagged as "free content" on GDC Vault.
- **Pre-flight:** verified HTTP 200 via WebFetch; confirmed marked as free content (GDC Vault opens last-2-years' top 30% to free users).

### S4. Iwata Asks — Wii Sports (Pages 1–4, Nintendo, free) and Wii Sports Resort (Pages 1–6, Nintendo, free)
- **URL:** <https://iwataasks.nintendo.com/interviews/wii/wii_sports/0/0/> and <https://iwataasks.nintendo.com/interviews/wii/wiisportsresort/0/5/>
- **Type:** dev-blog (developer interview series, Nintendo first-party)
- **Why it matters:** First-party Nintendo design commentary on why bowling and tennis became the genre-defining gesture-control loops, and how Wii MotionPlus (Resort) shifted from approximate flick → 1:1 mapping. Direct quote on emergent player behaviour: "before you knew it they were using their free left hand to try to toss an imaginary ball up for a serve!" — proof that the controller affordance shapes behaviour beyond what's instructed. Useful precedent for our gesture-vs-button-equivalent decision documented in C3 above.
- **Pre-flight:** verified HTTP 200 via WebFetch on Wii Sports page 3; confirmed free, no paywall.

### S5. Christian Nutt — "Smart Calls, Timing, Luck, & Poverty: How Rocket League Succeeded" (Game Developer, free)
- **URL:** <https://www.gamedeveloper.com/business/smart-calls-timing-luck-poverty-how-i-rocket-league-i-succeeded>
- **Type:** article (long-form interview)
- **Why it matters:** Companion long-form to Davis' GDC talk — covers 60fps non-negotiable, bespoke physics tuning over general-purpose, streamlined modes, matchmaking refinement, and the famous "the only way to give people agency was hats" line on cosmetic-only customization. The single best non-video reference on how a small studio shipped a deep sports sim without scope creep. Direct relevance to our packaging/distribution roadmap.
- **Pre-flight:** verified HTTP 200 via WebFetch; confirmed publicly accessible (no paywall).
