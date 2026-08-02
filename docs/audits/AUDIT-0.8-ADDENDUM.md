# AIRP 0.8 Audit Addendum

Audit date: 2026-07-29. Against commit `e40fac7` (`0.7.26`), branch `main`.

Companion to `AUDIT-0.8.md`. That document is still accurate and nothing in it has
been fixed yet. This addendum adds what it did not cover: a dead feature path, four
data-integrity bugs, the streaming performance profile, and a feature backlog (the
first audit was defect-only and made no feature recommendations).

Baseline re-verified at this audit:

- `flutter analyze` clean, no issues.
- `flutter test` 167 tests, all passing.

---

## 1. The lorebook does not scan conversation history

**Correction from the first draft of this document: this is not an accidental
regression.** History confirmed at `git show 8f9158e`:

```
[0.6.11.1] - Reformat Depth prompt and world lore
Replaced the legacy lorebook injection path with current-input lore recognition.
```

That commit (2026-04-26) deliberately deleted `ChatProvider._evaluateLorebooks` and
replaced it with `recognizeLoreEntriesFromInput`, whose own doc comment states it
"intentionally ignores history-based matching". The behaviour described below is
therefore the intended design as of 0.6.11.1.

What remains a defect is the residue: roughly 1,500 lines of engine and test code,
several settings fields, and an entire README chapter still describe the removed
system as if it were live. That inventory is in `docs/audits/DEAD-CODE-AND-DOCS.md`. The
decision to make here is **restore or retire**, and it should be made explicitly
rather than left in the current half state.

`PromptPipelineService.evaluateLorebooks()` is called only from
`test/prompt_pipeline_test.dart`, never from `lib/`. Verified with
`grep -rn "evaluateLorebooks" lib/ test/`.

In `sendMessage`, `lib/providers/chat_provider.dart:1381`:

```dart
const lorebookResult = LorebookEvalResult(
  byPosition: {},
  estimatedTokens: 0,
);
_lastLorebookEvalResult = lorebookResult;
final depthEntries = _collectDepthEntries(lorebookResult);
```

The evaluation result is hardcoded empty. Two consequences follow.

**1.1 Only the current user input is scanned.** The sole live path is
`recognizeLoreEntriesFromInput()` (`chat_provider.dart:1181`), which calls
`LorebookService.evaluateEntries(recentMessages: [trimmed])`. That is a
single-element list containing the message the user just typed. So:

- `scanDepth` is effectively pinned to 1 regardless of the configured value.
- An entry keyed on a word the *character* said never activates.
- An entry keyed on something the user said two messages ago never reactivates.
- Recursive activation and any multi-message keyword logic in `LorebookService`
  cannot fire, because there is only ever one message to scan.

**1.2 Positional injection is entirely dead.** `byPosition` is always `{}`, so
`buildSystemInstruction` receives an empty map and `collectDepthEntries` receives
nothing. Every one of these placements is inert in production:

`beforeCharDefs`, `afterCharDefs`, `emTop`, `emBottom`, `anTop`, `anBottom`,
`outlet`, and all `atDepth` entries.

Matched entries still reach the prompt through the `recognizedLoreEntries` list, so
lore is not *completely* absent, but it is all injected at one fixed location rather
than at each entry's declared position. The position selector in the lorebook editor
currently has no effect.

**Why the tests still pass.** `lorebook_service_test.dart` (935 lines) and
`prompt_pipeline_test.dart` (816 lines) both test `evaluateLorebooks` thoroughly and
correctly. Nothing calls it. Unit tests cannot see a service that was unwired, which
is the strongest argument for the send-path integration test in section 6.

**If restoring.** In `sendMessage`, replace the hardcoded constant with a real
evaluation over the recent history:

```dart
final lorebookResult = PromptPipelineService.evaluateLorebooks(
  lorebooks: [
    if (_globalLorebook.entries.isNotEmpty) _globalLorebook,
    if (_settings!.enableCharacterCard && _characterCard.characterBook != null)
      _characterCard.characterBook!,
  ],
  recentMessages: _messages.reversed
      .map((m) => m.isUser ? m.text : ChatMessage.sanitizeForContext(m.text))
      .toList(),
  characterName: _characterCard.name,
);
```

