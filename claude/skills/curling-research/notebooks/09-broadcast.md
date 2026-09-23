# Broadcast Presentation

How televised curling is staged for spectators: cameras, telestration, audio, score-bug graphics, commentary structure, and the production conventions a curling-game's HUD and spectator mode should mimic. Scope excludes rules (Notebook 1), strategy explanations (Notebook 5), and broadcaster biographies beyond their on-air role (Notebook 10).

---

## 1. Camera Positions — The Standard Curling Rig

The conventional televised curling rig is essentially **three core camera positions** that have been stable across CBC, TSN, Sportsnet, NBC, BBC, and OBS Olympic feeds for decades, with specialty cameras layered on top at majors.

- **Overhead house cam (truss-mounted)** — One robotic camera hangs on a truss directly above each end's house. It is both a play-by-play camera (tracking the rock into the rings) and the canonical stone-position diagram angle. SportsVideoGroup describes "a robotic camera positioned directly above the ice sheet and scoring area" as central to NBC's coverage. https://frontofficesports.com/nbc-curling-night-in-america/
- **Sheet-long delivery cam (hack POV / "slide cam")** — A low cam at or behind the delivering hack that frames the thrower sliding out and the long perspective down the sheet to the target. Typically the shot the broadcast cuts to at release.
- **Sheet-side reverse / hog-line cam** — A side camera near the far hog line that catches the stone arriving in the house and gives the cleanest collision geometry.
- **Hi-Motion super-slow-motion** — A specialty camera (jib- or pole-mounted) reserved for replays of release and collisions; documented in SVG's coverage of Vancouver 2010 and used at every Olympics since.
- **Spider/cable cam (majors only)** — Ailsa Craig finals, Brier finals, and Olympic finals add a low cable cam down the sheet for hero shots. Not standard for regular-season Slam events.
- **PTZ remote cams (Milan 2026)** — SMG's Milan 2026 deployment used ZowieTek NDI PTZ cameras with "rapid camera relocation and dynamic positioning adjustments" via networked discovery, reducing latency ~30% for AI overlays. https://zowietek.com/news/ndi-powers-the-milan-winter-olympics-zowietek-cameras-enable-smgs-ai-driven-all-ip-curling-broadcast

**Game-design takeaway:** A curling sim's spectator/replay mode should default to overhead-house for stones at rest, sheet-long delivery for the throw, and side reverse for collisions. Three presets cover ~90% of broadcast.

---

## 2. The Mic'd-Team Convention — Curling's Defining Audio Choice

The single most distinctive feature of curling broadcasts is that **all four players on every team wear lavalier microphones** and there is **no broadcast delay**. This is not optional broadcast colour — it is the production decision that makes televised curling work.

- **Origin:** TSN introduced player mics in 1985; the convention is now ~40 years old and adopted by every major curling rights-holder. CBC reporting confirms it has been the standard "for more than 20 years" and is now considered baseline. https://www.cbc.ca/sports/olympics/winter/curling/curling-bubble-tv-experience-1.5862657
- **What viewers hear:** The skip's strategic discussion with the vice, "hurry hard!" calls to sweepers, mid-shot adjustments ("off! off!"), and post-shot reactions. NBC producer Jim Carr describes it as "fly-on-the-wall" access to decision-making. https://frontofficesports.com/nbc-curling-night-in-america/
- **No-delay policy:** Olympic curling on OBS runs live without a profanity delay; rights-holders may add their own delay (CBC has historically not). Profanity slips occasionally air. https://www.cbc.ca/sports/olympics/winter/curling/profanity-slipping-out-televised-curling-events-1.5997756
- **Game-design takeaway:** A spectator/replay mode benefits enormously from "voiced strategy" — even synthesized AI dialogue ("guard at four-foot," "draw to button") modelled on real skip patter would feel authentic. Silent curling broadcasts feel dead.

---

## 3. Telestration & Trajectory Overlays

Telestration in curling broadcasts has evolved from announcer-drawn broom lines to AI-rendered predicted curl arcs.

