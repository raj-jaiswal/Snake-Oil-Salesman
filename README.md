# Snake Oil Salesman

A 2D top-down narrative/social simulation game about a broke adventurer traveling through a small town, gaining the trust of its inhabitants, and convincing them to part with their money or possessions.

The central mechanic is **open-ended conversation with AI-driven NPCs**. The player types what they actually want to say into a textbox instead of selecting from a fixed dialogue tree. Each NPC has a persistent identity, personality, background, financial limits, memories of the player, and different susceptibility to persuasion.

The game should feel like a mixture of a social sandbox, a lightweight immersive sim, and a comedic scam simulator.

> **Important design principle:** The LLM supplies natural-language interpretation and role-play. Godot remains the authoritative source of game state and rules.

---

## Premise

The player desperately wants to marry a princess. The king refuses because the player is too poor.

The player therefore sets out with one absurd objective:

> **Earn 1,000,000 Kurtos in 30 days.**

There are no normal jobs in this game. The player makes money by exploiting opportunities, convincing townspeople, performing elaborate scams, and learning how each NPC thinks.

At the end of Day 30 the player must face the king. The ending depends on money, reputation, trust, discovered secrets, NPC relationships, and the player's choices throughout the town.

---

## Core Game Loop

```text
Wake up / start day
        ↓
Explore the town
        ↓
Find NPCs and opportunities
        ↓
Talk freely using the textbox
        ↓
NPC AI interprets the conversation
        ↓
Trust / suspicion / relationship changes
        ↓
Attempt a scam, request, trade, or favor
        ↓
Game rules resolve the outcome
        ↓
Gain Kurtos / items / access / information
        ↓
NPC remembers what happened
        ↓
Continue exploring
        ↓
Day ends
        ↓
30-day deadline approaches
```

The player should constantly make choices between:

- **Low-risk conversations** that slowly build trust.
- **Medium-risk asks** that provide useful resources.
- **High-risk scams** that can generate large amounts of money.
- **Elaborate scams** requiring house access, items, or information.
- **Moving on** before an NPC becomes suspicious.

---

## Design Pillars

### 1. Conversation is gameplay

Talking is not merely exposition. The player's actual words affect NPC state.

### 2. NPCs are persistent

An NPC should remember meaningful interactions with the player. Repeatedly trying the same trick should become harder.

### 3. The world is systemic

NPCs have schedules, locations, finances, relationships, possessions, and secrets. The player can discover opportunities without a linear quest list.

### 4. The LLM is constrained

The LLM should not directly change money, inventory, quests, world state, or NPC statistics. It proposes an interpretation; deterministic game systems validate and apply the result.

### 5. Small local models are preferred

The game is intended to support offline/on-device inference where practical. Prompts must therefore be compact, outputs short, and the AI interface highly structured.

### 6. Failures are fun

A failed scam should create consequences, new dialogue, suspicion, comedy, or alternate opportunities rather than simply displaying `FAIL`.

---

## Documentation Map

| Document | Purpose |
|---|---|
| `docs/GAME_DESIGN.md` | Full gameplay and systems specification |
| `docs/STORY.md` | Story, characters, endings, narrative structure |
| `docs/NPC_AI.md` | LLM design, NPC cognition, prompts, memory, response contracts |
| `docs/TECHNICAL_ARCHITECTURE.md` | Godot architecture and code boundaries |
| `docs/DATA_SCHEMAS.md` | Recommended data structures and resource/JSON schemas |
| `docs/CONTENT_GUIDE.md` | Rules for creating NPCs, items, scams, locations, and dialogue content |
| `docs/UI_STYLE.md` | Medieval UI assets, theme, screen inventory, and presentation checks |
| `docs/LOCAL_LLM_CHAT.md` | Implemented Qwen dialogue integration, configuration, startup, and isolated tests |
| `docs/ROADMAP.md` | Milestones and implementation order |
| `AGENTS.md` | Rules for coding agents working on the repository |
| `ai/LOCAL_MODEL_PLAN.md` | Local LLM integration strategy and performance constraints |
| `data/examples/npc_example.json` | Example NPC definition |
| `data/examples/scam_example.json` | Example scam definition |

---

## Suggested Repository Structure

```text
snake-oil-salesman/
├── project.godot
├── icon.svg
├── AGENTS.md
├── README.md
├── docs/
│   ├── GAME_DESIGN.md
│   ├── STORY.md
│   ├── NPC_AI.md
│   ├── TECHNICAL_ARCHITECTURE.md
│   ├── DATA_SCHEMAS.md
│   ├── CONTENT_GUIDE.md
│   └── ROADMAP.md
├── ai/
│   └── LOCAL_MODEL_PLAN.md
├── data/
│   ├── npcs/
│   ├── items/
│   ├── scams/
│   ├── locations/
│   └── examples/
├── scenes/
├── scripts/
│   ├── game/
│   ├── npc/
│   ├── ai/
│   ├── dialogue/
│   ├── world/
│   ├── inventory/
│   └── ui/
├── assets/
└── tests/
```

---

## Development Philosophy

Prefer simple, explicit systems over highly abstract frameworks.

An AI coding agent should be able to answer these questions quickly:

1. What is the authoritative state?
2. Which system is allowed to mutate that state?
3. What does the LLM return?
4. How is the LLM response validated?
5. What happens when the model fails, times out, or produces malformed output?

If a feature cannot answer these questions, it is not ready to be integrated.
