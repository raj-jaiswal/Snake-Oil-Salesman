# Local Model Plan

The current Windows implementation uses the existing Qwen 2.5 0.5B GGUF through
llama.cpp HTTP chat completions for dialogue only. See
[Local NPC chat](../docs/LOCAL_LLM_CHAT.md) for configuration and verified tests.
The remaining sections describe broader future plans, not the current reply contract.

## Goal

Run the NPC language model locally so the final game does not require a paid cloud AI service for normal gameplay.

## Preferred Stack

Initial prototype:

```text
Godot 4.x
   ↓
LocalLLM abstraction
   ↓
GGUF model
   ↓
llama.cpp-based runtime / Godot integration
```

Android should use the same logical interface even if the native backend differs.

---

## Model Strategy

Start with the smallest modern instruct model that can reliably:

- understand short natural-language requests;
- maintain a simple persona;
- return structured JSON;
- generate 1–3 natural sentences;
- behave consistently under a compact prompt.

Benchmark roughly these ranges:

```text
~0.5B
~1B
~1.5B
~3B
```

Use quantization appropriate to the target hardware, typically a small 4-bit class for the first benchmark.

Do not select the model solely by parameter count. Measure:

- model file size;
- RAM usage;
- prompt processing speed;
- generation speed;
- time-to-first-token;
- structured-output reliability;
- conversation quality;
- Android thermals/battery impact.

---

## Output Budget

Initial target:

```text
context: as small as practical
output: 50–150 tokens
```

The player needs a response, not an essay.

---

## Context Budget

Build prompts from:

```text
NPC identity
+ compact personality
+ current trust/suspicion
+ 3–6 relevant memories
+ recent conversation window
+ player message
```

Never send unrelated world state.

---

## Model Loading

Load the model once and reuse it.

Do not load a model every time a player speaks.

Possible lifecycle:

```text
Game launch
   ↓
Model manager initializes
   ↓
Load GGUF
   ↓
Warm up
   ↓
Ready
   ↓
Reuse for all NPCs
```

On low-memory devices, consider loading lazily and unloading when the player disables AI mode.

---

## Android Packaging

The target architecture is:

```text
APK / AAB
├── Godot game
├── native inference library
└── GGUF model asset
```

The exact Android packaging mechanism should be implemented only after the desktop prototype works.

Keep the model path configurable so the development build can load a model externally.

For release builds, the final selected model may be bundled with the app or delivered as an install-time asset, depending on package-size constraints.

---

## Quality Fallbacks

If the model is unavailable:

```text
AI unavailable
    ↓
use deterministic response templates
    ↓
continue gameplay
```

This is also useful for automated testing.

---

## Benchmark Scene

Create a dedicated scene that runs the same 20–50 prompts against candidate models.

Collect:

```text
model
prompt length
generation tokens
latency
tokens/sec
valid JSON?
correct intent?
response length
```

Human-rank responses on:

```text
persona consistency
context awareness
naturalness
game usefulness
```

The benchmark should determine the final model rather than marketing benchmarks.