- **Broom-line telestration** — Analyst-drawn line from broom target through the released stone showing intended path; standard since the 1990s. NBC explicitly cites "telestrator graphics" used by announcers to explain shot options. https://frontofficesports.com/nbc-curling-night-in-america/
- **Stone-trail / "rock paths"** — Ribbon overlay showing the stone's actual trajectory after release. Persistent on screen for several seconds post-release; sometimes superimposed on overhead-house view with all four delivered stones' paths.
- **AI-driven trajectory prediction (Milan 2026)** — SMG's InnoMotion AI system generated "real-time trajectory heatmaps and predict[ed] post-collision sliding paths," plus 3D AR replay with "thermodynamic data overlays that illustrate the friction dynamics between stone and ice." First Olympic deployment of predictive curl-arc graphics in real time. https://zowietek.com/news/ndi-powers-the-milan-winter-olympics-zowietek-cameras-enable-smgs-ai-driven-all-ip-curling-broadcast
- **Distance-to-pin / shot-stone overlays** — Small text label or radial ring around stones in the house showing distance to the button (centimetres or "shot rock" tag).
- **Academic foundation** — "Visualization of Stone Trajectories in Live Curling Broadcasts using Online Machine Learning" (Takahashi & Yokozawa) and the more recent CurlObserver framework (ScienceDirect 2025) document the computer-vision pipeline that broadcasters' AI graphics rest on. https://www.sciencedirect.com/science/article/abs/pii/S0957417425023632
- **Open-source reference:** `jdumm/curlovision` on GitHub — extracts stone positions from broadcast footage, useful as a sanity check for sim trajectories. https://github.com/jdumm/curlovision/

**Game-design takeaway:** A curling sim already owns ground-truth trajectory data — render it natively as a broadcast-style ribbon overlay and a predicted curl arc during aiming, with toggles for spectator vs. player views.

---

## 4. Score-Bug Anatomy

The curling score-bug is unusual among sports HUDs because **the canonical score representation is end-by-end**, not a running total. Traditional broadcast score-bug elements:

- **End-by-end scoring grid** — Row per team, column per end, cell shows points scored that end (or blank if blanked). Running total at the right edge. This is the curling equivalent of a baseball line-score, and viewers expect it visible at all times during the throw.
- **Hammer indicator** — Visual marker (often a small icon) showing which team has last-rock advantage in the current end.
- **Stone count this end** — How many stones each team has left to throw (e.g., 4 vs. 3). Often as a row of small stone icons that fill or empty.
- **Thinking-time clocks** — Per-team countdown of remaining strategy time. Curling Canada's Time Clock Operator Manual (Nov 2025) specifies the timing standard: 4:00 of thinking time per end for ends 1–5, 4:15 per end for ends 6–10. Broadcasts surface both team clocks at all times. https://www.curling.ca/wp-content/uploads/2025/11/Time-Clock-Operator-Manual.pdf
- **Shot-stone tag** — Small text on stones in the house identifying which is currently shot rock; sometimes a colored pip rather than text.
- **Rights-holder branding** — TSN, Sportsnet, CBC, and NBC each ship slightly different score-bug layouts but all share the four core elements above. CBC's 2026 Olympic graphics package was designed by NewscastStudio with "system-driven framework" parallels for English/French and "shared assets for partners including TSN and Sportsnet" — a single visual language across Canadian rights-holders. https://www.newscaststudio.com/2026/02/19/cbc-2026-winter-olympics-graphics/

**Game-design takeaway:** The end-by-end grid is non-negotiable. Hide it and viewers can't follow the match arc (e.g., spotting a steal, anticipating hammer pressure). Hammer + stone-count + clocks are the next three priorities.

---

## 5. Commentary Structure — Two Voices, Sometimes Three

Curling has settled on a **play-by-play + colour analyst** booth model with optional ex-skip pundit, mirroring hockey but with longer strategic discussions during deliberation pauses.

