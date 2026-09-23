# Shot Taxonomy

**Owner:** curling-research skill
**Last reviewed:** 2026-04-26
**Status:** Seed pass (research subagent)

## Scope

A complete catalog of named curling shots — what each shot is *intended* to do, the geometry/handle that defines it, the weight band it lives in, and the canonical failure modes that show up in coaching corrections and shot-call notation. Covers:

- **Draws** — guard-weight, draw-weight, back-line/tee-weight, top-of-the-house, freeze, come-around (in-turn vs out-turn), tap-back, lid, biter, soft draw, the chip
- **Guards** — corner guard, centre guard, tight guard, top/bottom of FGZ, high guard, mid guard, the cover (rolled-from-behind variants for brevity only — strategy reasons live in Notebook 5)
- **Takeouts / hits** — open hit, hit-and-stay, hit-and-roll (for shot rock vs. for position vs. roll-out), nose hit, double takeout, triple, peel, peel-out, board-weight takeout, control-weight hit, normal-weight hit, hack-weight hit
- **Promotions / interaction shots** — raise (raise takeout, raise to count, light raise/tap-up), runback (and runback double / runback raise), in-off, ricochet, angle raise, draw-raise / split / promotion-split, wick, chip, steal-saver
- **Trajectory shots** — port shot (narrow port, pocket), tick (mixed-doubles 5-rock zone tick, plus regular team-curling FGZ tick), board-weight tick
- **Weight terminology** — guard, draw, back-line, hack, board, control, normal, peel-plus; with literature/coaching numerical bands
- **Handle conventions** — in-turn vs out-turn for right- and left-handed deliverers, including handle on come-arounds and freezes

**Excludes:** *when* to choose each shot — see Notebook 05 (Strategy/Analytics). The physics of *why* stones curl, *why* sweeping changes line/distance, and *why* collisions split angles — see Notebook 02 (Physics) and Notebook 03 (Sweeping). AI shot selection / scoring of candidate shots — Notebook 12. Broadcast graphic conventions and shot-call lower-thirds — Notebook 09. The free-guard-zone rule itself (the *constraint* shots operate under) — Notebook 01.

## Coverage Outline

### 1. Weight terminology and timing

The weight grid is the spine of any curling taxonomy because every named shot is a (weight × line × handle × target) tuple. Coaches train weight via stopwatch timing of either *hog-to-hog* (HtH, far-hog crossing minus near-hog crossing) or *back-line-to-near-hog* (split time) — these are the two windows where the stone is past release and before sweep decisions matter.

Canonical bands as used in NCCP-style coaching and in Curling Canada / WCF references (numbers vary ±0.3 s with ice speed, but the ordering is universal):

| Weight name | Hog-to-hog (s) | Split / B–H1 (s) | Intent |
|---|---|---|---|
| Guard / soft | 16+ | 4.20+ | Stop short of house, in FGZ |
| Draw | 13.0–14.5 | 3.95–4.10 | Reach house; "tee weight" = draw to button |
| Back-line / back-house | 12.5–13.0 | 3.85–3.95 | Reach back ring without rolling out |
| Hack | ~11.0 | 3.55–3.70 | Reach hack at far end (light takeout) |
| Board | ~10.0 | 3.45–3.55 | Reach back boards |
| Control / normal | 9.5–9.8 | 3.30–3.45 | Most-used takeout weight |
| Firm / heavy | ~9.0 | ~3.20 | Aggressive takeout, less roll predictability |
| Peel | <8.5 | ≤2.50 (split) | Remove target *and* the shooter |

### 2. Handle (rotation) conventions

Curling rotations are named for the wrist motion of a right-handed deliverer:

- **In-turn (RH):** clockwise rotation viewed from above. Stone curls left-to-right relative to the broom for a RH thrower.
- **Out-turn (RH):** counter-clockwise. Stone curls right-to-left.
- **LH deliverer:** rotations *physically* match name (in-turn is still CW, out-turn still CCW), but the broom positioning relative to the body flips. The *curl direction is identical* — handle is named by rotation, not by which way it curves on the sheet.
- Come-arounds and freezes are typically called by handle ("come-around in-turn behind the corner guard") because the curl direction determines which side of the guard the rock can settle.
- A ¼–1 turn is the typical release; coaches measure quality by 2.5–3.5 rotations between hog lines.

