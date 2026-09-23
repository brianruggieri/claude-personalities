# Curling Physics

> Part of the curling-research skill for ~/git/curling. Paste the URLs below into a NotebookLM notebook with this name.

## Scope

This notebook is the canonical reference for the *physics of a single curling stone in motion on pebbled ice*, plus stone-on-stone collisions. It collects the primary peer-reviewed literature on the curl-mechanism debate (Shegelski's wet/dry asymmetric friction, the Nyberg/Honkanen scratch-guidance theory, Maeno's evaporation-abrasion model, Shegelski-Lozowski and Mancini pivot-slide variants, Murata's slow-side pivot model, Penner/Denny first-principles asperity models), the Stribeck-curve mixed-lubrication regime that governs ice friction, instrumented-stone and high-speed video kinematic measurements, running-band geometry and surface-roughness studies, asperity-melt and quasi-liquid-layer ice friction physics, and elastic stone-on-stone collisions including coefficient-of-restitution data and Hertzian impact mechanics. **Excludes:** the physics and biomechanics of brushing/sweeping (Notebook 03 — Sweeping), ice-technician practice and pebbling procedure (Notebook 08 — Ice Technician), and equipment material science not directly tied to motion (Notebook 07 — Equipment). Where a paper covers both stone motion and sweeping, only the stone-motion content is in scope here.

## Coverage Outline

- **Curl-mechanism theories** — wet/dry asymmetric friction (Shegelski et al.), scratch-guidance (Nyberg/Honkanen), evaporation-abrasion (Maeno), pivot-slide (Shegelski-Lozowski, Mancini), slow-side pivot / velocity-dependent asymmetry (Murata), asperity-based pivot-slide (Jenkins/Diosady 2025), grit-and-debris transfer (Denny).
- **Ice friction physics** — Stribeck curve and mixed lubrication regime, asperity-melt and quasi-liquid-layer theories, frictional heating and meltwater films, velocity dependence of μ, ice deformation and ploughing.
- **Running-band geometry & surface roughness** — annular contact-band hydrodynamics, dependence of curl on stone-bottom roughness and band area, pebble-stone contact pressure (~0.4–8.1 MPa over 10–100 pebbles).
- **Instrumented-stone & kinematic measurement** — IMU/MEMS on-stone telemetry, high-speed and computer-vision tracking, precision digital-image kinematics, Olympic-rink friction-coefficient measurement (Beijing 2022).
- **Pebble interaction & ice-surface geometry** — pebble shape, abrasion-per-pass, evolution of running-band/pebble contact during a game.
- **Stone-on-stone collisions** — coefficient of restitution for granite, Hertzian cone fracture and stress regimes, momentum/angular-impulse transfer, double-takeout geometry.
- **Historical & review** — 1996 Shegelski-Niebergall-Walton baseline, century-spanning review of competing hypotheses (Maeno 2023), modern syntheses.

## Sources (25)

### 1. The motion of a curling rock (Shegelski, Niebergall, Walton 1996)
- **URL:** https://cdnsciencepub.com/doi/10.1139/p96-095
- **Type:** paper
- **Why it matters:** The foundational analytical paper of the modern curl-mechanism debate; introduces the wet/dry asymmetric-friction hypothesis (kinetic-friction-induced ice melting + film-drag) that every later theory either extends or refutes.

### 2. The motion of curling rocks: Experimental investigation and semi-phenomenological description (Jensen & Shegelski 2004)
- **URL:** https://www.researchgate.net/publication/237202460_The_motion_of_curling_rocks_Experimental_investigation_and_semi-phenomenological_description
- **Type:** paper
- **Why it matters:** Companion experimental paper to Shegelski's analytical model; provides the stop-watch / video data and the parameter fits that calibration efforts (including this repo's) still cite as a baseline.

### 3. The physics of sliding cylinders and curling rocks (Penner 2001)
- **URL:** https://aapt.scitation.org/doi/10.1119/1.1309524
- **Type:** paper
- **Why it matters:** AJP paper that first showed front-back symmetry friction *cannot* by itself explain curl direction — narrowed the search space and made left-right asymmetry the consensus problem.

### 4. The asymmetrical friction mechanism that puts the curl in the curling stone (Nyberg, Alfredsson, Hogmark, Jacobson 2013)
- **URL:** https://www.sciencedirect.com/science/article/abs/pii/S0043164813000732
- **Type:** paper
- **Why it matters:** Wear-journal paper that introduced the scratch-guidance theory: leading-edge asperities scratch the ice, trailing-edge asperities cross those scratches at a small angle and follow them, generating the lateral force. Directly competing alternative to Shegelski's wet-friction model.