- **Play-by-play (PBP):** Calls the action, identifies teams, sets up shot context, narrates score/end transitions. Vic Rauter held this seat at TSN from 1986 to 2026 — 40 years — with signature calls "Make the final..." (final-score reveal) and "Count 'em up — 1, 2, 3, 4..." for big-end reactions. https://en.wikipedia.org/wiki/Vic_Rauter
- **Colour analyst (ex-elite-curler):** Explains shot-call rationale, sweeping decisions, ice-reading. Russ Howard — Olympic gold medallist, 2-time world champion — has been TSN's analyst since 2009 alongside Rauter. https://www.cbc.ca/sports/olympics/winter/curling/vic-rauter-retirement-curling-broadcaster-tsn-9.7151696
- **Second analyst / ex-skip pundit:** Cathy Gauthier (2005 Scotties champion with Jennifer Jones) joined TSN as a second analyst, covering women's events alongside Rauter and Howard. https://en.wikipedia.org/wiki/Cathy_Gauthier
- **OBS Olympic feeds:** OBS produces a clean international feed; rights-holders add commentary. Andrew Catalon has been NBC's curling PBP since 2010, working three Olympic Games. https://en.wikipedia.org/wiki/Curling_Night_in_America
- **CBC tradition:** Don Wittman, Don Duguid, Mike Harris, and Joan McCusker formed the canonical CBC curling booth from 1962 through 2011 when CBC's curling rights expired. https://en.wikipedia.org/wiki/Curling_on_CBC

**Game-design takeaway:** A two-voice commentary track (terse PBP "Gushue draws to four-foot" + analyst rationale "they need this to sit behind the corner guard") is the broadcast voice. Single-voice narration sounds like a tutorial.

---

## 6. Slow-Motion Replay Conventions

Curling slow-mo serves three specific purposes that a sim's replay system should mirror:

1. **Release mechanics** — Hi-Motion isolation on the slider foot, broom, and stone handle to show rotation and release timing. Triggered automatically on every shot at majors.
2. **Collision geometry** — Side-reverse angle slowed to ~10% to show contact angle, energy transfer, and post-collision paths. Almost always replayed for any double-takeout, tap-back, or run-back.
3. **Sweeping technique** — Hi-Motion on the brush head during a critical sweep, especially during Broomgate-era "directional sweeping" debates. SVG noted Hi-Motion's role in showing "great color of the sweepers and detailed views of their technique."

**Trigger pattern:** Every shot gets at least one replay during deliberation for the next shot — the deliberation pause is *what makes curling broadcastable*. A sim that auto-replays the just-thrown stone during AI thinking time is reproducing the canonical broadcast rhythm.

---

## 7. The Broomgate Coverage Case Study

Broomgate (2015–16) is the most-studied curling broadcast event because it forced production teams to **make the invisible visible** — sweeping efficacy isn't normally a televisible variable. Key broadcast adaptations:

- **Hi-Motion macro shots of brush heads** to show the directional fabric texture and ice-grain disturbance pattern.
- **Side-by-side comparison reels** of pre-2015 vs. directional-fabric sweeping outcomes on near-identical shots.
- **National Research Council "Sweeping Summit" footage** (Kemptville, May 2016) released to broadcasters as B-roll. https://www.cbc.ca/news/canada/london/curling-frankenbrooms-directional-fabric-1.5744754
- **Mainstream crossover:** The Late Show with Stephen Colbert ran a six-minute "Broomageddon" segment in November 2015 — rare instance of curling breaking into US late-night, reflecting how the broadcast graphic language ("watch what the brush is doing to the rock") gave a non-curling audience a concrete visual hook. https://en.wikipedia.org/wiki/Broomgate

**Game-design takeaway:** If a sim models sweeping effects (we do — see Notebook 3), a dedicated "sweeping efficacy" replay overlay is broadcast-faithful and educational. Show the pre-sweep predicted resting point vs. actual.

---

## 8. CurlingZone & WCF Live-Stream Stat Overlays

Outside major-network broadcasts, **CurlingZone** and **WCF's curlingchannel.tv** provide secondary streams during World Curling events with simpler graphics packages but heavier statistical overlays.

- **CurlingZone:** Shot-by-shot stats (shooting %, hammer efficiency, force/draw split) overlaid live; the de facto stat reference for competitive curling. https://www.curlingzone.com/television.php
- **Curling Channel (WCF):** WCF's own streaming arm; carries lower-priority sheets at championships that the main host broadcaster isn't covering. Production is a single overhead cam + one sheet-long cam; no telestration. https://curlingchannel.tv/
- **Grand Slam streaming (Sportsnet+):** Full HD, full graphics package, but all four sheets covered simultaneously from overhead-only. https://www.thegrandslamofcurling.com/streaming-faqs

**Game-design takeaway:** A "stat-overlay" toggle in spectator mode (shooting %, recent shot history) emulates the CurlingZone experience and is great for analytics-leaning players.

