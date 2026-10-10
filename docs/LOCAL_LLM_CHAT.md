# Local NPC chat

`scripts/local_llm.gd` uses asynchronous Godot `HTTPRequest` calls to the
existing llama.cpp server. It sends one OpenAI-compatible chat completion per
player message and reads only `choices[0].message.content`. Barnaby, Marla,
Cedric, Arthur, and other NPCs using the same chat panel receive their authored
name, role, background, personality, values, fears, and speech style.

## Start the existing server separately

The executable and model were verified in this directory. No server is launched
by the game and no model download is required.

```powershell
Set-Location 'C:\Zekrui\llama-b11476-bin-win-cpu-x64'
.\llama-server.exe -m '.\qwen2.5-0.5b-instruct-q4_k_m.gguf' --host 127.0.0.1 --port 8080 -c 2048
```

Wait for the model to finish loading, open the game, approach Barnaby, and use
the existing chat panel. The AI status button can recheck the connection.
Each Send also attempts a fresh request, allowing recovery after an outage.
The server API is described in the
[official llama.cpp server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md).

## Central configuration

Select the existing `LocalLLM` child in `scenes/ui/chat_ui.tscn` to override
exported properties in the Inspector; defaults live in `scripts/local_llm.gd`.

| Property | Default |
|---|---|
| `enabled` | `true`; false uses existing canned replies without inference |
| `server_url` | `http://127.0.0.1:8080/v1/chat/completions` |
| `health_url` | Empty derives `/health` from the API host |
| `model_name` | `qwen2.5-0.5b-instruct-q4_k_m.gguf` |
| `temperature` / `max_tokens` | `0.65` / `100` |
| `request_timeout_seconds` / `health_timeout_seconds` | `30` / `2` |
| `history_exchanges` | `4` recent exchanges per NPC (maximum 5) |
| `max_turn_characters` / `max_player_characters` / `max_reply_characters` | `300` / `1000` / `640` |

Core networking contains no Windows filesystem paths. A later Android client
can use a reachable endpoint; Android deployment or inference is not included.

## Gameplay and memory boundaries

The existing offline evaluation heuristic and `ScamManager` threshold rules
compute the result independently of generation. The existing chat resolver
applies it once through the existing economy and NPC methods. No formulas,
rewards, penalties, budgets, inventory rules, or save format were changed.
The former model evaluator no longer supplies scores or transaction fields.
Live and fallback replies therefore use the same deterministic gameplay result.

History uses the NPC's existing conversation array, bounded per NPC and sent
as separate user/assistant messages. The current player message appears once.
Reopening a conversation restores its history without adding another greeting.
Existing day rollover clears history. Existing saves do not persist NPC chat
history; this integration does not add a second persistence system.

Closing chat or switching NPC cancels generation and discards the incomplete
turn, restoring earlier turns even when the history cap evicted one while sending.
A day reset during generation is respected rather than rolled back.
Request IDs prevent stale or duplicate callbacks from applying effects.
Malformed/missing history is ignored; only complete user/assistant exchanges
for the current NPC are sent, preventing foreign speakers or forged roles.
Player and model text are escaped for the existing rich-text chat display.
Connection errors, timeout, malformed JSON, or empty content produce one
existing fallback reply and restore input. No failed generation is retried
automatically for that player action.

## Verification without touching real saves

```powershell
.\tests\run_isolated.ps1
# Optional real inference check, after starting the server:
.\tests\run_isolated.ps1 -Tests test_llm_connection.gd
```

The runner stages shared sources under `.godot/qwen-test-project` and uses
separate application data under `.godot/qwen-test-userdata`. It restores the
process environment afterward; the normal project's save directory is untouched.

Default suites cover the loopback mock HTTP server, corrupted history, real
pending-request cancellation, per-NPC memory, hostile model text, duplicate
submissions, gameplay, desktop/mobile presentation, and actual title
Start/Continue, save/load, movement, inventory opening and world pickup paths.
All UI/input events are programmatic, not physical mouse/touch tests.

Logs are under `.godot/`. The optional live test uses the actual chat panel for
three exchanges each with Barnaby, Marla, Cedric and Arthur. It checks real
generated text, request/NPC association, memory assembly, and UI completion.
An unavailable server is explicitly **SKIPPED**, not a pass. Color recall and
persona keyword observations are recorded separately from transport checks in
`.godot/qwen-test-project/.godot/llm-live-report.json`; keyword matches alone
do not establish complete personality fidelity. The existing server passed
live checks during the automated testing follow-up.

The greeting investigation found that existing threshold rules can penalize
plain greetings for Marla and Arthur. The unchanged heuristic gives score 55,
which is not above their initial trust (65 and 55). This yields -3 trust,
+6 suspicion and -1 reputation, including when the model reply is friendly.
The same branch existed before this integration; no balance changes were made.

## Automated follow-up results (2026-10-10)

The existing healthy server was reused and left running. Final validation:
227 mock chat/authority checks, 200 existing gameplay checks, 29 title/save/world
checks, both desktop/mobile presentation suites, and 64 live integration checks
passed with no failed assertions or parser errors. Live tests generated 12
replies across all four NPCs; all four recalled BLUE and matched broad persona
keywords. See `.godot/llm-final-validation.log` and the live JSON report above.

Three confirmed history bugs were fixed: invalid cached history returning the
wrong type, foreign/forged history speakers entering prompts, and cancellation
at the five-exchange cap evicting an older turn. Tests reproduce those cases,
including a day reset while a reply is pending. No gameplay formula changes
were made.

Real dialogue quality is not perfect: some replies reverse buyer/seller roles,
contradict NPC wealth, or invent transaction details. These are observed model
quality limitations with correctly assembled context; generated text cannot
execute those claims. Keyword matches are not a full semantic personality test.
Physical mouse/touch, device keyboard and visual review were not performed.
Existing certificate-store and title-texture UID fallback warnings remain.
The updated title test frees its fixtures; the final runs had no resource-leak
warnings.
