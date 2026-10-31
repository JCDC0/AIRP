# Persistent narrative compaction ("Chronicle")

Design for replacing the single Summarize/Context action with two selectable
compaction modes, one of which maintains a long-term narrative that accumulates
across many conversations.

Status: design, not implemented. Audited against HEAD (`0.8.2`, commit `bec2a6e`).

> Line numbers below are anchors from that audit and drift by a few lines in
> places. Re-grep for the symbol before editing; no finding's substance depends
> on an exact line.

## 1. What exists today

`ChatProvider.compressAndBranch` (`lib/providers/chat_provider.dart:1819`) is the
whole feature:

1. Flattens every message into a plain-text transcript.
2. Two `_oneShotGenerate` calls: narrative summary, then voice samples.
3. Appends both results to the CURRENT chat as AI messages, autosaves.
4. Builds a new `ChatSessionData` seeded with `[summary, voices, last N blocks]`
   and switches to it.

`SummarizeDrawer` (`lib/widgets/summarize_drawer.dart`) drives it: two editable
prompt fields persisted straight to `SharedPreferences`, a 0-40 block slider,
and one full-width **Compress** button.

## 2. Naming: do not call it a lorebook in code

A `Lorebook` already exists and means something else entirely. The current
lorebook is **current-input keyword recognition only**: `scanDepth`,
`tokenBudget`, keys, secondary AND/NOT keys, probability, inclusion groups. Its
single production caller is `ChatProvider.recognizeLoreEntriesFromInput`
(`:1168`), which scans **only the message being typed** and injects matches as a
`--- Recognized World Lore ---` block in `buildSystemInstruction`.

Reusing that vocabulary causes four concrete problems:

| Reuse | What breaks |
|---|---|
| `Lorebook` model as carrier | ~24 inert SillyTavern fields persisted per generation; the V2 round-trip contract (`test/prompt_pipeline_test.dart`) now has to hold for free narrative text |
| `LorebookEntry` as a constant entry | `LorebookStrategy.constant` activates unconditionally (`lorebook_service.dart:117`), so `previewRecognizedLoreEntry` returns the narration as `matched.first` and the chat-input glow chip is **permanently lit** on every keystroke |
| `enableLorebook` as the opt-out | One flag, two features: turning the narration off also kills keyword lore recognition. (It lives at `sillyTavernState.enableLorebook` in the config pack, not at the top level, and has no UI today.) |
| `airp_lib_lorebooks` (`LocalLibraryProvider`) | Dead code with zero callers anywhere in `lib/` or `test/`; it stores `Lorebook` objects, so reuse looks free and is not |

**Recommendation:** internal symbol `Chronicle` / `ChatMessage.isChronicle`. The
user-facing word stays whatever you want, including "Lorebook".

## 3. Delivery: a pinned chat block, not a system-prompt append

Settled by two facts in the code:

- `autoSaveCurrentSession` writes the **assembled** instruction into
  `session.systemInstruction` (`:2056`) and `loadSession` reads it back into the
  raw `_systemInstruction` field (`:2110`). Anything parked there **duplicates on
  every save/load cycle**.
- A `ChatMessage` already persists itself inside `airp_sessions`, renders in a
  bubble, and is editable through `editMessage`. No new store, no migration.

So: one `ChatMessage` with `isChronicle: true`, pinned at index 0, carried
forward by each compaction.

## 4. The two modes

Mode selector: a `DropdownButton` in the established repo idiom
(`DropdownButtonHideUnderline` + `theme.dropdownColor`, as
`model_settings_panel.dart:620`), in a **non-scrolling footer** Row added as a
third child of the drawer's `Column` after the `Expanded`. Not a `Positioned` in
the `Stack` (it would cover the Compress button) and not inside the `ListView`
(it would scroll off, which is the complaint the feature exists to fix).

The same applies to the conversation drawer's chronicle dropdown: it must be a
`Column` sibling, because that `ListView` is only reached when
`filteredSessions.isNotEmpty` - the empty case renders a `Center` instead, so a
dropdown inside the list would vanish exactly when a new user needs it.

**Mode A - Simple Compact to New Conversation.** Today's behaviour, renamed. No
logic change.

**Mode B - Compact to Chronicle.**

1. Scan `_messages` for an existing `isChronicle` block.
2. **One** `_oneShotGenerate` call - it takes a single `String` and needs **zero
   new arguments** to behave exactly like the existing two:
   - block found: "revise and extend the following chronicle" + existing body + transcript
   - no block: create-from-scratch prompt (same principles as Mode A's two
     prompts, one combined output)