### 3. Draws

- **Draw (generic):** any non-contact shot intended to come to rest in the house. Draw-weight = enough to reach the rings; "tee-weight" or "draw-to-the-button" = stop on the button.
- **Guard-weight draw:** intentionally short of the house, designed to land in FGZ.
- **Back-line draw:** stops in the back of the house, often used to sit behind cover.
- **Come-around (in-turn / out-turn):** a draw that uses curl to bend around a guard and settle in the house behind it. The handle defines which side of the guard it settles.
  - *Failure modes:* hung on the guard (came too narrow / under-curled), through the rings (over-thrown), wrecked on a stone (wrong handle).
- **Freeze:** a draw that stops touching, or within an inch of, another stone — typically an opponent's stone in the house. Variants:
  - *Top freeze* — frozen on the front edge.
  - *Side freeze* — alongside.
  - *Back freeze* — directly behind, used to lock the opponent's stone in.
- **Tap-back / tap-up:** a deliberate draw with slightly heavier weight that contacts a stone (own or opponent) and pushes it backward by a known amount; the shooter usually replaces the contacted stone's position.
- **Lid:** a draw that comes to rest covering the button (sits on top of / on the pin) — shot-rock claim language.
- **Biter:** a stone whose edge just touches the 12-foot. Drawing-the-biter is a recognised cat-and-mouse final shot.
- **The chip / chip-and-roll:** a very light contact draw that taps a stone aside and rolls into scoring position; sometimes classed as a draw, sometimes as a soft hit depending on weight.

### 4. Guards

A guard is any stone deliberately placed short of the house (in the FGZ) to obstruct future shots. Position-named variants:

- **Centre-line guard / centre guard** — on or near the centre line.
- **Corner guard** — placed wide, off the centre line (typical opening shot for the team without hammer in the 5-rock-rule era).
- **Tight guard** — close to the front rings, just above the top edge of the house.
- **Top of FGZ / high guard** — near the hog line; harder to remove but harder to come around.
- **Bottom of FGZ / low guard / 12-foot guard** — closer to the rings; easier come-around target but easier to peel.
- **Numbered weight scale** (Ferbey/Pointe-Claire training): 1 = high guard, 2 = mid guard, 3 = tight guard, 4–10 = increasing depth into the house.

### 5. Takeouts (hits)

- **Open hit / takeout:** straight-line removal of an exposed stone with no roll constraint.
- **Hit-and-stay (nose hit):** contact dead-on, shooter stops at impact location. Achieved by hitting the stone "on the nose" (perfectly aligned).
- **Hit-and-roll (for shot rock / for position):** glancing contact, shooter rolls a planned distance/direction. Sub-categorised by where the roll ends:
  - *Hit-and-roll for shot rock* (rolls behind cover or to the button)
  - *Hit-and-roll for position* (rolls to a specific spot)
  - *Hit-and-roll out of play* (i.e. a peel — see below)
- **Double takeout:** one delivery removes two stones. Geometry families: *barely-touching pair* (kiss-line), *gap doubles* (rebound off second stone after hitting first), *runback doubles* (see runback).
- **Triple takeout:** rare three-stone removal, almost always a "running" double that runs back into a third.
- **Peel (peel-out):** delivered with peel weight so that *both* the target stone and the shooter exit the rings (or sheet entirely). Used to clear FGZ once the rule allows.
- **Board-weight takeout:** light enough to keep the shooter in play but firm enough to remove the target — common on heavy ice or when roll predictability matters.
- **Hack-weight hit:** the lightest commonly-thrown takeout; high curl, used to thread through traffic or to leave the shooter in the rings.
- **Normal-weight / control-weight takeout:** the everyday hit; hog-to-hog ~9.5–9.8 s.

### 6. Promotion / interaction shots

- **Raise:** generic term for promoting a stone forward by collision. Shot is named by *what is being raised* and *where it ends up*:
  - *Raise to count* — bumps a friendly guard into the house for points.
  - *Raise takeout* — the raised stone removes an opponent stone.
  - *Light raise / raise tap* — bumps own stone deeper into the house for shot rock.
  - *Angle raise* — non-axial promotion that changes the raised stone's line.