Note `recentMessages` must be newest-first, per the doc comment on
`evaluateLorebooks`. Apply the same change in `_runWebSearchToolLoop` and
`regenerateResponse` if they build their own result. Then decide whether
`recognizedLoreEntries` should remain as a separate mechanism or be folded into the
positional result, since keeping both risks injecting the same entry twice.

---

## 2. Data-integrity bugs

### 2.1 A corrupt sessions blob wipes every conversation, then overwrites the backup

`lib/services/session_service.dart:20`:

```dart
Future<void> loadSessions() async {
  final prefs = await SharedPreferences.getInstance();
  final String? data = prefs.getString(sessionsKey);
  if (data != null) {
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      savedSessions = jsonList.map((j) => ChatSessionData.fromJson(j)).toList();
      onStateChanged();
    } catch (e) {
      debugPrint("Error loading sessions: $e");
    }
  }
}
```

On any decode failure `savedSessions` stays `[]` and the app opens with an empty
conversation list. The user sends one message, `_scheduleAutoSave` fires 600 ms
later, and `persistSessions()` writes `[]` over `airp_sessions`. The original data
is now unrecoverable.

The trigger does not have to be exotic. `ChatMessage.fromJson`
(`lib/models/chat_models.dart:168`) calls `DateTime.parse(json['timestamp'])`
unguarded, so a single malformed timestamp anywhere in the corpus throws and aborts
the entire list. Given that `persistSessions` already has quota-exhaustion fallback
logic, a partially written blob is a realistic path in.

Three fixes, all worth doing:

1. Set a `_loadFailed` flag on catch and have `persistSessions()` refuse to write
   while it is set. Never overwrite data you failed to read.
2. Copy the raw unparseable string to `airp_sessions_corrupt_<timestamp>` before
   doing anything else.
3. Parse per session inside its own try/catch so one bad conversation costs one
   conversation, not all of them. Same for `ChatMessage.fromJson`: fall back to
   `DateTime.now()` on an unparseable timestamp rather than throwing.

### 2.2 Background stream completions are never written to disk — FIXED in 0.7.29

Both methods now call `onStateChanged()` and `persistSessions()`. Guarded by
`test/session_service_background_persist_test.dart`.

Conversations already damaged on disk are repaired on load by
`SessionService.dropEmptyAssistantPlaceholders`, which drops the empty assistant
message left behind when a completion never landed. Autosave is also flushed on
`paused`/`hidden`/`detached` via the `WidgetsBindingObserver` in `main.dart`, so
a close inside the 600 ms debounce no longer drops the last turn.

Original finding follows.

`finalizeBackgroundSession` (`session_service.dart:177`) and
`addMessageToSavedSession` (`session_service.dart:156`) both mutate
`savedSessions[idx]` and then return. Neither calls `persistSessions()`. Neither
calls `onStateChanged()`.

Every other mutator in the file (`bookmarkSession`, `deleteSession`,
`saveCurrentSessionData`, `mergeSessions`, `prependSession`) calls both.

So when a response finishes while you are looking at a different conversation:

- The drawer keeps showing the stale preview until some unrelated action triggers a
  rebuild.
- The completed reply exists only in memory. Kill the app before anything else
  writes, and the response is gone even though the notification said it arrived.

Fix: call `onStateChanged()` and `persistSessions()` at the end of both methods.

### 2.3 Message identity is positional

`ChatMessage` has no `id` field. Everything addresses messages by list index or by
`_messages.last`. This is the shared root cause of several separate symptoms:

- The `_messages.last` races already noted in `AUDIT-0.8.md` section 5.4.
- The GlobalKey bug in 2.4 below.
- `regenerateResponse(int index)`, `editMessage`, `deleteMessage`, branch, and the
  search provider's `matchMessageIndices` all break if the list shifts underneath
  them.

Adding `final String id` to `ChatMessage` (defaulted in the constructor, persisted
in `toJson`, tolerant of absence in `fromJson` for older sessions) is a small change
that makes all of the above fixable rather than merely papered over. Do it before
the section 3 provider refactor in the first audit, since the streaming callbacks
need it.

### 2.4 GlobalKeys are keyed by list index

`lib/widgets/chat_messages_list.dart:41`:

```dart
GlobalKey _keyFor(int index) => _messageKeys.putIfAbsent(
  index,
  () => GlobalKey(debugLabel: 'msg-$index'),
);
```

`GlobalKey` carries element state across rebuilds. Keying by position means that
after deleting message 3, the widget now at index 3 (formerly message 4) inherits
message 3's element. Expanded/collapsed reasoning panels, version-selector state,
and scroll anchoring attach to the wrong bubble.