3. New session seeded with `[chronicle, ...last N blocks]`, where the carried
   blocks **exclude** any previous chronicle block.

## 5. Why top-pinned

`regenerateResponse` does `_messages.removeRange(index, _messages.length)` on a
user turn (`:1725`). A tail-pinned chronicle is deleted by regenerating **any**
earlier message - the exact opposite of the "undeletable" guarantee. At index 0
that path cannot reach it.

The cost of top-pinning is that `_limitedHistory` takes a *trailing* window, so
the block must be explicitly re-pinned into the outbound request. That is two
lines, and it is mandatory - see the next section.

## 6. Change list

Ordered by what silently breaks if skipped.

### Must do, or the feature does nothing

| File | Change | If missed |
|---|---|---|
| `chat_provider.dart:1618` | `_limitedHistory`: prepend an `isChronicle` message that fell before `startIndex` | Chronicle is sent **never** when Message History is off (`effectiveHistoryLimit` becomes 0) and drops out once the conversation passes `historyLimit`. The block still renders, so the user believes it is in context. |
| `chat_provider.dart:2260` | `_estimatePromptTokens`: pin the block here too - but **write it separately**, do not copy-paste | Same trailing-limit arithmetic over a *different base*: `_limitedHistory` can also exclude the block via its `- 2` head slice, and `_recordUsage` calls `_estimatePromptTokens` with its own `messageCount`. Diverge and every estimate is short by the chronicle's whole cost; `TokenUtils.calibrate` folds the error into the ratio persisted under `airp_token_calibration`, so the meter is wrong in **every** conversation on that provider. |
| `chat_models.dart` | `isChronicle` in constructor, `toJson`, `fromJson` (`?? false`), **and `copyWith`** | `copyWith` is the quiet eraser: `collectTrailingMessages` (`:1929`), the branch builders, `finalizeBackgroundSession` (`session_service.dart:262`), `stripRegenerationHistory` and `editMessage` all rebuild through it. Serialize without threading `copyWith` and the flag dies the moment the block is carried. |

### Must do, or the block is deletable

| File | Change | If missed |
|---|---|---|
| `chat_provider.dart:2159` | `deleteMessage`: early-return on `isChronicle` | Sole enforcement point. Widget hiding is cosmetic. |
| `chat_provider.dart:1725` | `regenerateResponse` user-turn branch: `removeRange(index, _messages.length)` must skip or re-insert the block | Worst path: invisible to any bubble-level guard, triggered from a *different* message's Regenerate button. Top-pinning makes it unreachable, which is the main reason to top-pin. |
| `chat_provider.dart:1715-1717` | `regenerateResponse`: the `index - 1` user-turn lookup must **step over** a chronicle block | A chronicle immediately above an AI reply makes regenerating that reply fall into the `else` branch, which does `removeAt(index)` and returns - deleting the reply and generating nothing. The fix belongs at the lookup, not at the `removeRange` on `:1711`, which a top-pinned block never enters. |
| `chat_messages_list.dart:370-392` | `onEdit`/`onRegenerate`/`onDelete` to `message.isChronicle ? null : ...`. Leave `onCopy` and `onBranch`. | The bubble offers Delete, shows "This cannot be undone", and `_confirmDeleteMessage` shows the "Message deleted" snackbar unconditionally - so a provider-only guard produces a **lying UI**. |
| `session_service.dart:49` | `dropEmptyAssistantPlaceholders`: add `|| m.isChronicle` to the keep predicate | An emptied chronicle looks exactly like a stranded streaming placeholder and is deleted on next launch, silently. |
| `chat_provider.dart:1708,1715,1724` | `_safeDisposeMessageNotifiers` runs on the **full range immediately before** each removal (also `loadSession:2108`, `createNewSession:2092`) | A "preserve the chronicle" fix that only filters the `removeRange` still disposes its notifier. The block survives with a dead notifier. |
| **`_messages.last` overwrite family** | `session_service.dart:251`, `chat_provider.dart:2136`, `chat_provider.dart:1013` all do `messages.last.copyWith(text: ...)` guarded only by `!isUser` | **Worst data-loss path in the feature.** With `blockCount: 0` - which the drawer explicitly supports - a freshly branched conversation's chronicle is both first *and* last. A background completion, a stream reconnect on load, or the web-search progress indicator then overwrites the chronicle body with the streamed reply. Each guard needs `&& !_messages.last.isChronicle`. |

### Correctness around the pin

