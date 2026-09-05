import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_lock_service.dart';
import '../services/battery_service.dart';
import '../services/export_service.dart';
import '../services/foreground_service.dart';
import '../services/forward_service.dart';
import '../services/payload_builder.dart';
import '../services/sender_presets.dart';
import '../services/settings_service.dart';
import '../models/forward_status.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiUrl;
  late final TextEditingController _apiToken;
  late final TextEditingController _apiKeyHeader;
  late final TextEditingController _payloadTemplate;
  late final TextEditingController _fixedHeaders;
  late final TextEditingController _senderInput;
  late final TextEditingController _includeInput;
  late final TextEditingController _excludeInput;
  late final TextEditingController _pinInput;
  late final TextEditingController _pinConfirm;

  late List<String> _senders;
  late List<String> _include;
  late List<String> _exclude;
  late AuthType _authType;
  late ThemeMode _themeMode;
  late bool _forwardingEnabled;
  late bool _filtersUseRegex;
  late bool _appLockEnabled;
  late bool _structuredParse;

  bool _testing = false;
  bool _obscureToken = true;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _apiUrl = TextEditingController(text: SettingsService.apiUrl);
    _apiToken = TextEditingController(text: SettingsService.apiToken);
    _apiKeyHeader = TextEditingController(text: SettingsService.apiKeyHeader);
    _payloadTemplate =
        TextEditingController(text: SettingsService.payloadTemplate);
    _fixedHeaders = TextEditingController(
      text: SettingsService.customHeaders.join('\n'),
    );
    _senderInput = TextEditingController();
    _includeInput = TextEditingController();
    _excludeInput = TextEditingController();
    _pinInput = TextEditingController();
    _pinConfirm = TextEditingController();
    _senders = List.of(SettingsService.allowedSenders);
    _include = List.of(SettingsService.includeKeywords);
    _exclude = List.of(SettingsService.excludeKeywords);
    _authType = SettingsService.authType;
    _themeMode = SettingsService.themeMode;
    _forwardingEnabled = SettingsService.forwardingEnabled;
    _filtersUseRegex = SettingsService.filtersUseRegex;
    _appLockEnabled = SettingsService.appLockEnabled;
    _structuredParse = SettingsService.structuredParseEnabled;
  }

  @override
  void dispose() {
    _apiUrl.dispose();
    _apiToken.dispose();
    _apiKeyHeader.dispose();
    _payloadTemplate.dispose();
    _fixedHeaders.dispose();
    _senderInput.dispose();
    _includeInput.dispose();
    _excludeInput.dispose();
    _pinInput.dispose();
    _pinConfirm.dispose();
    super.dispose();
  }

  Future<void> _saveApi() async {
    final headers = PayloadBuilder.normalizeHeaderLines(_fixedHeaders.text);
    await SettingsService.setApiUrl(_apiUrl.text);
    await SettingsService.setApiToken(_apiToken.text);
    await SettingsService.setAuthType(_authType);
    await SettingsService.setApiKeyHeader(_apiKeyHeader.text);
    await SettingsService.setCustomHeaders(headers);
    await SettingsService.setPayloadTemplate(_payloadTemplate.text);
    setState(() => _fixedHeaders.text = headers.join('\n'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API settings saved')),
    );
    ForwardService().flushPending();
  }

  Future<void> _testConnection() async {
    await _saveApi();
    setState(() => _testing = true);
    final result = await ForwardService().testConnection();
    if (!mounted) return;
    setState(() => _testing = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Connection test'),
        content: SingleChildScrollView(child: Text(result)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addToList({
    required TextEditingController controller,
    required List<String> list,
    required Future<void> Function(List<String>) save,
  }) async {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    if (list.any((s) => s.toLowerCase() == value.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already added')),
      );
      return;
    }
    setState(() => list.add(value));
    await save(list);
    controller.clear();
  }

  Future<void> _setPin() async {
    final pin = _pinInput.text.trim();
    final confirm = _pinConfirm.text.trim();
    if (pin.length < 4 || pin.length > 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 4–8 digits')),
      );
      return;
    }
    if (pin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match')),
      );
      return;
    }
    await SettingsService.setPin(pin);
    setState(() => _appLockEnabled = true);
    _pinInput.clear();
    _pinConfirm.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App lock PIN saved')),
    );
  }

  String get _tokenLabel {
    switch (_authType) {
      case AuthType.none:
        return 'Token (unused)';
      case AuthType.bearer:
        return 'Bearer token';
      case AuthType.apiKey:
        return 'API key';
      case AuthType.basic:
        return 'Basic auth (user:password)';
    }
  }

  String? get _tokenHint {
    switch (_authType) {
      case AuthType.none:
        return null;
      case AuthType.bearer:
        return 'Paste the bearer token only';
      case AuthType.apiKey:
        return 'Value for the API key header';
      case AuthType.basic:
        return 'Example: sms:your-password  (must match API secrets)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Forwarding'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable forwarding'),
            subtitle: const Text('When off, SMS still queues locally'),
            value: _forwardingEnabled,
            onChanged: (v) async {
              setState(() => _forwardingEnabled = v);
              await SettingsService.setForwardingEnabled(v);
              if (v) ForwardService().flushPending();
            },
          ),
          const Divider(height: 32),
          _sectionTitle('API'),
          const SizedBox(height: 8),
          TextField(
            controller: _apiUrl,
            decoration: const InputDecoration(
              labelText: 'API URL',
              hintText: 'https://sms-forwarder-api.<subdomain>.workers.dev',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
          ),
          if (_apiUrl.text.trim().startsWith('http://'))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Warning: prefer HTTPS for production',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AuthType>(
            key: ValueKey(_authType),
            initialValue: _authType,
            decoration: const InputDecoration(labelText: 'Auth type'),
            items: AuthType.values
                .map(
                  (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _authType = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiToken,
            obscureText: _obscureToken,
            enabled: _authType != AuthType.none,
            decoration: InputDecoration(
              labelText: _tokenLabel,
              hintText: _tokenHint,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureToken ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _obscureToken = !_obscureToken),
              ),
            ),
          ),
          if (_authType == AuthType.apiKey) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyHeader,
              decoration: const InputDecoration(
                labelText: 'API key header name',
                hintText: 'X-API-Key',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Fixed headers (every request)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'One header per line as Name: Value. Always sent on forward + Test.\n'
            'Built-in: Content-Type, Accept, X-Device-Id, X-Client.\n'
            'Placeholder: {{device_id}}  ·  Lines starting with # are ignored.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _fixedHeaders,
            maxLines: 6,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'Fixed headers',
              hintText: 'X-Api-Key: your-secret\nX-Shop-Id: 42\nX-Source: {{device_id}}',
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            'Payload template',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Placeholders: {{device_id}} {{sender}} {{body}} {{received_at}} {{amount}} {{txn_id}} {{type}} {{counterparty}} {{currency}}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _payloadTemplate,
            maxLines: 8,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'JSON body template',
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _payloadTemplate.text = SettingsService.defaultPayloadTemplate;
              });
            },
            child: const Text('Reset template'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(onPressed: _saveApi, child: const Text('Save API')),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _testing ? null : _testConnection,
                child: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Test'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            'Device ID: ${SettingsService.deviceId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 32),
          _sectionTitle('Filters'),
          const SizedBox(height: 4),
          Text(
            'Sender allow-list, plus optional include/exclude body rules.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Treat keywords as regex'),
            subtitle: const Text('Off = plain case-insensitive contains'),
            value: _filtersUseRegex,
            onChanged: (v) async {
              setState(() => _filtersUseRegex = v);
              await SettingsService.setFiltersUseRegex(v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Structured parse'),
            subtitle: const Text(
              'Extract amount, TxnID, type, counterparty into API payload',
            ),
            value: _structuredParse,
            onChanged: (v) async {
              setState(() => _structuredParse = v);
              await SettingsService.setStructuredParseEnabled(v);
            },
          ),
          const SizedBox(height: 8),
          Text('Quick presets', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SenderPresets.items.map((preset) {
              final already = preset.senders.every(
                (s) => _senders.any((e) => e.toLowerCase() == s.toLowerCase()),
              );
              return FilterChip(
                label: Text(preset.label),
                selected: already,
                onSelected: (_) async {
                  final next = List<String>.from(_senders);
                  for (final s in preset.senders) {
                    if (!next.any((e) => e.toLowerCase() == s.toLowerCase())) {
                      next.add(s);
                    }
                  }
                  setState(() {
                    _senders
                      ..clear()
                      ..addAll(next);
                  });
                  await SettingsService.setAllowedSenders(_senders);
                },
              );
            }).toList(),
          ),
          _listEditor(
            title: 'Allowed senders',
            hint: 'e.g. bKash or 16216',
            controller: _senderInput,
            items: _senders,
            onAdd: () => _addToList(
              controller: _senderInput,
              list: _senders,
              save: SettingsService.setAllowedSenders,
            ),
            onRemove: (s) async {
              setState(() => _senders.remove(s));
              await SettingsService.setAllowedSenders(_senders);
            },
          ),
          _listEditor(
            title: 'Include keywords (optional)',
            hint: _filtersUseRegex ? r'e.g. TxnID|received' : 'e.g. TxnID',
            controller: _includeInput,
            items: _include,
            help: 'If set, body must match at least one',
            onAdd: () => _addToList(
              controller: _includeInput,
              list: _include,
              save: SettingsService.setIncludeKeywords,
            ),
            onRemove: (s) async {
              setState(() => _include.remove(s));
              await SettingsService.setIncludeKeywords(_include);
            },
          ),
          _listEditor(
            title: 'Exclude keywords (optional)',
            hint: 'e.g. promotional',
            controller: _excludeInput,
            items: _exclude,
            help: 'Drop message if any rule matches',
            onAdd: () => _addToList(
              controller: _excludeInput,
              list: _exclude,
              save: SettingsService.setExcludeKeywords,
            ),
            onRemove: (s) async {
              setState(() => _exclude.remove(s));
              await SettingsService.setExcludeKeywords(_exclude);
            },
          ),
          const Divider(height: 32),
          _sectionTitle('Data'),
          const SizedBox(height: 4),
          Text(
            'Export the local queue or clear history to free space.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.ios_share),
            title: const Text('Export all messages'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ExportService.shareLog(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.report_gmailerrorred_outlined),
            title: const Text('Export failed only'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                ExportService.shareLog(onlyStatus: ForwardStatus.failed),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Clear sent messages'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final n = await ForwardService().clearSent();
              messenger.showSnackBar(
                SnackBar(content: Text('Cleared $n sent messages')),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Clear all messages'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Clear all messages?'),
                  content: const Text(
                    'This deletes the entire local queue and cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                final n = await ForwardService().clearAll();
                messenger.showSnackBar(
                  SnackBar(content: Text('Cleared $n messages')),
                );
              }
            },
          ),
          const Divider(height: 32),
          _sectionTitle('App lock'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Require PIN'),
            subtitle: Text(
              SettingsService.hasPin
                  ? 'Lock on launch and when returning to the app'
                  : 'Set a PIN below to enable',
            ),
            value: _appLockEnabled && SettingsService.hasPin,
            onChanged: SettingsService.hasPin
                ? (v) async {
                    setState(() => _appLockEnabled = v);
                    await SettingsService.setAppLockEnabled(v);
                    if (!v) AppLockService().unlockWithoutPin();
                  }
                : null,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pinInput,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 8,
            decoration: InputDecoration(
              labelText: SettingsService.hasPin ? 'New PIN' : 'Set PIN',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
            ),
          ),
          TextField(
            controller: _pinConfirm,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 8,
            decoration: const InputDecoration(labelText: 'Confirm PIN'),
          ),
          Row(
            children: [
              FilledButton(onPressed: _setPin, child: const Text('Save PIN')),
              const SizedBox(width: 8),
              if (SettingsService.hasPin)
                OutlinedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await SettingsService.clearPin();
                    setState(() => _appLockEnabled = false);
                    AppLockService().unlockWithoutPin();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('App lock removed')),
                    );
                  },
                  child: const Text('Remove lock'),
                ),
            ],
          ),
          const Divider(height: 32),
          _sectionTitle('Reliability'),
          const SizedBox(height: 4),
          Text(
            'Keep the listener alive on OEM phones that kill background apps.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.battery_charging_full),
            title: const Text('Disable battery optimization'),
            subtitle: const Text('Required for 24/7 SMS capture'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => BatteryService().requestIgnoreOptimization(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phonelink_setup),
            title: const Text('Device-specific guide'),
            subtitle: const Text('Xiaomi, Oppo, Vivo, Samsung, Huawei…'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => BatteryService().showAllGuides(),
          ),
              ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Restart listening service'),
            subtitle: const Text('Shows the persistent notification'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await ForegroundService().start();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Listening service running'
                        : 'Could not start listening service',
                  ),
                ),
              );
            },
          ),
          const Divider(height: 32),
          _sectionTitle('Theme'),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {_themeMode},
            onSelectionChanged: (set) async {
              final mode = set.first;
              setState(() => _themeMode = mode);
              await SettingsService.setThemeMode(mode);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _listEditor({
    required String title,
    required String hint,
    required TextEditingController controller,
    required List<String> items,
    required VoidCallback onAdd,
    required void Function(String) onRemove,
    String? help,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (help != null)
          Text(help, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(labelText: title, hintText: hint),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: onAdd, child: const Text('Add')),
          ],
        ),
        ...items.map(
          (s) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(s),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onRemove(s),
            ),
          ),
        ),
      ],
    );
  }
}