`_messageKeys` is also never pruned. It is not cleared when the session changes or
when the message list shrinks, so it grows for the lifetime of the app and hands
stale keys to unrelated conversations.

Fix falls out of 2.3: key by `ValueKey(message.id)` and drop the map entirely, or
keep a `Map<String, GlobalKey>` keyed by ID if `scrollToMessage` still needs
GlobalKeys for `ensureVisible`.

### 2.5 Prior-turn images are dropped from history

Both stream builders construct history entries from text only.

`chat_api_service.dart:114`, Gemini:

```dart
for (var msg in history) {
  final parts = <Map<String, dynamic>>[
    {'text': msg.isUser ? msg.text : ReasoningUtils.stripThinkBlocks(msg.text)},
  ];
```

`chat_api_service.dart:306`, OpenAI-compatible: same shape, `"content"` is always
the string.

`msg.imagePaths` is read only for the *current* message. Attach an image, then ask a
follow-up question about it, and the model no longer has the image. It answers from
whatever it said last turn, which reads as the model forgetting or hallucinating.

Fix: rebuild multimodal parts for history messages that carry `imagePaths`. Gate it
behind a "send images from history" setting, since re-uploading every image every
turn is expensive on paid providers, and cap how far back it reaches.

---

## 3. Streaming performance

This section is the largest untapped win in the app. All three costs compound in the
same loop, so a long response gets progressively slower as it generates, which is
exactly the perceived-quality problem to fix first.

### 3.1 String accumulation is quadratic

`lib/services/streaming_coordinator_service.dart:96`:

```dart
fullText += chunk;
_activeStreamTexts[sessionId] = fullText;
contentNotifier.value = fullText;
onUpdate(sessionId, fullText, null);
```

Dart strings are immutable, so `+=` allocates and copies the entire accumulated
string on every chunk. For a 4,000 token response arriving roughly a token per
chunk, that is ~4,000 allocations averaging half the final size. Total copy volume
is O(n^2), roughly 30 MB of garbage for one medium response.

### 3.2 The full markdown AST is reparsed on every chunk

`MessageBubbleMarkdown` renders `MarkdownBody(data: text)`
(`lib/widgets/message_bubble/message_bubble_markdown.dart:46`). `flutter_markdown`
parses `data` into an AST and rebuilds the whole span tree whenever it changes.
Since `contentNotifier.value` is assigned on every chunk with no throttle, the
entire message is reparsed once per token.

The style sheet, `codeStyle`, and `CodeElementBuilder` are also constructed fresh
inside `build()`, so they are rebuilt per token too.

This is the dominant cost, and it is also O(n^2) in response length.

**Fix, in priority order:**

1. **Throttle the notifier.** Publish at most once per ~50 ms (or coalesce to one
   update per frame via `SchedulerBinding.addPostFrameCallback`). Alone this cuts
   parse work by roughly 10 to 20x and is a contained change inside
   `registerStream`. Flush unconditionally on `onDone` so the final text is exact.
2. **Use a `StringBuffer`** for accumulation and only materialise `toString()` when
   actually publishing. Combined with throttling, allocation drops from per-chunk to
   per-tick.
3. **Wrap each bubble in a `RepaintBoundary`.** There are none anywhere in the
   message list, so a repaint in one bubble dirties the layer containing all of
   them, on top of the animated background and particle overlay.
4. **Hoist the style sheet** out of `build()` and memoise it against the theme and
   font size.

### 3.3 Per-character regex in the token estimator

`chat_provider.dart:2433`:

```dart
final cjkRegex = RegExp(r'[　-〿...]');
int cjkCount = 0;
for (int i = 0; i < text.length; i++) {
  if (cjkRegex.hasMatch(text[i])) cjkCount++;
}
```

Three problems in four lines. The `RegExp` is constructed on every call rather than
hoisted to a `static final`. `text[i]` allocates a new single-character `String` per
iteration. And a full regex engine invocation per character is roughly two orders of
magnitude slower than a range comparison.

`updateTokenCount()` calls this over every message in the conversation after every
turn, so cost grows with conversation length.

Fix: hoist the pattern to a `static final`, and replace the loop body with a
`codeUnitAt(i)` range check. Same result, far cheaper.

### 3.4 Every autosave re-encodes every conversation