| File | Change |
|---|---|
| `chat_provider.dart:2043` | `autoSaveCurrentSession` titles an untitled session from `_messages.first.text`. Skip chronicle blocks, or the conversation is titled with the narration. |
| `chat_messages_list.dart:346` | `isLastMessage`: in an idle freshly branched conversation the chronicle **is** `messages.length - 1`, so it is the one message offered a Regenerate button. Covered by nulling `onRegenerate`. (`_showTypingIndicator` is unaffected - it keys on `isUser`.) |
| `chat_provider.dart:1783` | `createBranchFromMessage` seeds only the selected message, so branching drops the chronicle. Prepend it. |
| `chat_provider.dart:1887` | Mode B appends **one** block, not two, so the `_messages.length - 2` slice becomes `-1`; the carried-blocks slice must skip the old chronicle or the model sees two contradictory narrations. |
| `chat_provider.dart:1837` | The transcript builder is a bare `for (final m in _messages)` with no filter, so **the existing chronicle's full text enters the transcript as if it were dialogue**. Mode B would hand the model the chronicle twice - once as "the chronicle to revise", once buried in the transcript it is meant to summarize. Exclude `isChronicle` from the loop. |
| `chat_models.dart:192` | `DateTime.parse(json['timestamp'])` is guarded against null but not against a malformed string. Make it `tryParse` with a `DateTime.now()` fallback. | One line, and it removes the cheapest trigger for the total-loss bug in the next section. |

### Pre-existing bugs this feature will be blamed for

Fix in the same change:

- **Compact leaves the context meter near-full.** Carried blocks keep their
  `usage`, and `loadSession` then `_restoreTokenAnchorFromHistory` (`:2324`)
  walks backwards for any `prompt_tokens`, so a fresh short session anchors to
  the old long conversation. Strip `usage` from carried blocks.
- **Compact loses the chat background and bookmark**: `compressAndBranch`
  hardcodes `backgroundImage: null`, `isBookmarked: false` (`:1904`, `:1906`).
- **`_oneShotGenerate`'s Gemini branch uses `_selectedModel`** (`:1988`) while
  its OpenAI branch uses `activeModelId` (`:2004`). For Local, `_selectedModel`
  is the empty string whenever the user means Auto.

### Chronicle library + dropdown

**Implemented differently from the proposal below, deliberately.** The dropdown
derives its options from the saved sessions (`ChatProvider.availableChronicles`
scans each session for its chronicle block) instead of keeping a store of its
own. A chronicle already persists inside the conversation that produced it, and
every compaction copies it forward, so the generations *are* the history.

That removes all of the work in the rest of this section - no new prefs key, no
whitelist chain, no `chronicleId`, no `ChatSessionData.copyWith` across eight
sites - and it adds no new corruption surface. It also means chronicles travel
in `.airp` exports and config packs for free, because they ride inside the
`sessions` key that is already whitelisted.

The trade-offs, accepted: a chronicle cannot be renamed apart from its
conversation, and deleting a conversation deletes its copy. The chain survives
either way, because the next generation already holds its own copy.

The original proposal, kept for the day a chronicle needs to be a first-class
named object:

> The dropdown attaches/switches a chronicle, so chronicles must persist
independently of any one session. A **separate** `SharedPreferences` key, not
inside `airp_sessions`:

> `airp_sessions` is rewritten by a 600 ms debounce fired from ten sites, and
> `loadSessions` swallows a decode error while `persistSessions` writes anyway
> (AUDIT-0.8-ADDENDUM 2.1, live at HEAD). A chronicle is the condensed value of
> many conversations, so that blast radius is the wrong place for it.

A new key is orphaned by default. It must be added to **all** of:

- `constants.dart` (declare the key; `local_library_provider.dart` inlines
  `airp_lib_lorebooks` three times - do not copy that)
- `chat_provider.dart` `_loadSettings` / `saveSettings`
- `exportSettingsMap` / `importSettingsMap` - **both** providers have a pair
  (`chat_provider.dart:2387`/`:2418` and `settings_provider.dart:320`/`:356`);
  put the key in whichever owns the store and merge, do not overwrite
- `library_service.dart:78` `importLibrary` whitelist
- `settings_library_panel.dart:315` export map (export is hand-written, not
  derived from the whitelist - teach one without the other and the key is dead)

`ChatSessionData` also needs a `chronicleId` to bind a session to a chronicle,
and it has **no `copyWith`** - it is reconstructed field-by-field in **eight**
places (`session_service.dart` 62/137/168/223/273, `chat_provider.dart`
1794/1899/2067). Add `copyWith` first and convert all eight, or the field reverts
whenever the user bookmarks a conversation, branches from a message, or a
background reply lands.