- **Runback:** harder version of a raise where the shooter strikes a *front* stone (often a guard) hard enough to send it back into the *house* and remove a stone there.
  - *Runback double* — runback that takes out two stones.
  - *Runback raise* — promotes one's own front stone into a takeout.
- **Draw-raise / split / promotion-split:** soft delivery contacts a friendly stone and sends both stones to scoring positions (the shooter "splits" with the contacted stone).
- **In-off:** shooter strikes an opponent stone and *the angle off that stone* sends the shooter to a scoring position. Named "in-off" because the shooter ends up *in* the house *off* another rock.
- **Ricochet:** shooter rebounds off one stone into another (often into a takeout or into the rings). "Ricochet double" is a famous pro shot family.
- **Wick:** very light glancing contact that nudges a guard sideways while the shooter continues into the house. Often used to clear a tiny line of sight.
- **Chip:** a wick with the explicit intent of moving the contacted stone; sometimes used synonymously with wick.
- **Steal-saver:** colloquial term for the last-rock draw to avoid being stolen on (e.g., "draw to the four-foot for a steal-saver").

### 7. Trajectory / threading shots

- **Port shot:** delivered through a gap between stones. *Pocket* = a wider, more forgiving gap; *narrow port* = barely wider than the stone.
- **Tick:**
  - *Mixed doubles 5-rock-zone tick* — a delivered stone that ticks a centre-line guard sideways without removing it (the no-tick rule disallows full removal in MD; a clean tick that leaves the stone in play is legal in some rule variants).
  - *Free-guard-zone tick (regular curling)* — board-weight or heavier glancing shot to move a guard out of useful position without violating FGZ rules.
- **Board-weight tick:** softer tick where the shooter goes out the back, used late-end to neutralise centre cover.

### 8. Failure mode vocabulary

Coaching manuals and shot-call logs use a short, shared list of failure modes:

- **Hung** — under-curled and got stuck on a guard.
- **Wrecked** — collided with the wrong stone (usually a guard) en route.
- **Through** — overthrown past intended depth.
- **Light** — under-thrown, didn't reach.
- **Wide** — broom was set too wide, stone passed outside intended target.
- **Narrow** — broom set too tight, stone curled inside target.
- **Picked** — caught a debris/seam-induced line break.
- **Flashed** — takeout missed entirely (no contact).
- **Burned** — touched by a sweeper / player; equivalent to a foul, not a shot type.

These pair with shot names in shot-call notation: "hit-and-roll, light flash" or "come-around in-turn, hung."

## Sources

### Federation glossaries and rule references

1. **What is curling? — World Curling Federation**
   URL: https://worldcurling.org/about/curling/
   Type: Federation explainer (international governing body)
   Why it matters: The WCF's own page defines draw, guard, takeout, and the FGZ — the canonical wording teams and refs cite. (Glossary URL on the WCF site has historically moved; this is the active landing page citing the same definitions.)

2. **Curling Canada — Rules of Curling**
   URL: https://www.curling.ca/rules/
   Type: National federation rules portal
   Why it matters: Curling Canada is the primary publisher for NCCP/coach-development materials and shot terminology in the English-speaking curling world. The rules portal is the authoritative source for legal shot constraints (FGZ, no-tick, etc.).

3. **NBC Olympics — Types of curling shots, explained**
   URL: https://www.nbcolympics.com/news/types-curling-shots-explained
   Type: Major-broadcaster shot dictionary (Olympic edit desk)
   Why it matters: Concise, definition-grade entries for takeout, draw, guard, peel, freeze, hit-and-roll, raise — vetted against WCF/USCA glossaries for Olympic broadcast use.

4. **NBC Olympics — Curling 101: Glossary**
   URL: https://www.nbcolympics.com/news/curling-101-glossary
   Type: Broadcast glossary derived from federation sources
   Why it matters: Alphabetised glossary covering the long tail of named shots (in-off, port, wick, biter, lid) cross-referenced for Olympic commentary.

