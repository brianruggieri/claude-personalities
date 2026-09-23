#!/usr/bin/env python3
"""Generate per-notebook Agent Card JSON files from the master index.json.

These cards are A2A-shaped local manifests, NOT compliant A2A Agent Cards.
The transport is local script invocation (NDJSON over stdout); there is no
HTTP server, no SSE, and no remote endpoint. Fields like `url` and
`provider.url` are intentionally null because the spec values
(public HTTP URLs) do not apply here. The `x-curlingResearch.transport`
extension records the real, local transport.

Run after editing agent-cards/index.json. Emits one card per notebook
under agent-cards/<slug>.json, plus agent-cards/coordinator.json.

Usage:
    python3 scripts/build-cards.py [--registry path/to/registry.json]

If --registry is supplied, the script injects each notebook's NotebookLM ID
into `x-curlingResearch.notebookId` (a local extension; not an A2A spec
field). Otherwise that field is null.
"""
import argparse
import json
from pathlib import Path

SPEC_VERSION = "0.2.0"
SKILL_DIR = Path(__file__).resolve().parent.parent
INDEX_PATH = SKILL_DIR / "agent-cards" / "index.json"
CARDS_DIR = SKILL_DIR / "agent-cards"


def card_for(agent: dict, registry: dict, library_desc: str) -> dict:
    """Build a (local-manifest, A2A-shaped) Agent Card for one notebook."""
    slug = agent["slug"]
    nb_id = registry.get(slug, {}).get("notebook_id")
    return {
        "$schema": "https://google-a2a.github.io/A2A/specification/agent-card-v0.2.json",
        "protocolVersion": SPEC_VERSION,
        "name": agent["name"],
        "description": (
            f"{agent['name']} specialist for the curling-research library. "
            f"Backed by NotebookLM, surfaced over a local script transport "
            f"(no HTTP, no SSE). Use only for: "
            f"{', '.join(agent['tags'][:6])}, etc."
        ),
        "version": "1.0.0",
        # No public endpoint — invocation is via the local `ask` script.
        "url": None,
        "provider": {
            "organization": "curling-research (local)",
            # No public URL — provider is a local skill directory.
            "url": None,
        },
        "defaultInputModes": ["text/plain"],
        "defaultOutputModes": ["text/plain", "application/json"],
        "capabilities": {
            # No HTTP+SSE transport — `ask` is synchronous, NDJSON over stdout.
            "streaming": False,
            "pushNotifications": False,
            "stateTransitionHistory": False,
        },
        "securitySchemes": {},
        "skills": [
            {
                "id": s["id"],
                "name": s["name"],
                "description": s["name"],
                "tags": agent["tags"],
                "examples": s.get("examples", []),
            }
            for s in agent["skills"]
        ],
        "x-curlingResearch": {
            "slug": slug,
            "notebookFile": agent["notebookFile"],
            "notebookId": nb_id,
            "library": "curling-research",
            "libraryDescription": library_desc,
            "transport": "local-script",
            "skillDir": str(SKILL_DIR),
            "askCommand": (
                f"~/git/curling/.claude/skills/curling-research/scripts/ask "
                f"{slug} \"<question>\""
            ),
        },
    }


def coordinator_card(agents: list, library_desc: str) -> dict:
    """Build the coordinator's own card."""
    all_tags = sorted({t for a in agents for t in a["tags"]})
    return {
        "$schema": "https://google-a2a.github.io/A2A/specification/agent-card-v0.2.json",
        "protocolVersion": SPEC_VERSION,
        "name": "curling-research coordinator",
        "description": (
            "Routes curling research questions across 12 specialist NotebookLM agents "
            "(rules, physics, sweeping, shot taxonomy, strategy, player roles, equipment, "
            "ice technician, broadcast, culture & history, game design, AI opponent design). "
            "Picks specialists by tag/keyword match and dispatches in parallel; emits one "
            "Task envelope per specialist as they complete (NDJSON to stdout — not a merged "
            "single artifact, and not HTTP+SSE)."
        ),
        "version": "1.0.0",
        # No public endpoint — invocation is via the local `coordinator` script.
        "url": None,
        "provider": {
            "organization": "curling-research (local)",
            "url": None,
        },
        "defaultInputModes": ["text/plain"],
        "defaultOutputModes": ["text/plain", "application/json"],
        "capabilities": {
            "streaming": False,
            "pushNotifications": False,
            "stateTransitionHistory": False,
        },
        "securitySchemes": {},
        "skills": [
            {
                "id": "research-question",
                "name": "Cross-domain research question",
                "description": "Answer a curling research question by routing to relevant specialist notebooks.",
                "tags": all_tags,
                "examples": [
                    "How should sweeping affect a come-around draw?",
                    "What curl coefficient does the literature support for CSAS-grade ice?",
                    "Write 6 broadcast-grade narration lines for a steal of three in the 8th end.",
                    "Down two without hammer in the final end — best shot family and why?",
                ],
            }
        ],
        "x-curlingResearch": {
            "slug": "coordinator",
            "library": "curling-research",
            "libraryDescription": library_desc,
            "transport": "local-script",
            "skillDir": str(SKILL_DIR),
            "specialists": [a["slug"] for a in agents],
            "dispatchCommand": (
                "~/git/curling/.claude/skills/curling-research/scripts/coordinator "
                "<slugs-csv> \"<question>\""
            ),
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", default=str(SKILL_DIR / "registry.json"))
    args = parser.parse_args()

    index = json.loads(INDEX_PATH.read_text())
    library_desc = index["description"]

    registry = {}
    reg_path = Path(args.registry)
    if reg_path.exists():
        registry = {e["slug"]: e for e in json.loads(reg_path.read_text()).get("notebooks", [])}

    written = 0
    for agent in index["agents"]:
        card = card_for(agent, registry, library_desc)
        out = CARDS_DIR / f"{agent['slug']}.json"
        out.write_text(json.dumps(card, indent=2) + "\n")
        written += 1

    coord = coordinator_card(index["agents"], library_desc)
    (CARDS_DIR / "coordinator.json").write_text(json.dumps(coord, indent=2) + "\n")
    written += 1
    print(f"Wrote {written} Agent Cards to {CARDS_DIR}")


if __name__ == "__main__":
    main()
