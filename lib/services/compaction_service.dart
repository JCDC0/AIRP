import 'dart:convert';

/// One user-defined step of the original compact system.
///
/// The compact system used to be exactly two hardcoded prompts (summary, voice
/// samples) whose outputs became two separate chat messages. It is now an
/// ordered list of rules whose outputs are edits against ONE shared document,
/// so the result is a single block that the rules compose rather than
/// concatenate.
class CompactRule {
  /// Stable id, used to key the drawer's per-rule text controllers.
  final String id;

  /// Short label shown in the drawer and in the progress readout.
  String name;

  /// The instruction sent to the model for this rule.
  String prompt;

  /// Disabled rules are skipped without being deleted.
  bool enabled;

  CompactRule({
    required this.id,
    required this.name,
    required this.prompt,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'prompt': prompt,
    'enabled': enabled,
  };

  factory CompactRule.fromJson(Map<String, dynamic> json) => CompactRule(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Rule',
    prompt: json['prompt'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
  );

  CompactRule copyWith({String? name, String? prompt, bool? enabled}) =>
      CompactRule(
        id: id,
        name: name ?? this.name,
        prompt: prompt ?? this.prompt,
        enabled: enabled ?? this.enabled,
      );
}

/// How a rule's tool call changes the shared document.
enum DocumentEditMode {
  /// Create the section, or overwrite its body if it exists.
  replace,

  /// Add to the end of an existing section's body, creating it if absent.
  append,

  /// Delete the section.
  remove,
}

DocumentEditMode _modeFromName(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'append':
      return DocumentEditMode.append;
    case 'remove':
    case 'delete':
      return DocumentEditMode.remove;
    default:
      return DocumentEditMode.replace;
  }
}

/// One heading plus its body.
class DocumentSection {
  final String heading;
  final String body;

  const DocumentSection({required this.heading, required this.body});
}

/// The shared document the compact rules edit.
///
/// Sectioned rather than a flat string so a later rule can revise what an
/// earlier one wrote instead of only appending to it, and so the document
/// round-trips through markdown: an existing summary or chronicle block can be
/// parsed back in and edited further on the next compaction.
class CompactDocument {
  final List<DocumentSection> sections;

  CompactDocument({List<DocumentSection>? sections})
    : sections = sections ?? <DocumentSection>[];

  bool get isEmpty => sections.every((s) => s.body.trim().isEmpty);

  /// Applies one edit, matching an existing section by case-insensitive,
  /// trimmed heading so the model does not create "Cast" and "cast" as two
  /// sections across rules.
  void applyEdit({
    required String heading,
    required String content,
    DocumentEditMode mode = DocumentEditMode.replace,
  }) {
    final key = heading.trim();
    if (key.isEmpty) return;
    final index = sections.indexWhere(
      (s) => s.heading.trim().toLowerCase() == key.toLowerCase(),
    );

    if (mode == DocumentEditMode.remove) {
      if (index >= 0) sections.removeAt(index);
      return;
    }

    if (index < 0) {
      sections.add(DocumentSection(heading: key, body: content.trim()));
      return;
    }

    final existing = sections[index];
    final body = mode == DocumentEditMode.append
        ? '${existing.body.trimRight()}\n\n${content.trim()}'.trim()
        : content.trim();
    sections[index] = DocumentSection(heading: existing.heading, body: body);
  }

  /// Applies a raw tool-call argument blob.
  ///
  /// Returns the heading touched, or null when the payload was unusable. The
  /// model controls this JSON, so every field is treated as untrusted and a
  /// malformed blob is skipped rather than thrown.
  String? applyToolArguments(String rawJson) {
    Map<String, dynamic> args;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) return null;
      args = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    final heading = args['heading'];
    final content = args['content'];
    if (heading is! String || heading.trim().isEmpty) return null;
    applyEdit(
      heading: heading,
      content: content is String ? content : '',
      mode: _modeFromName(args['mode'] as String?),
    );
    return heading.trim();
  }