5. **Curling Canada — Coach Education (NCCP entry)**
   URL: https://www.curling.ca/coaching/
   Type: National coaching certification portal
   Why it matters: Index of Curling Canada's NCCP coach-development pathway (Levels 1–4); the curriculum is where weight bands, handle conventions, and shot-call vocabulary are formalised.

6. **Curling Canada — Competition Development**
   URL: https://www.curling.ca/coaching/competition-development/
   Type: Advanced-level coaching curriculum
   Why it matters: This is the level that introduces shot-percentage analytics and the full shot-classification taxonomy used by national-team coaches.

7. **Curling Canada — Competition Development product (NCCP package)**
   URL: https://canada.curling.io/en/products/Iqs8kTlaRDA
   Type: Coaching course product page
   Why it matters: Lists the explicit modules — including "shot selection," "shot-making mechanics," and weight control — that form the canonical taxonomy.

### Coaching manuals (PDF / club-published)

8. **Pointe-Claire CC — Advanced Instructional Program Manual (2012)**
   URL: https://www.pointeclairecurling.com/PCCC%20Advanced%20Instructional%20Program%20Manual%202012-2013%20(20012-08-24).pdf
   Type: Club-level advanced instructional manual
   Why it matters: One of the most-cited freely available NCCP-aligned coaching PDFs; chapters on weight control, shot selection, and shot-mechanics use the standard taxonomy.

9. **Lanark CC — Timing Curling Shots (Tech 5 support sheet)**
   URL: https://www.lanarkcurlingclub.org/wp-content/uploads/Support_Tech5-Timing.pdf
   Type: Coaching reference PDF
   Why it matters: Explicit mapping of split-time and hog-to-hog times to weight categories — the source data for the timing table in §1.

10. **Fort Wayne CC — Curling 301 (advanced curriculum)**
    URL: https://fortwaynecurling.com/index.php/learn-to-curl-heading/curling-university/curling-301
    Type: Club-level advanced clinic curriculum
    Why it matters: Contains the Ferbey 1–10 weight scale (high guard → back 12-foot) and explicit definitions of board, peel, control, hack, normal, firm, and bumper weights.

11. **CurlTech — Timing Rocks**
    URL: https://www.curltech.com/curling-training/timing-rocks
    Type: Specialist coaching site (Mike Harris–era staff)
    Why it matters: Industry-standard reference on stopwatch timing methodology and ice-condition adjustment — backs up the canonical weight-to-time mapping.

12. **CurlTech School — Timing Rocks**
    URL: http://www.curlingschool.com/timingRocks.html
    Type: Curling-school reference (companion to CurlTech)
    Why it matters: Independent confirmation of the same hog-to-hog tables, plus drills for calibrating weight by feel.

13. **Pat Reid Curling — Intermediate Guide (Curling Troy)**
    URL: https://curltroy.org/images/Intermediate_Guide2.pdf
    Type: Intermediate club-level curriculum
    Why it matters: Worked-example shot-selection sheets that list the standard shot families with diagrammed entry/exit angles.

14. **Peachtree Curling Association — Five Rock Rule explainer**
    URL: https://peachtreecurlingassociation.org/index.php/membership/leagues/14-curling-info/489-five-rock-rule-and-spirit-of-curling
    Type: Club-level rule explainer (FGZ)
    Why it matters: Practical guidance on how the 5-rock rule reshapes shot selection — directly relevant to which shot types are *legally available* on a given stone number.

15. **Curl BC — No Tick Rule (mixed doubles)**
    URL: https://www.curlbc.ca/wp-content/uploads/2024/10/No-Tick-Rule-EN.pdf
    Type: Member-association rule update PDF
    Why it matters: The current canonical reference for the no-tick rule in mixed doubles — defines exactly which tick-shot variants are legal vs illegal.

16. **Curling Basics — Free Guard Zone**
    URL: https://www.curlingbasics.com/en/free-guard-zone.html
    Type: Beginner curling reference site
    Why it matters: Concise FGZ definition that frames the legal envelope for guard-weight, tick, and runback shots.

17. **Curling Basics — Shot definitions**
    URL: https://www.curlingbasics.com/en/shot.html
    Type: Beginner shot-name dictionary
    Why it matters: Compact list with the long-tail terms (back-house weight, draw raise, split raise, "through a port", wick) defined in plain language.

