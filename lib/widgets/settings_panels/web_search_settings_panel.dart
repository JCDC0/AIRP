import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/scale_provider.dart';
import '../../services/web_search_service.dart';
import '../../utils/constants.dart';

/// A settings panel for configuring the BYOK web search backend.
///
/// Positioned beneath the Generation Parameters panel in the Settings Drawer.
/// Users select a search provider from a dropdown, and provider-specific
/// credentials are revealed conditionally.
class WebSearchSettingsPanel extends StatefulWidget {
  const WebSearchSettingsPanel({super.key});

  @override
  State<WebSearchSettingsPanel> createState() => _WebSearchSettingsPanelState();
}

class _WebSearchSettingsPanelState extends State<WebSearchSettingsPanel> {
  final TextEditingController _braveKeyController = TextEditingController();
  final TextEditingController _tavilyKeyController = TextEditingController();
  final TextEditingController _serperKeyController = TextEditingController();
  final TextEditingController _searxngUrlController = TextEditingController();

  bool _searxngValidating = false;
  bool? _searxngValid; // null = untested, true = ok, false = failed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      _braveKeyController.text = chatProvider.braveApiKey;
      _tavilyKeyController.text = chatProvider.tavilyApiKey;
      _serperKeyController.text = chatProvider.serperApiKey;
      _searxngUrlController.text = chatProvider.searxngUrl;
    });
  }

  @override
  void dispose() {
    _braveKeyController.dispose();
    _tavilyKeyController.dispose();
    _serperKeyController.dispose();
    _searxngUrlController.dispose();
    super.dispose();
  }

  Future<void> _validateSearXNG(ChatProvider chatProvider) async {
    final url = _searxngUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _searxngValidating = true;
      _searxngValid = null;
    });

    final ok = await WebSearchService.validateSearXNGInstance(url);

    if (!mounted) return;
    setState(() {
      _searxngValidating = false;
      _searxngValid = ok;
    });

    if (ok) {
      chatProvider.setSearxngUrl(url);
      chatProvider.saveSettings(showConfirmation: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    final Color accent = themeProvider.appThemeColor;
    final double fs = scaleProvider.systemFontSize;
    final List<Shadow> bloomShadow = themeProvider.enableBloom
        ? [Shadow(color: accent.withOpacity(0.9), blurRadius: 20)]
        : [];

    InputDecoration buildFieldDecoration({
      required String hint,
      String? label,
      bool obscure = false,
    }) =>
        InputDecoration(
          hintText: hint,
          labelText: label,
          labelStyle: TextStyle(color: accent, fontSize: fs - 1),
          border: OutlineInputBorder(
            borderSide: themeProvider.enableBloom
                ? BorderSide(color: accent)
                : const BorderSide(),
          ),
          enabledBorder: themeProvider.enableBloom
              ? OutlineInputBorder(
                  borderSide: BorderSide(color: accent.withOpacity(0.5)),
                )
              : const OutlineInputBorder(),
          filled: true,
          isDense: true,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search Provider dropdown ─────────────────────────────────────
        Text(
          "Search Backend",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: accent,
            fontSize: fs,
            shadows: bloomShadow,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: themeProvider.enableBloom
                  ? accent.withOpacity(0.5)
                  : Colors.white12,
            ),
            boxShadow: themeProvider.enableBloom
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SearchProvider>(
              value: chatProvider.searchProvider,
              isExpanded: true,
              dropdownColor: const Color(0xFF2C2C2C),
              icon: Icon(Icons.travel_explore, color: accent),
              items: [
                DropdownMenuItem(
                  value: SearchProvider.provider,
                  child: Text(
                    'Provider  (native grounding)',
                    style: TextStyle(fontSize: fs),
                  ),
                ),
                DropdownMenuItem(
                  value: SearchProvider.brave,
                  child: Text(
                    'Brave Web Search  (BYOK)',
                    style: TextStyle(fontSize: fs),
                  ),
                ),
                DropdownMenuItem(
                  value: SearchProvider.tavily,
                  child: Text(
                    'Tavily  (AI-optimised, BYOK)',
                    style: TextStyle(fontSize: fs),
                  ),
                ),
                DropdownMenuItem(
                  value: SearchProvider.serper,
                  child: Text(
                    'Serper.dev  (Google results, BYOK)',
                    style: TextStyle(fontSize: fs),
                  ),
                ),
                DropdownMenuItem(
                  value: SearchProvider.searxng,
                  child: Text(
                    'SearXNG  (self-hosted)',
                    style: TextStyle(fontSize: fs),
                  ),
                ),
                DropdownMenuItem(
                  value: SearchProvider.duckduckgo,
                  child: Text(
                    'DuckDuckGo  (free, scraping)',
                    style: TextStyle(fontSize: fs),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val == null) return;
                chatProvider.setSearchProvider(val);
                chatProvider.saveSettings(showConfirmation: false);
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          chatProvider.searchProvider == SearchProvider.provider
              ? "Uses the AI provider's native search (e.g. Gemini Search, OpenRouter web plugin)."
              : chatProvider.searchProvider == SearchProvider.brave
                  ? "Results are fetched via the Brave Search API before each message."
                  : chatProvider.searchProvider == SearchProvider.tavily
                      ? "AI-optimised search with pre-summarised results. Fast and accurate."
                      : chatProvider.searchProvider == SearchProvider.serper
                          ? "Google Search results via Serper.dev — high-quality organic results."
                          : chatProvider.searchProvider == SearchProvider.searxng
                              ? "Results are fetched from your self-hosted SearXNG instance."
                              : "DuckDuckGo HTML scraping — no API key required.",
          style: TextStyle(
            fontSize: fs * 0.78,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
        const Divider(height: 24),

        // ── Provider-specific configuration ─────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildProviderConfig(
            chatProvider: chatProvider,
            themeProvider: themeProvider,
            accent: accent,
            fs: fs,
            bloomShadow: bloomShadow,
            fieldDecoration: buildFieldDecoration,
          ),
        ),

        // ── Result count slider ──────────────────────────────────────────
        if (chatProvider.searchProvider != SearchProvider.provider) ...[
          const Divider(height: 24),
          Text(
            "Max Results  —  ${chatProvider.searchResultCount}",
            style: TextStyle(fontSize: fs - 1, color: Colors.grey),
          ),
          Slider(
            value: chatProvider.searchResultCount.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: accent,
            label: chatProvider.searchResultCount.toString(),
            onChanged: (v) {
              chatProvider.setSearchResultCount(v.toInt());
              chatProvider.saveSettings(showConfirmation: false);
            },
          ),
          Text(
            "Number of search results injected into the AI context per message.",
            style: TextStyle(
              fontSize: fs * 0.78,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildProviderConfig({
    required ChatProvider chatProvider,
    required ThemeProvider themeProvider,
    required Color accent,
    required double fs,
    required List<Shadow> bloomShadow,
    required InputDecoration Function({
      required String hint,
      String? label,
      bool obscure,
    }) fieldDecoration,
  }) {
    switch (chatProvider.searchProvider) {
      case SearchProvider.brave:
        return _BraveConfig(
          key: const ValueKey('brave'),
          controller: _braveKeyController,
          accent: accent,
          fs: fs,
          bloomShadow: bloomShadow,
          fieldDecoration: fieldDecoration,
          onSave: (val) {
            chatProvider.setBraveApiKey(val);
            chatProvider.saveSettings(showConfirmation: false);
          },
        );

      case SearchProvider.tavily:
        return _ApiKeyConfig(
          key: const ValueKey('tavily'),
          controller: _tavilyKeyController,
          label: 'Tavily API Key',
          hint: 'Paste Tavily API key…',
          helpText: 'Get a key at app.tavily.com — 1 000 free searches/month.',
          helpUrl: 'https://app.tavily.com/home',
          accent: accent,
          fs: fs,
          bloomShadow: bloomShadow,
          fieldDecoration: fieldDecoration,
          onSave: (val) {
            chatProvider.setTavilyApiKey(val);
            chatProvider.saveSettings(showConfirmation: false);
          },
        );

      case SearchProvider.serper:
        return _ApiKeyConfig(
          key: const ValueKey('serper'),
          controller: _serperKeyController,
          label: 'Serper API Key',
          hint: 'Paste Serper.dev API key…',
          helpText: 'Get a key at serper.dev — 2 500 free searches included.',
          helpUrl: 'https://serper.dev/api-key',
          accent: accent,
          fs: fs,
          bloomShadow: bloomShadow,
          fieldDecoration: fieldDecoration,
          onSave: (val) {
            chatProvider.setSerperApiKey(val);
            chatProvider.saveSettings(showConfirmation: false);
          },
        );

      case SearchProvider.searxng:
        return _SearXNGConfig(
          key: const ValueKey('searxng'),
          controller: _searxngUrlController,
          validating: _searxngValidating,
          valid: _searxngValid,
          accent: accent,
          fs: fs,
          bloomShadow: bloomShadow,
          fieldDecoration: fieldDecoration,
          onValidate: () => _validateSearXNG(chatProvider),
          onSave: (val) {
            chatProvider.setSearxngUrl(val);
            chatProvider.saveSettings(showConfirmation: false);
          },
        );

      case SearchProvider.duckduckgo:
        return _DDGWarning(key: const ValueKey('ddg'), fs: fs);

      case SearchProvider.provider:
        return const SizedBox.shrink(key: ValueKey('provider'));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brave configuration sub-widget
// ─────────────────────────────────────────────────────────────────────────────

class _BraveConfig extends StatelessWidget {
  final TextEditingController controller;
  final Color accent;
  final double fs;
  final List<Shadow> bloomShadow;
  final InputDecoration Function({
    required String hint,
    String? label,
    bool obscure,
  }) fieldDecoration;
  final ValueChanged<String> onSave;

  const _BraveConfig({
    super.key,
    required this.controller,
    required this.accent,
    required this.fs,
    required this.bloomShadow,
    required this.fieldDecoration,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Brave API Key",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: accent,
            fontSize: fs,
            shadows: bloomShadow,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          style: TextStyle(fontSize: fs - 2),
          decoration: fieldDecoration(hint: "Paste Brave Search API key…"),
          onChanged: onSave,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse('https://api.search.brave.com/app/keys');
            // Open link if launcher is available
            debugPrint('[WebSearch] Brave key URL: $uri');
          },
          child: Text(
            "Get a free key at api.search.brave.com/app/keys",
            style: TextStyle(
              fontSize: fs * 0.78,
              color: accent.withOpacity(0.8),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic API key configuration sub-widget  (Tavily, Serper, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class _ApiKeyConfig extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String helpText;
  final String helpUrl;
  final Color accent;
  final double fs;
  final List<Shadow> bloomShadow;
  final InputDecoration Function({
    required String hint,
    String? label,
    bool obscure,
  }) fieldDecoration;
  final ValueChanged<String> onSave;

  const _ApiKeyConfig({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.helpText,
    required this.helpUrl,
    required this.accent,
    required this.fs,
    required this.bloomShadow,
    required this.fieldDecoration,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: accent,
            fontSize: fs,
            shadows: bloomShadow,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          style: TextStyle(fontSize: fs - 2),
          decoration: fieldDecoration(hint: hint),
          onChanged: onSave,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            debugPrint('[WebSearch] $label URL: $helpUrl');
          },
          child: Text(
            helpText,
            style: TextStyle(
              fontSize: fs * 0.78,
              color: accent.withOpacity(0.8),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SearXNG configuration sub-widget
// ─────────────────────────────────────────────────────────────────────────────

class _SearXNGConfig extends StatelessWidget {
  final TextEditingController controller;
  final bool validating;
  final bool? valid;
  final Color accent;
  final double fs;
  final List<Shadow> bloomShadow;
  final InputDecoration Function({
    required String hint,
    String? label,
    bool obscure,
  }) fieldDecoration;
  final VoidCallback onValidate;
  final ValueChanged<String> onSave;

  const _SearXNGConfig({
    super.key,
    required this.controller,
    required this.validating,
    required this.valid,
    required this.accent,
    required this.fs,
    required this.bloomShadow,
    required this.fieldDecoration,
    required this.onValidate,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    Widget statusIcon;
    if (validating) {
      statusIcon = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: accent,
        ),
      );
    } else if (valid == true) {
      statusIcon = const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20);
    } else if (valid == false) {
      statusIcon = const Icon(Icons.error, color: Colors.redAccent, size: 20);
    } else {
      statusIcon = Icon(Icons.help_outline, color: Colors.grey, size: 20);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SearXNG Instance URL",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: accent,
            fontSize: fs,
            shadows: bloomShadow,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: fs - 2),
          decoration: fieldDecoration(
            hint: "http://192.168.1.10:8080  or  IP:port",
            label: "Instance address",
          ),
          onChanged: onSave,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: validating ? null : onValidate,
              icon: statusIcon,
              label: Text(
                validating
                    ? "Validating…"
                    : valid == true
                        ? "Instance OK"
                        : valid == false
                            ? "Unreachable — retry"
                            : "Validate Instance",
                style: TextStyle(fontSize: fs - 2),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: valid == true
                    ? Colors.greenAccent
                    : valid == false
                        ? Colors.redAccent
                        : accent,
                side: BorderSide(
                  color: valid == true
                      ? Colors.greenAccent
                      : valid == false
                          ? Colors.redAccent
                          : accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "The instance must have JSON output enabled. "
          "Accepts both  IP:port  and  http://IP:port.",
          style: TextStyle(
            fontSize: fs * 0.78,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DDG warning sub-widget
// ─────────────────────────────────────────────────────────────────────────────

class _DDGWarning extends StatelessWidget {
  final double fs;

  const _DDGWarning({super.key, required this.fs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: fs * 0.85, color: Colors.white70),
                children: const [
                  TextSpan(
                    text: "DuckDuckGo scraping is unreliable. ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  TextSpan(
                    text:
                        "Results may be incomplete or unavailable if DDG blocks the request. "
                        "Consider asking the AI to verify or cross-check any fetched information.",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