---

## 9. AI / Vision Research Curling Broadcasts Now Depend On

Real-time stone tracking from broadcast video is the technical foundation under modern curling graphics. Two strands worth knowing:

- **Takahashi & Yokozawa (NHK), "Visualization of Stone Trajectories in Live Curling Broadcasts using Online Machine Learning"** — 2017 paper, the first published trajectory-from-broadcast pipeline; used at Pyeongchang 2018. https://www.researchgate.net/publication/320543320_Visualization_of_Stone_Trajectories_in_Live_Curling_Broadcasts_using_Online_Machine_Learning
- **CurlObserver (Expert Systems with Applications, 2025)** — Latest framework: dynamic-perspective broadcast video → real-world rink coordinates without camera calibration; CurlSort tracker handles cross-frame association of visually similar stones. Published trajectory dataset. https://www.sciencedirect.com/science/article/abs/pii/S0957417425023632
- **Kim & Han, "Curling stone tracking based on enhanced mean-shift"** (Sage 2021) — earlier algorithmic baseline, useful as a complexity comparison. https://journals.sagepub.com/doi/abs/10.1177/1754337120967729

**Game-design takeaway:** A sim has the inverse problem solved by construction (we know the trajectory). The research is most useful as validation: render the sim's trajectory the same way a CV pipeline would render real broadcast footage, and the spectator experience converges.

---

## 10. Production Scale Reference Points

For sizing-the-effort context:

- **Pyeongchang 2018 OBS curling crew:** 167 members across coverage of two competition sheets in the curling venue.
- **Milan 2026 IP-based production:** Reduced overall latency ~30% vs. traditional baseband via NDI; first Olympics with end-to-end IP curling production.
- **TSN's Brier coverage:** Typically 6–8 cameras per sheet for the playoff round; reduced to 4 for round-robin.
- **OBS philosophy:** "OBS delivers content in real time and does not add delays or mute athlete microphones, which are a standard part of curling coverage." https://en.wikipedia.org/wiki/Olympic_Broadcasting_Services

---

## 11. HUD/UI Design Implications for the Sim

Synthesizing the above into actionable conventions for our curling game's UI/HUD/spectator mode:

| Broadcast convention | Implication for the sim |
|---|---|
| Three-camera default rig (overhead house / sheet-long / side reverse) | Spectator-mode preset cycle should be these three before any artistic angles |
| Mic'd-team audio | Synthesized strategic dialogue during AI thinking-time = the highest-leverage immersion add |
| End-by-end score grid always visible | Score-bug is non-negotiable persistent UI; running total alone is wrong |
| Thinking-time clocks per team | Show both clocks; 4:00 ends 1–5, 4:15 ends 6–10 (per Curling Canada manual) |
| Telestration / curl-arc overlay | Render predicted curl arc during aim; render actual trail after release |
| Hi-Motion replay on every shot during opponent's deliberation | Auto-trigger replay when control passes to the other team |
| Hammer + stone-count icons | Surface as small dedicated HUD widgets, not buried in menus |
| Distance-to-pin overlays | Show on stones in the house when paused or in spectator mode |
| Two-voice commentary | If shipping commentary at all, ship two voices not one |
| Sweeping efficacy replays (Broomgate legacy) | Replay overlay showing pre-sweep predicted vs. actual resting point — broadcast-faithful AND educational |

---

## Sources spot-checked