Note the export side is already broken independently of this feature: the
`.airp` export map carries **sessions only**, so 16 of `importLibrary`'s 17
branches are unreachable from anything AIRP writes. The existing global lorebook
is already absent from every `.airp` export today. Adding a whitelist entry
without adding a matching export entry produces dead code.

`GlobalSettingsService` is not a safer harbour either: unknown keys survive a
*successful* round trip, but a corrupt `airp_global_settings_v1` blob is silently
reset and overwritten exactly like `airp_sessions`.

### Drawer traps (each has a guarding test in the repo)

- **One field for two modes is the API-key-box bug verbatim**
  (`ARCHITECTURE.md:96`, `test/api_key_panel_provider_switch_test.dart`). Give
  each mode its own controller, or force a repaint and drop focus on mode switch.
- **No focus-keyed resync guard** (`ARCHITECTURE.md:90`,
  `test/regression_0_7_30_5_test.dart`). Loading a chronicle's prompt into a
  focused field must compare against the last-seen value, not bail on focus.
- **Controller in `initState`, disposed in `dispose`** - never in `build()`.
- **`SummarizeDrawer`'s State is created once** (`chat_screen.dart:622`, no key,
  unlike `SettingsDrawer`'s `resetVersion`). `_loadPrefs` runs once per launch,
  so any external write to the mode or prompt will not show until restart.
- **`pumpAndSettle` hangs** on an unfinishable animation;
  `test/summarize_drawer_test.dart` uses it at `:43`, `:89`, `:117`. Anything the
  mode selector kicks off that spins forever under the fake clock will hang the
  suite - pump fixed frames instead (`test/service_tier_test.dart`).

### Rendering

`message_bubble/message_bubble_reasoning.dart` already is a collapsible in-bubble
disclosure. Parameterize its hardcoded "Show/Hide Thought Process" label (`:220`)
and let it take a child widget in place of the monospace `Text` (`:251`), then
reuse it. A chronicle that accumulates across generations otherwise renders as a
wall of text above every conversation.

One catch when reusing it: `_MessageBubbleReasoningState._isExpanded`
(`:119`) is nested State matched by **list position**, not by message. Inserting
a pinned block at index 0 shifts every later bubble's collapse state by one. Give
the chronicle bubble its own `Key` so Flutter matches it by identity.

**Do not** collapse it by wrapping the body in `<think>` tags. Every outbound
builder strips think blocks (`chat_api_service.dart` 241, 493, 759, 934, 1100,
1370), so the chronicle would render perfectly and reach the model as nothing.

## 7. The test that actually guards this

ARCHITECTURE.md's own warning applies directly: the lorebook engine carried
~1,400 lines of green tests against a path with no production caller for nine
versions. A flag plus a provider guard will pass every unit test while the
chronicle still falls out of `_limitedHistory` and never reaches the wire.

Required: a **send-path integration test** asserting that with
`enableMsgHistory: false` (and with a conversation longer than `historyLimit`),
the chronicle body is present in the history handed to the API layer. Plus:

- `collectTrailingMessages` preserves `isChronicle` through `copyWith`
- `deleteMessage` and all three `regenerateResponse` removals leave it in place
- `dropEmptyAssistantPlaceholders` keeps an empty chronicle
- a session round trip preserves `isChronicle` and `chronicleId`
- Mode B with an existing chronicle makes exactly one generate call, excludes the
  old chronicle from the transcript, and carries no second chronicle into the
  branch

`test/chat_provider_compress_pairs_test.dart` (`:65-104` covers
`collectTrailingMessages`) and `test/summarize_drawer_test.dart` both guard code
Mode B changes, so both will need updating.

## 8. Suggested order

1. `ChatMessage.isChronicle` (all four members) + round-trip test.
2. `_limitedHistory` and `_estimatePromptTokens` pin + the send-path integration test.
3. Delete/regenerate/placeholder guards + widget callback nulling.
4. `compressAndBranchToChronicle` + prompt constants.
5. Drawer footer mode selector.
6. Pre-existing fixes (token anchor, background, `_selectedModel`).
7. Chronicle store + `ChatSessionData.copyWith` + `chronicleId` + the full key
   whitelist chain.
8. Conversation drawer dropdown.

Steps 1-6 are the feature as described, end to end. 7-8 are what makes a
chronicle outlive a single chain of conversations.