  /// Renders to markdown. Headings are `##` so they paint through the
  /// markdown structure colour, which the Summarize drawer's own output
  /// already relies on.
  String render() {
    final buf = StringBuffer();
    for (final s in sections) {
      if (s.body.trim().isEmpty) continue;
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('## ${s.heading}');
      buf.writeln();
      buf.writeln(s.body.trim());
    }
    return buf.toString().trimRight();
  }

  /// Parses markdown produced by [render], and degrades sensibly on anything
  /// else: text before the first heading becomes an untitled leading section
  /// so no content is silently dropped.
  factory CompactDocument.parse(String text) {
    final doc = CompactDocument();
    final lines = text.split('\n');
    String? heading;
    final body = <String>[];

    void flush() {
      final joined = body.join('\n').trim();
      body.clear();
      final current = heading;
      if (current == null) {
        if (joined.isNotEmpty) {
          doc.sections.add(DocumentSection(heading: 'Summary', body: joined));
        }
        return;
      }
      doc.sections.add(DocumentSection(heading: current, body: joined));
    }

    for (final line in lines) {
      final match = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line.trimLeft());
      if (match != null) {
        flush();
        heading = match.group(1)!.trim();
        continue;
      }
      body.add(line);
    }
    flush();
    return doc;
  }
}

/// Prompt assembly and tool specs for the rule-driven compact system.
class CompactionService {
  CompactionService._();

  static const String toolName = 'edit_document';

  static const String _toolDescription =
      'Edit the shared compaction document. Call this exactly once with the '
      'section you are responsible for. Use mode "replace" to write or rewrite '
      'a section, "append" to add to what an earlier rule already wrote, and '
      '"remove" to delete a section that the conversation has made obsolete. '
      'Write the section body as plain markdown prose, with no heading inside '
      'the content field.';

  static const String systemInstruction =
      'You maintain a single shared reference document that summarises a '
      'roleplay conversation. You are given the document as it stands and one '
      'instruction describing the section you are responsible for. Make your '
      'contribution by calling the edit_document tool exactly once. Record only '
      'what the transcript establishes; invent nothing. Do not restate sections '
      'another rule already owns.';

  /// OpenAI-compatible tool spec.
  static Map<String, dynamic> buildToolSpec() => {
    'type': 'function',
    'function': {
      'name': toolName,
      'description': _toolDescription,
      'parameters': {
        'type': 'object',
        'properties': {
          'heading': {
            'type': 'string',
            'description':
                'The section heading to write, for example "Story So Far", '
                '"Cast", "Relationships" or "Open Threads". Reuse an existing '
                'heading exactly when revising it.',
          },
          'content': {
            'type': 'string',
            'description':
                'The section body as markdown prose. Do not include the '
                'heading itself.',
          },
          'mode': {
            'type': 'string',
            'enum': ['replace', 'append', 'remove'],
            'description':
                'replace to write or rewrite the section, append to extend it, '
                'remove to delete it.',
          },
        },
        'required': ['heading', 'content'],
      },
    },
  };