### Club / association glossaries (used to triangulate consensus terminology)

18. **Cape Cod CC — Glossary of Curling Terms**
    URL: https://capecodcurling.org/index.php/curling/curling-101/glossary-of-curling-terms
    Type: Club glossary (USCA-affiliated)
    Why it matters: Frequently linked from USCA materials; covers in-turn / out-turn, biter, lid, chip, and the failure-mode vocabulary in §8.

19. **Potomac CC — Curling Terms**
    URL: https://curldc.org/customPage.php/curling-terms
    Type: USCA-affiliated club glossary
    Why it matters: Strong on shot-call notation — the way TV graphics and shot-percentage logs label each shot.

20. **Granite CC of Seattle — Glossary**
    URL: https://curlingseattle.org/glossary
    Type: Club glossary (Pacific NW)
    Why it matters: Broad coverage including ricochet, in-off, runback families.

21. **Lodi Curling Club — Curling Lingo**
    URL: https://lodicurling.org/index.php/curling/about-curling/curling-lingo
    Type: Club glossary
    Why it matters: Useful for cross-checking weight terminology and the lesser-used "bumper" and "control" weight names.

### Coaching analysis and analytics references

22. **Glenn Howard — In-off ricochet double takeout (TSN coaching breakdown)**
    URL: https://www.youtube.com/watch?v=fckTkyKpLZI
    Type: Coaching breakdown video by an Olympic gold medallist
    Why it matters: Live demonstration of in-off and ricochet shots being named on-air — anchors the terminology to a concrete pro shot.

23. **Throwing Rocks (Glenn Paulley) — Understanding the Free Guard Zone rule**
    URL: https://glennpaulley.ca/curling/2011/01/10/understanding-the-free-guard-zone-rule/
    Type: Long-form curling analytics blog (Paulley is a published curling analyst and certified coach)
    Why it matters: The article walks through how FGZ shapes shot choice family-by-family — guard, come-around, peel, tick — with numerical context.

24. **DoubleTakeout — The effect of the 5-rock rule**
    URL: https://doubletakeout.com/blog/the-effect-of-the-5-rock-rule/
    Type: Curling analytics blog (data-driven shot analysis)
    Why it matters: Quantifies how the 5-rock rule changed the *frequency* of each shot family at the elite level — the empirical companion to the taxonomy.

25. **Glossary of Curling — Wikipedia**
    URL: https://en.wikipedia.org/wiki/Glossary_of_curling
    Type: Encyclopaedia (one allowed Wikipedia link)
    Why it matters: The most-edited consolidated curling glossary; referenced here only as a pointer to the long tail of regional shot names not always covered by federation glossaries.

## Supplementary Sources (5)

*Scrape-tested additions, 2026-04-26. Targets scrape-friendly equivalents for paywalled coaching-book references (Howard / Stoughton / Arnold) and missing video demonstrations of named shots. All five verified HTTP 200 via WebFetch on 2026-04-26.*

### S1. Curling Class — The Tick Shot (with Coach Matt video demo)
- **URL:** https://curlingclass.com/curling-theory/hitting-tactics/the-tick-shot/
- **Type:** coaching article + embedded video demonstration
- **Why it matters:** Dedicated explainer for the tick-shot family — names the weight ("hack weight"), the line, and the sweeping decisions that distinguish a clean tick from a peel or a wrecked guard. Coach Matt's video is the kind of named-shot demo that the original 25 sources only describe in text. Covers both regular-curling FGZ ticks and is directly applicable to the mixed-doubles no-tick rule envelope.
- **Pre-flight:** verified HTTP 200 via WebFetch

### S2. Karrick Martin — Corner tick shot vs Epping (mixed doubles power play counter)
- **URL:** https://www.youtube.com/watch?v=KiLHwi2l4Qo
- **Type:** video (broadcast clip with shot-call context)
- **Why it matters:** Live elite-level corner tick attempt in a mixed-doubles power-play scenario — exactly the shot family Notebook 4 §7 calls out as poorly documented in scrape-friendly form. Shows shot intent, broom set, weight call, and outcome in one short clip. Pairs with the Curl BC no-tick PDF (source 15) by demonstrating *the legal envelope* it defines.
- **Pre-flight:** verified HTTP 200 via WebFetch