`persistSessions()` calls `_encodeSessionsPayload(savedSessions)`, which is
`jsonEncode` over the entire corpus, on the UI isolate, inside a 600 ms debounce
(`ChatDefaults.autoSaveDebounce`). Cost is O(all conversations ever) per saved
message, not O(the one that changed).

The first audit recommends per-session files under `path_provider` for the storage
quota reason. That change also fixes this one, and it is the stronger argument of
the two. If the migration is deferred, at minimum move the encode to a background
isolate via `compute()`.

### 3.5 Whole-screen rebuilds on every notification

`chat_screen.dart:321` and `chat_messages_list.dart:269` both use listening
`Provider.of<ChatProvider>(context)`. There is not a single `Selector` in the
codebase. So each of the 61 `notifyListeners()` sites in `ChatProvider` rebuilds:

- the full-bleed background `Image`,
- `EffectsOverlay` (525 lines of particle animation: motes, rain, fireflies),
- the entire `ListView.builder` subtree.

The `contentNotifier` design correctly keeps per-token updates off this path, which
is good, but usage chunks, thought signatures, loading-state flips, and every
settings change still go through it.

Fix: introduce `Selector` for the narrow slices the tree actually reads (message
list identity, `isLoading`, `selectedModel`), and lift the background and
`EffectsOverlay` into `const` or memoised subtrees so they are not rebuilt by chat
state at all.

### 3.6 Smaller items

- `updateTokenCount()` on Gemini makes a network `countTokens` round trip after
  every turn. Cache by message-list length plus last message length, or debounce it.
- `_cancelledSessions` in `StreamingCoordinatorService` is added to and never
  pruned.
- `StreamingCoordinatorService.dispose()` clears only `_activeStreams`, leaving
  `_activeNotifiers`, `_activeStreamTexts`, `_activeStreamModels`, and
  `_pendingNotifications` populated.

---

## 4. Correctness and robustness tweaks

- **`AiProvider.vertexAi` and `AiProvider.openAiCompatible` have no registered
  strategy.** `StrategyResolver._strategies` covers 18 of the 20 enum values; these
  two fall through to the `resolve()` fallback at `strategy_resolver.dart:90` with
  `baseUrl: ''`. The declared constants `prefListVertexAi` (`airp_list_vertexai`)
  and `prefListOpenAiCompatible` (`airp_list_openai_compatible`) are consequently
  dead, since the fallback synthesises `airp_list_${provider.name}`, which differs
  in casing. The cached model list still round-trips (both read and write go through
  `strategy.prefKey`), so this is not itself a data loss, but combined with sections
  2.1 and 2.2 of the first audit it means OpenAI Compatible is broken across
  restarts by three independent defects. Register both explicitly.

- **In-band stream sentinels can collide with model output.** `[[USAGE:` and
  `[[THOUGHT_SIG:` are detected with `chunk.startsWith`
  (`streaming_coordinator_service.dart:86`), and the payload is extracted with fixed
  offsets that assume the marker arrives alone and intact. A model that emits a line
  starting with `[[USAGE:` has it silently swallowed. Replacing `Stream<String>`
  with a sealed event type (`TextChunk`, `UsageChunk`, `SignatureChunk`) removes the
  ambiguity and the offset arithmetic at the same time.

- **`ChatMessage.copyWith` cannot clear nullable fields.** Only `contentNotifier`
  has an explicit `clearContentNotifier` escape hatch. `usage`, `thoughtSignature`,
  and `modelName` use `x ?? this.x`, so once set they can never be unset. Editing a
  message keeps the token usage of the text it replaced.

- **Gemini safety settings omit `HARM_CATEGORY_CIVIC_INTEGRITY`**
  (`chat_api_service.dart:167`). With `disableSafety` on, that category still blocks.

- **Three copies of the `customUrl` resolution**, at `chat_provider.dart:934`,
  `1586`, and `2074`. This is the mechanism behind the first audit's finding 2.2 (the
  missing Ollama branch). Extract one `String? _resolveCustomUrl(AiProvider)` helper
  so the next provider cannot be forgotten in two of three places.

- **No timeout on any LLM call** (first audit section 5, restated here because it
  interacts with 3.1: a stalled stream also holds the accumulated string alive).

---

## 5. Feature recommendations

The first audit was defect-only. These are ordered by value-to-effort for a
roleplay-focused client, and the first three are genuinely small.