  /// Gemini function declaration. Same tool, uppercase schema types and no
  /// `function` wrapper, matching the split the web search tool already makes.
  static List<Map<String, dynamic>> buildGeminiFunctionDeclarations() => [
    {
      'name': toolName,
      'description': _toolDescription,
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'heading': {
            'type': 'STRING',
            'description':
                'The section heading to write, for example "Story So Far", '
                '"Cast", "Relationships" or "Open Threads". Reuse an existing '
                'heading exactly when revising it.',
          },
          'content': {
            'type': 'STRING',
            'description':
                'The section body as markdown prose. Do not include the '
                'heading itself.',
          },
          'mode': {
            'type': 'STRING',
            'description':
                'One of replace, append or remove. replace to write or rewrite '
                'the section, append to extend it, remove to delete it.',
          },
        },
        'required': ['heading', 'content'],
      },
    },
  ];

  /// The per-rule prompt: the rule's own instruction, the document so far, and
  /// the transcript.
  ///
  /// The document is included so a rule can revise earlier rules' work, which
  /// is the whole point of editing one document instead of concatenating
  /// separate answers.
  static String buildRulePrompt({
    required CompactRule rule,
    required CompactDocument document,
    required String transcript,
  }) {
    final buf = StringBuffer();
    buf.writeln('YOUR INSTRUCTION (rule "${rule.name}"):');
    buf.writeln(rule.prompt.trim());
    buf.writeln();
    if (!document.isEmpty) {
      buf.writeln('DOCUMENT SO FAR:');
      buf.writeln(document.render());
      buf.writeln();
    } else {
      buf.writeln('DOCUMENT SO FAR: (empty, you are the first rule)');
      buf.writeln();
    }
    buf.writeln('CONVERSATION TRANSCRIPT:');
    buf.writeln(transcript);
    return buf.toString().trimRight();
  }

  /// A model that answered with prose instead of calling the tool still did
  /// the work, so its text is filed under the rule's own name rather than
  /// discarded.
  static String fallbackHeadingFor(CompactRule rule) =>
      rule.name.trim().isEmpty ? 'Summary' : rule.name.trim();

  /// Builds the initial rule list from the legacy two prompts.
  ///
  /// Carries the user's own edited text across rather than resetting to the
  /// defaults: these two prompts have been editable and persisted since
  /// 0.7.x, so replacing them on upgrade would throw away real work.
  static List<CompactRule> migrateLegacyRules({
    required String compressPrompt,
    required String voiceSamplesPrompt,
    required String summaryName,
    required String voicesName,
  }) => [
    CompactRule(id: 'rule_0', name: summaryName, prompt: compressPrompt),
    CompactRule(id: 'rule_1', name: voicesName, prompt: voiceSamplesPrompt),
  ];

  /// Matches the decorated heading the compact system writes on its blocks,
  /// e.g. `**[Summary]**`, `**[Voice Samples]**`, `**[Chronicle]**`.
  static final RegExp blockHeadingPattern = RegExp(r'^\*\*\[([^\]]+)\]\*\*');

  /// True when [text] opens with one of those decorated headings.
  ///
  /// This is how a pre-existing compact block is recognised in an old
  /// conversation that predates the `isChronicle` flag, so conversations
  /// summarised by any earlier version are still mergeable.
  static bool looksLikeCompactBlock(String text) =>
      blockHeadingPattern.hasMatch(text.trimLeft());

  /// Strips a decorated heading off a block body.
  static String stripBlockHeading(String text) {
    final trimmed = text.trim();
    final match = RegExp(r'^\*\*\[[^\]]+\]\*\*\s*').firstMatch(trimmed);
    return match == null ? trimmed : trimmed.substring(match.end).trim();
  }

  /// Builds the final merge prompt for a multi-conversation chronicle.
  static String buildMergePrompt({
    required String instruction,
    required List<({String title, String body})> extracts,
  }) {
    final buf = StringBuffer();
    buf.writeln(instruction.trim());
    buf.writeln();
    for (var i = 0; i < extracts.length; i++) {
      buf.writeln('--- SOURCE ${i + 1}: ${extracts[i].title} ---');
      buf.writeln(extracts[i].body.trim());
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  /// Encodes [rules] for SharedPreferences.
  static String encodeRules(List<CompactRule> rules) =>
      jsonEncode(rules.map((r) => r.toJson()).toList());

  /// Decodes rules, returning null when nothing usable is stored so the caller
  /// can fall back to migrating the legacy two-prompt setup.
  static List<CompactRule>? decodeRules(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final rules = <CompactRule>[];
      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        // The drawer keys a TextEditingController per rule id, so an id that
        // arrived empty or duplicated has to be replaced or two rules share
        // one controller and edits land in the wrong prompt.
        final existing = map['id'];
        final taken = rules.map((r) => r.id).toSet();
        if (existing is! String ||
            existing.isEmpty ||
            taken.contains(existing)) {
          map['id'] = 'rule_$i';
        }
        rules.add(CompactRule.fromJson(map));
      }
      return rules.isEmpty ? null : rules;
    } catch (_) {
      return null;
    }
  }
}