### 5. A surface topography analysis of the curling stone curl mechanism (Honkanen, Ovaska, Alava, Ronkainen, Koivisto 2018)
- **URL:** https://www.nature.com/articles/s41598-018-26595-y
- **Type:** paper
- **Why it matters:** White-light interferometer scans of the ice before/after each slide directly imaged the cross-scratches predicted by Nyberg, and showed the transverse force scales linearly with cross-scratch angle — the strongest experimental support for scratch-guidance.

### 6. A Scratch-Guide Model for the Motion of a Curling Rock (Shegelski & Lozowski 2019)
- **URL:** https://link.springer.com/article/10.1007/s11249-019-1144-0
- **Type:** paper
- **Why it matters:** Tribology Letters paper that operationalises scratch-guidance as a quantitative trajectory model; the version most often plugged into simulators (including the precursor to this repo's curl model).

### 7. Pivot–slide model of the motion of a curling rock (Shegelski & Lozowski 2016)
- **URL:** https://cdnsciencepub.com/doi/10.1139/cjp-2016-0466
- **Type:** paper
- **Why it matters:** Introduces the pivot-slide model — brief pivot around a contact point followed by a longer slide — that produces the right curl-distance magnitude and weak rotation-rate dependence; the structural basis for several later refinements.

### 8. Improved pivot–slide model of the motion of a curling rock (Mancini & de Schoulepnikoff 2019)
- **URL:** https://cdnsciencepub.com/doi/abs/10.1139/cjp-2018-0356
- **Type:** paper
- **Why it matters:** Adds velocity dependence to the pivot/slide-time ratio, recovering the empirical fact that slower stones curl more and that sweeping reduces curl — exactly the hooks a game simulator needs.

### 9. First principles pivot-slide model of the motion of a curling rock (Lozowski & Shegelski 2017)
- **URL:** https://www.sciencedirect.com/science/article/abs/pii/S0165232X17302975
- **Type:** paper
- **Why it matters:** Cold Regions S&T paper deriving the pivot-slide trajectory from first principles and giving qualitative + quantitative predictions used by every later validation paper.

### 10. Study of curling mechanism by precision kinematic measurements of curling stone's motion (Murata 2022)
- **URL:** https://www.nature.com/articles/s41598-022-19303-4
- **Type:** paper
- **Why it matters:** Scientific Reports paper using digital image analysis to argue the curl is dominated by left-right asymmetric *velocity-dependent* friction at discrete pebble contacts, with the stone swinging around slow-side pivot points — the most-cited recent reframing of the mechanism.

### 11. arXiv preprint of Murata 2022 (precision kinematic measurements)
- **URL:** https://arxiv.org/abs/2203.00347
- **Type:** paper
- **Why it matters:** Open-access preprint of source #10 with the full method and supplementary appendices, useful when the Nature version is paywalled or when the simulator needs the exact tracking-resolution figures.

### 12. The importance of the surface roughness and running band area on the bottom of a stone for the curling phenomenon (Ivanov & Shatrov 2020)
- **URL:** https://www.nature.com/articles/s41598-020-76660-8
- **Type:** paper
- **Why it matters:** Scientific Reports paper showing curl distance is primarily set by stone-bottom roughness and running-band area, not by ice condition — directly informs how the simulator should parameterise stone-vs-ice contributions.

### 13. Ice Deformation Explains Curling Stone Trajectories (Denny 2022)
- **URL:** https://link.springer.com/article/10.1007/s11249-022-01582-7
- **Type:** paper
- **Why it matters:** Tribology Letters paper proposing asymmetric normal/radial/COM-drag forces from ice deformation and grit/debris distribution, addressing the crucial fact that curl distance is roughly *independent* of initial spin rate.

### 14. A First-Principles Model of Curling Stone Dynamics (Denny 2022)
- **URL:** https://link.springer.com/article/10.1007/s11249-022-01623-1
- **Type:** paper
- **Why it matters:** Companion Tribology Letters paper deriving an asymmetric-grit-transfer trajectory model "with almost no free parameters"; one of the few models that ties both rotation independence and roughness dependence into one framework.

### 15. Why Curling Stones Curl: Modelling and Numerical Experiments (Ohashi 2022)
- **URL:** https://link.springer.com/article/10.1007/s11249-022-01648-6
- **Type:** paper
- **Why it matters:** Tribology Letters paper running numerical experiments on the front-back asperity double-pass mechanism — useful as an independent simulation cross-check for any in-house curl model.

### 16. Asperity-based pivot–slide model of curling stone motion (Jenkins, Jenkins, Diosady 2025)
- **URL:** https://cdnsciencepub.com/doi/10.1139/cjp-2024-0305
- **Type:** paper
- **Why it matters:** Newest extension of pivot-slide; ascribes motion to interactions between running-band asperities and pebbles with asymmetric water-layer thickness. The current frontier reference for asperity-level simulation.

### 17. Calculated Trajectories of Curling Stones Sliding Under Asymmetrical Friction: Validation of Published Models (Shegelski & Lozowski 2013)
- **URL:** https://link.springer.com/article/10.1007/s11249-013-0135-9
- **Type:** paper
- **Why it matters:** Cross-validation paper that integrates the equations of motion under several asymmetrical-friction hypotheses and compares trajectories — the canonical "do these models actually reproduce real shots" benchmark.

### 18. Dynamics and curl ratio of a curling stone (Maeno 2014)
- **URL:** https://link.springer.com/article/10.1007/s12283-013-0129-8
- **Type:** paper
- **Why it matters:** Sports Engineering paper formalising the *curl ratio* (lateral deflection / forward distance) and developing the evaporation-abrasion variant of the friction-asymmetry model; gives concrete numerical curl-ratio targets for calibration.

### 19. Curl Mechanism of a Curling Stone on Ice Pebbles (Maeno 2010)
- **URL:** https://www.jstage.jst.go.jp/article/bgr/28/0/28_0_1/_article
- **Type:** paper
- **Why it matters:** Original statement of Maeno's evaporation-abrasion mechanism: rear-running-band ice cooled by pebble-evaporation has higher μ than the front, producing the asymmetry. Key to understanding why ice temperature/quality matters in the simulator.

### 20. Assignments and progress of curling stone dynamics (Maeno 2016/2023 review)
- **URL:** https://journals.sagepub.com/doi/abs/10.1177/1754337116647241
- **Type:** paper
- **Why it matters:** IMechE Part P review by the dean of curling physics surveying the century-long debate; the single best entry point for understanding why the mechanism is still contested.

### 21. Comparison of IMU Measurements of Curling Stone Dynamics with a Numerical Model (Lozowski et al., Procedia Engineering 2016)
- **URL:** https://www.sciencedirect.com/science/article/pii/S1877705816306932
- **Type:** paper
- **Why it matters:** Procedia Engineering paper instrumenting a stone with a MicroStrain MEMS IMU at ~1 kHz and comparing measured linear/angular velocities to the pivot-slide model — gold-standard real-stone data for comparing against simulator output.

### 22. Experimental Measurement of Ice-Curling Stone Friction Coefficient Based on Computer Vision Technology — Beijing 2022 "Ice Cube" (Liu et al. 2022)
- **URL:** https://www.mdpi.com/2075-4442/10/10/265
- **Type:** paper
- **Why it matters:** Lubricants paper measuring μ on the actual Olympic ice via YOLO-v3 + CSRT tracking; reports μ ~0.007–0.012 declining with velocity — the cleanest modern empirical Stribeck-curve evidence on a competition rink.

### 23. Correlations between curling stone frictions and tribology's Stribeck curve: concepts to consider (Brown 2024)
- **URL:** https://cdnsciencepub.com/doi/10.1139/cjp-2024-0095
- **Type:** paper
- **Why it matters:** Canadian Journal of Physics 2024 paper laying out why the three-segment glide (high-speed mild deceleration → mid-speed greater deceleration → abrupt stop) maps cleanly onto Stribeck's hydrodynamic / mixed / boundary regimes; structural justification for any Stribeck-style μ(v) model.

### 24. Characteristics of pebble shape and the amount of pebble abrasion measured with a replica reproduced on a curling rink (Kameda et al. 2024)
- **URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC11106237/
- **Type:** paper
- **Why it matters:** Replica-and-profilometry study quantifying pebble geometry, contact-pressure (0.4–8.1 MPa over 10–100 pebbles per stone), and per-shot pebble-top abrasion (~1 µm) — the empirical inputs needed for any wear/track model.

### 25. The slippery science of Olympic curling: we still don't know how it works (UNSW / The Conversation, Hutchinson 2022)
- **URL:** https://theconversation.com/the-slippery-science-of-olympic-curling-we-still-dont-know-how-it-works-176463
- **Type:** article
- **Why it matters:** Plain-language synthesis by a tribologist that maps each competing theory (wet/dry, scratch-guide, evaporation-abrasion, asperity-melt) to its supporting experiment, with peer-reviewed sourcing — useful as a reading-order roadmap for new contributors.

## Supplementary Sources (5)

*Scrape-tested additions, 2026-04-26. Original pass had high failure rate on Springer/Conversation paywalls; these supplement with open-access equivalents and address gaps called out in CLAUDE.md (post-2020 numerical simulations, instrumented-stone open data, granite collision/fracture mechanics, modern ice-friction MD simulations, and an open-access reading-order roadmap to replace #25's cookie-walled Conversation piece).*

### S1. Quasi liquid layer-pressure asymmetrical model for the motion of a curling rock on ice surface (Wei, arXiv 2023)
- **URL:** https://arxiv.org/abs/2302.11348
- **Type:** preprint
- **Why it matters:** Post-2020 mechanism paper that ties curl direction directly to QLL pressure asymmetry — a structurally different competitor to scratch-guidance, pivot-slide, and evaporation-abrasion. Adds an open-access primary source for the QLL-driven branch of the curl-mechanism debate that none of the original 25 cover.
- **Pre-flight:** verified HTTP 200 via WebFetch — title and abstract render as expected ("...we present a new model based on Quasi liquid layer to explain why the direction of lateral motion of the curling rock on ice surface is opposite to the other material surface").

### S2. Where curling stones collide with rock mechanics: cyclical damage accumulation and fatigue in granitoids (Leung, Fusseis, Butler — Solid Earth 2026)
- **URL:** https://se.copernicus.org/articles/17/429/2026/
- **Type:** paper
- **Why it matters:** Open-access (CC-BY) Copernicus paper using curling-stone collisions as a rock-physics experiment — quantifies impact stress at 300–680 MPa, characterises Hertzian cone-fracture geometry within the striking band (~2–2.5 fractures/cm, 3–5 cm radial penetration), and shows damage saturates early so subsequent impacts propagate rather than create fractures. Directly fills the granite-COR / Hertzian-cone fracture gap mentioned in CLAUDE.md and provides empirical bounds for any collision-damage model.
- **Pre-flight:** verified HTTP 200 via WebFetch — DOI 10.5194/se-17-429-2026, full text accessible under CC-BY.

### S3. Acceleration-Based Method of Ice Quality Assessment in the Sport of Curling (Dzikowski, Weremczuk, Pachwicewicz — Sensors 2022, PMC)
- **URL:** https://pmc.ncbi.nlm.nih.gov/articles/PMC8839312/
- **Type:** paper
- **Why it matters:** Open-access PMC mirror of an MDPI Sensors paper that mounts an IMU at 400 Hz on a competition stone and uses frequency-domain accelerometer features to score ice quality — gives a different, cheaper instrumented-stone protocol than the MicroStrain rig in source #21, plus a published method for empirically separating "fast" from "swingy" ice. Direct open-access alternative for the instrumented-stone-data gap.
- **Pre-flight:** verified HTTP 200 via WebFetch — Sensors 22(3):1074 confirmed, full text and figures accessible.

### S4. Ice friction at the nanoscale (Baran, Llombart, Rzysko, MacDowell — arXiv / PNAS 2022)
- **URL:** https://arxiv.org/abs/2206.01313
- **Type:** preprint
- **Why it matters:** Atomistic MD-simulation paper (published PNAS, open arXiv mirror) that derives ice friction from first principles via the QLL and matches macroscopic μ to within experimental scatter — gives a microscale physical foundation for the Stribeck-curve observations in sources #22 and #23, and a reproducible numerical pipeline absent from the original 25. Authoritative post-2020 reference for the QLL-mediated lubrication regime.
- **Pre-flight:** verified HTTP 200 via WebFetch — arXiv 2206.01313, PNAS 2022; abstract and full PDF available.

### S5. An examination of studies related to the sport of curling: a scoping review (Zacharias, Robak, Passmore — Frontiers in Sports and Active Living 2024)
- **URL:** https://www.frontiersin.org/articles/10.3389/fspor.2024.1291241/full
- **Type:** paper (review)
- **Why it matters:** Open-access (CC-BY) scoping review of 94 peer-reviewed curling studies across ten themes (curl mechanics, sweeping, delivery biomechanics, AI applications, etc.) with an explicit map of which controversies remain open in stone-trajectory and friction physics — replaces source #25's cookie-walled Conversation piece as the recommended reading-order roadmap for new contributors and provides the up-to-date citation network.
- **Pre-flight:** verified HTTP 200 via WebFetch — Front. Sports Act. Living 6:1291241 (2024), full text including all 94 references accessible without login.