### S3. John Epping — Angle runback double takeout for the win
- **URL:** https://www.youtube.com/watch?v=scoEFeDQprk
- **Type:** video (broadcast highlight, shot-call labelled in title)
- **Why it matters:** Canonical *angle runback double* — one of the harder named shots in the runback family (§6) and one the original 25 sources only define in prose. The geometry (front-stone strike → angle into the back stones) is exactly what the AI-shot-selection consumers in Notebook 12 need a concrete reference clip for. Shot-call name is in the title, so cited terminology is unambiguous.
- **Pre-flight:** verified HTTP 200 via WebFetch

### S4. Scottish Curling — Drills and Coaching Aids
- **URL:** https://www.scottishcurling.org/resources/coaching-resources/drills-coaching-aids/
- **Type:** federation coaching-resource page (Royal Caledonian / Scottish Curling)
- **Why it matters:** Fills the "Scottish Curling coaching pathway" gap explicitly flagged at the bottom of this notebook. Drills are bucketed by *Weight Control*, *Line & Balance*, *Shot Execution*, and *Tactical Play* — the same axes our taxonomy uses. Provides UK/Scottish naming conventions (e.g. "Tunnel Training", "Round the Clock", "Climb the Ladder") that occasionally diverge from Curling Canada terminology, useful for cross-federation triangulation.
- **Pre-flight:** verified HTTP 200 via WebFetch

### S5. Curling Class — Glossary of Curling Terms (124 entries)
- **URL:** https://curlingclass.com/glossary-of-curling-terms/
- **Type:** structured glossary (coaching site, not a club)
- **Why it matters:** 124-entry glossary that explicitly covers the long tail our original glossaries (Cape Cod, Potomac, Granite Seattle) handle inconsistently — including *no-handle* delivery, *reverse handle*, *soft release*, double-takeout naming, and the full freeze family. Coaching-site provenance (vs. club-glossary) means terminology is curated to match NCCP-equivalent vocabulary. Single source of definitions for in-turn/out-turn that explicitly handles the right-handed convention without the LH ambiguity.
- **Pre-flight:** verified HTTP 200 via WebFetch

**Rejections (with reason):**
- *Glenn Paulley — "Does handedness matter in brushing?" (glennpaulley.ca, 2024-09-14)* — verified HTTP 200 but content scope is sweeping/brushing handedness, not shot taxonomy or handle conventions. Belongs in Notebook 03 (Sweeping), not 04.
- *Curl Coach — Curling Drills Handbook PDF (curlcoach.com)* — fetched as raw PDF binary; could not auto-verify scrape content without an OCR pass. Park for a future pass with a PDF-text extractor.
- *YouTube "Curling tip No. 1 — How to throw a turn on a curling rock" (BFHZoj7Ytgw)* — title matches but page metadata didn't expose creator attribution via WebFetch (footer-only HTML returned), so provenance is unconfirmed. Skipped in favour of the two shot-call-titled clips above.

## Gaps

- **WCF online glossary** returned 404 during seeding (worldcurling.org has reorganised; the glossary endpoint moves). Re-fetch on a later pass — the WCF glossary is the single most authoritative source and should anchor every term.
- **Russ Howard "Curl to Win" / Glenn Howard / Jeff Stoughton books** are paywalled or print-only; cited indirectly via TSN/CBC coaching segments. A deeper pass with library/archive access would let us pin specific weight bands and handle conventions to a named coaching author rather than a club glossary.
- **Scott Arnold "The Curling Book"** was searched but no direct chapter URLs surfaced — the book is referenced in coaching syllabi but not openly indexed.
- **CurlingZone shot-call logs / scoring datasets** (academic curling analytics) — only indirect references found; deeper crawl needed to extract the shot-classification schema used by competitive shot-percentage tracking.
- **Scottish Curling coaching pathway** PDFs were not located in this pass; their terminology occasionally diverges from Curling Canada (notably handle naming conventions for LH deliverers).
- **NCCP Levels 1–4 internal shot-classification document** is referenced from multiple club PDFs but is not freely hosted; would require a Curling Canada course-purchase to retrieve canonically.