- WebFetch verified: zowietek.com (Milan 2026), Wikipedia/Curling_on_CBC, Wikipedia/Vic_Rauter, frontofficesports.com (NBC).
- Web-search verified (text confirmed in result snippets): cbc.ca (mic'd players bubble article), cbc.ca (London ON Frankenbrooms study), tsn.ca (Rauter retirement), curling.ca Time Clock Manual, sciencedirect.com (CurlObserver), newscaststudio.com (CBC 2026 graphics).

(One Wikipedia-only fact: Vic Rauter biographical article. Curling-on-CBC and Cathy Gauthier are also Wikipedia-cited but corroborated by CBC/TSN articles in the same search.)

---

## Supplementary Sources (5)

*Scrape-tested additions, 2026-04-26. CBC URLs that 403'd in the original pass replaced with alternative broadcast-design references.*

### S1. SVG Europe — "Milano Cortina 2026: OBS makes 'significant breakthrough' with AI for capture and replays at Winter Games"
- **URL:** https://www.svgeurope.org/blog/headlines/milano-cortina-2026-obs-makes-significant-breakthrough-with-ai-for-capture-and-replays-at-winter-games/
- **Type:** article
- **Why it matters:** Authoritative production-trade write-up of OBS's first-ever AI stone-tracking deployment at an Olympics. Confirms 12 cameras per sheet × 4 sheets, plus a new full-length overhead rail camera. Documents the live data panel (trajectory, speed, rotation, timing) and the OBS executive quote on previously-impossible live sweep/spin analysis. Pair with the existing zowietek vendor page for cross-checked numbers from broadcaster + camera-vendor sides.
- **Pre-flight:** verified HTTP 200 via WebFetch (full content extracted).

### S2. SVG Europe — "Milano Cortina 2026: AI tracking introduced for curling coverage"
- **URL:** https://www.svgeurope.org/blog/top-stories/milano-cortina-2026-ai-tracking-introduced-for-curling-coverage/
- **Type:** article
- **Why it matters:** The companion SVG Europe piece introducing the **CurlingHunter "Ghost Line"** — an on-ice digital overlay showing the predicted path and curl of the stone *before* it stops. This is exactly the predicted-curl-arc telestration our sim's aim phase already owns ground-truth data for; the article gives us a named broadcast-equivalent feature to anchor UX copy and option labels. Also documents the virtualized OB-van cloud production stack that supersedes traditional baseband trucks at three Olympic venues.
- **Pre-flight:** verified HTTP 200 via WebFetch (page content extracted, including 12-cams-per-sheet figure and rail-camera detail).

### S3. OBS Beijing 2022 Media Guide (host-broadcaster production spec)
- **URL:** https://www.obs.tv/prx/asset.php?tgt=OBSBeijing2022MediaGuide-January2022v2-9e7745a3ebf4.pdf&gen=1
- **Type:** manual
- **Why it matters:** Official OBS host-broadcaster media guide PDF — the closest thing to a "curling production handbook" the IOC publishes. Covers per-sport venue camera plans, replay/multi-cam systems (Alibaba Cloud collaboration for curling + speed skating multi-cam replays), and the OBS no-delay / no-mute audio policy that is the structural reason mic'd-team curling broadcasts work. Use as primary citation for the standard Olympic curling rig before Milan's AI extensions.
- **Pre-flight:** asset URL surfaced in WebSearch results; library.olympics.com mirror also confirmed; PDF is too large for WebFetch summarization (`maxContentLength` exceeded), which itself confirms HTTP 200 + non-empty body.

### S4. Wikipedia — *Season of Champions on TSN*
- **URL:** https://en.wikipedia.org/wiki/Season_of_Champions_on_TSN
- **Type:** article
- **Why it matters:** Canonical reference for TSN's Canadian curling production package (Brier, Scotties, men's/women's Worlds, Continental Cup, Skins) — the rights-holder lineage CBC handed to in 2008. Documents the four-event annual cycle, the announcer-rotation tree (Rauter/Howard/Gauthier/Courtney lead booth + Mudryk secondary), and the Linda Moore / Cheryl Bernard / Ray Turnbull historical chairs. Replaces the two CBC URLs that 403'd by giving us the rights-holder side that actually carries Canadian curling today.
- **Pre-flight:** verified HTTP 200 via WebFetch (page content extracted).

### S5. TSN — "The 'Voice of Curling' Vic Rauter calls it a career"
- **URL:** https://www.tsn.ca/curling/article/the-voice-of-curling-calls-it-a-career/
- **Type:** interview
- **Why it matters:** Long-form retirement feature from the rights-holder itself, with first-person Rauter quotes on broadcast philosophy: the deliberate "casual viewer" framing TSN's VP of production cast him for, the "Make the Final" signature-call origin story, and the explicit "set up the analyst" booth dynamic. This is the source for two-voice commentary structure as a designed-in production choice rather than an accident — directly informs synthesized-commentary pacing (PBP sets up, analyst delivers rationale) for the sim's spectator mode.
- **Pre-flight:** verified HTTP 200 via WebFetch (interview content extracted).