**5.1 Stop sequences.** Nothing in the codebase sends `stop` or `stop_sequences`.
For roleplay this is the single most valuable missing generation control: it is what
prevents the model from writing the user's turn (`\nUser:`, `\nYou:`). One text
field, one list in the request body, supported by every provider AIRP targets.

**5.2 Repetition controls.** `generation_settings_panel.dart` exposes only
temperature, top P, top K, and max output tokens. `frequency_penalty` and
`presence_penalty` (and `repetition_penalty` for the local and Ollama paths) are
standard and directly address the repetition that long roleplay sessions produce.
`settings_slider.dart` already exists, so this is mostly plumbing through the same
eight-place provider pattern the first audit wants collapsed anyway. Worth doing
after that refactor, not before.

**5.3 Seed.** Reproducible generations, useful for comparing prompts and for
debugging. Trivial once 5.1 and 5.2 have established the parameter path.

**5.4 Continue.** Extend a truncated response in place instead of regenerating it
from scratch. Common whenever `maxOutputTokens` clips a long reply, and currently
the only recourse is a full regenerate that discards the good text. Implementable on
top of the existing stream path by seeding the assistant turn with the partial text.

**5.5 Impersonate.** Have the model draft the user's next message. A standard
roleplay feature, and `_oneShotGenerate` (`chat_provider.dart:2070`) is already the
right primitive to build it on, the same way the 0.7.25 summarize drawer does.

**5.6 Per-conversation setting overrides.** Model, temperature, and system prompt
are global. A session restores only `systemInstruction`. Pinning provider, model,
and generation parameters per conversation would mean switching conversations does
not silently change how the next reply is generated. `ChatSessionData` already has
`modelName` and `provider` fields that are saved but not authoritative on load.

**5.7 Lorebook token budget.** `LorebookEvalResult.estimatedTokens` is already
computed and surfaced, but nothing enforces a ceiling. Once section 1 is fixed and
positional entries actually activate, a large lorebook can silently consume the
context window. Add a budget cap that drops entries by ascending `order` once
exceeded. This becomes necessary rather than optional as soon as section 1 lands.

**5.8 Text-to-speech output.** No TTS anywhere in the codebase. The natural
companion to the existing visual atmosphere features, though it is the largest item
on this list.

**5.9 Group chat / multiple characters.** `CharacterCard` is singular throughout.
Substantial work, listed for completeness as the main SillyTavern-parity gap
remaining after lorebooks.

---

## 6. Testing

The section 1 bug is the clearest possible demonstration of the coverage shape
problem the first audit identified. `evaluateLorebooks` has roughly 900 lines of
correct, passing tests and zero production callers. Unit tests on services cannot
detect a service that is never invoked.

Recommended additions, in order:

1. **A send-path integration test.** Drive `ChatProvider.sendMessage` with a fake
   `ChatApiService` and assert on the assembled prompt: lorebook entries at their
   declared positions, depth entries present, history included. This one test class
   would have caught section 1, and it guards the section 3 refactor in the first
   audit.
2. **Persistence round-trip tests**, as the first audit already recommends, plus a
   corruption test: seed a malformed `airp_sessions` blob, load, save, and assert
   the original string is still recoverable (section 2.1).
3. **A background-completion test** asserting `persistSessions` is called
   (section 2.2).

---

## 7. Revised order of work

Merging both documents. Sections marked `[A]` are from `AUDIT-0.8.md`.

1. `[A]` Gemini `alt=sse`. One line, unblocks the flagship provider.
2. **Lorebook history evaluation** (section 1). Highest severity, and it makes the
   app's headline feature work as documented for the first time.
3. **Data integrity** (section 2.1 and 2.2). Corrupt-blob guard and background
   persistence. These are the only two findings across both audits that cause
   permanent, unrecoverable user data loss.
4. `[A]` The four persistence bugs, with round-trip tests.
5. **`ChatMessage.id`** (section 2.3), then the GlobalKey and `_messages.last`
   fixes that depend on it.
6. **Streaming throttle plus `StringBuffer`** (section 3.1 and 3.2). Contained,
   high perceived impact.
7. `[A]` Collapse duplicated provider state, with the send-path test from section 6
   as the safety net.
8. Remaining efficiency items (3.3 through 3.6).
9. Features, starting with stop sequences (5.1).
10. `[A]` Documentation cleanup, then the Android release blockers when a public APK
    is actually wanted.
