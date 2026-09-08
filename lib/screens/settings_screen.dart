import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/forward_status.dart';
import '../services/app_lock_service.dart';
import '../services/battery_service.dart';
import '../services/export_service.dart';
import '../services/foreground_service.dart';
import '../services/forward_service.dart';
import '../services/payload_builder.dart';
import '../services/sender_presets.dart';
import '../services/settings_service.dart';
import '../services/sync_scheduler.dart';
import '../widgets/settings_section.dart';

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
  late final TextEditingController _telegramBotToken;
  late final TextEditingController _telegramChatId;
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
  late bool _realtimeKeepAlive;
  late int _syncIntervalMinutes;

  bool _testing = false;
  bool _obscureToken = true;
  bool _obscureTelegramToken = true;
  bool _obscurePin = true;
  bool _showAdvancedApi = false;

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
    _telegramBotToken =
        TextEditingController(text: SettingsService.telegramBotToken);
    _telegramChatId =
        TextEditingController(text: SettingsService.telegramChatId);
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
    _realtimeKeepAlive = SettingsService.realtimeKeepAliveEnabled;
    _syncIntervalMinutes = SettingsService.syncIntervalMinutes;
    _showAdvancedApi = SettingsService.customHeaders.isNotEmpty ||
        SettingsService.payloadTemplate.trim() !=
            SettingsService.defaultPayloadTemplate.trim();
  }

  @override
  void dispose() {
    _apiUrl.dispose();
    _apiToken.dispose();
    _apiKeyHeader.dispose();
    _payloadTemplate.dispose();
    _fixedHeaders.dispose();
    _telegramBotToken.dispose();
    _telegramChatId.dispose();
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

  Future<void> _saveTelegram() async {
    await SettingsService.setTelegramBotToken(_telegramBotToken.text);
    await SettingsService.setTelegramChatId(_telegramChatId.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Telegram settings saved')),
    );
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
        return 'Example: sms:your-password';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SettingsSection(
            icon: Icons.sync_alt_rounded,
            title: 'Forwarding',
            subtitle: 'Queue locally even when paused',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable forwarding'),
                subtitle: const Text('When off, SMS still queues on device'),
                value: _forwardingEnabled,
                onChanged: (v) async {
                  setState(() => _forwardingEnabled = v);
                  await SettingsService.setForwardingEnabled(v);
                  if (v) ForwardService().flushPending();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsSection(
            icon: Icons.cloud_outlined,
            title: 'API',
            subtitle: 'Where matching SMS are posted',
            children: [
              TextField(
                controller: _apiUrl,
                decoration: const InputDecoration(
                  labelText: 'API URL',
                  hintText: 'https://your-api.example.com/sms',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
              ),
              if (_apiUrl.text.trim().startsWith('http://'))
                Text(
                  'Prefer HTTPS for production traffic.',
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              DropdownButtonFormField<AuthType>(
                key: ValueKey(_authType),
                initialValue: _authType,
                decoration: const InputDecoration(
                  labelText: 'Auth type',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
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
              TextField(
                controller: _apiToken,
                obscureText: _obscureToken,
                enabled: _authType != AuthType.none,
                decoration: InputDecoration(
                  labelText: _tokenLabel,
                  hintText: _tokenHint,
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureToken ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                  ),
                ),
              ),
              if (_authType == AuthType.apiKey)
                TextField(
                  controller: _apiKeyHeader,
                  decoration: const InputDecoration(
                    labelText: 'API key header name',
                    hintText: 'X-API-Key',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded: _showAdvancedApi,
                  onExpansionChanged: (v) =>
                      setState(() => _showAdvancedApi = v),
                  title: Text(
                    'Advanced payload & headers',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  subtitle: const Text('Optional JSON template and fixed headers'),
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'One header per line as Name: Value. Built-in: Content-Type, Accept, X-Device-Id, X-Client. Placeholder: {{device_id}}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _fixedHeaders,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        labelText: 'Fixed headers',
                        hintText:
                            'X-Api-Key: your-secret\nX-Shop-Id: 42\nX-Source: {{device_id}}',
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Placeholders: {{device_id}} {{sender}} {{body}} {{received_at}} {{amount}} {{txn_id}} {{type}} {{counterparty}} {{currency}} {{telegram_bot_token}} {{telegram_chat_id}}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _payloadTemplate,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        labelText: 'JSON body template',
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _payloadTemplate.text =
                                SettingsService.defaultPayloadTemplate;
                          });
                        },
                        child: const Text('Reset template'),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saveApi,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save API'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt_outlined),
                    label: const Text('Test'),
                  ),
                ],
              ),
              SelectableText(
                'Device ID: ${SettingsService.deviceId}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsSection(
            icon: Icons.telegram,
            title: 'Telegram',
            subtitle: 'Included in every API payload for your backend',
            iconColor: const Color(0xFF229ED9),
            children: [
              TextField(
                controller: _telegramBotToken,
                obscureText: _obscureTelegramToken,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Bot token',
                  hintText: '123456:ABC-DEF...',
                  prefixIcon: const Icon(Icons.smart_toy_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureTelegramToken
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => setState(
                      () => _obscureTelegramToken = !_obscureTelegramToken,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: _telegramChatId,
                keyboardType: TextInputType.text,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Chat ID',
                  hintText: '123456789 or -1001234567890',
                  prefixIcon: Icon(Icons.chat_bubble_outline),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _saveTelegram,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Telegram'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsSection(
            icon: Icons.filter_alt_outlined,
            title: 'Filters',
            subtitle:
                'Exact sender match (case-insensitive). Optional body rules.',
            children: [
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
                  'Extract amount, TxnID, type, counterparty',
                ),
                value: _structuredParse,
                onChanged: (v) async {
                  setState(() => _structuredParse = v);
                  await SettingsService.setStructuredParseEnabled(v);
                },
              ),
              Text(
                'Quick presets',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SenderPresets.items.map((preset) {
                  final already = preset.senders.every(
                    (s) =>
                        _senders.any((e) => e.toLowerCase() == s.toLowerCase()),
                  );
                  return FilterChip(
                    label: Text(preset.label),
                    selected: already,
                    onSelected: (_) async {
                      final next = List<String>.from(_senders);
                      for (final s in preset.senders) {
                        if (!next
                            .any((e) => e.toLowerCase() == s.toLowerCase())) {
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
                title: 'Include keywords',
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
                title: 'Exclude keywords',
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
            ],
          ),
          const SizedBox(height: 12),
          SettingsSection(
            icon: Icons.folder_outlined,
            title: 'Data',
            subtitle: 'Export or clear the local queue',
            children: [
              _ActionTile(
                icon: Icons.ios_share_outlined,
                title: 'Export all messages',
                onTap: () => ExportService.shareLog(),
              ),
              _ActionTile(
                icon: Icons.report_gmailerrorred_outlined,
                title: 'Export failed only',
                onTap: () =>
                    ExportService.shareLog(onlyStatus: ForwardStatus.failed),
              ),
              _ActionTile(
                icon: Icons.delete_sweep_outlined,
                title: 'Clear sent messages',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final n = await ForwardService().clearSent();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Cleared $n sent messages')),
                  );
                },
              ),
              _ActionTile(
                icon: Icons.delete_forever_outlined,
                title: 'Clear all messages',
                destructive: true,
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
            ],
          ),
          const SizedBox(height: 12),
          SettingsSection(
            icon: Icons.lock_outline,
            title: 'App lock',
            subtitle: 'Optional PIN when opening the app',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require PIN'),
                subtitle: Text(
                  SettingsService.hasPin
                      ? 'Lock on launch and when returning'
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
              TextField(
                controller: _pinInput,
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: SettingsService.hasPin ? 'New PIN' : 'Set PIN',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePin = !_obscurePin),
                  ),
                ),
              ),
              TextField(
                controller: _pinConfirm,
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
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
            ],
          ),
          const SizedBox(height: 12),
          SettingsSection(
            icon: Icons.phonelink_setup_outlined,
            title: 'Reliability',
            subtitle: 'Background sync + OEM survival',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Realtime keepalive'),
                subtitle: Text(
                  _realtimeKeepAlive
                      ? 'Foreground service — sticky notification, ~15s retries'
                      : 'Off — AlarmManager sync, no sticky notification',
                ),
                value: _realtimeKeepAlive,
                onChanged: (v) async {
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _realtimeKeepAlive = v);
                  await SettingsService.setRealtimeKeepAliveEnabled(v);
                  await SyncScheduler.applyFromSettings();
                  await ForegroundService().refreshRunningState();
                  if (!mounted) return;
                  final running = ForegroundService().isRunning.value;
                  final message = !v
                      ? 'Realtime off — syncing every $_syncIntervalMinutes min'
                      : running
                          ? 'Realtime keepalive on — notification may appear'
                          : 'Could not start keepalive — using AlarmManager sync';
                  messenger.showSnackBar(SnackBar(content: Text(message)));
                },
              ),
              if (!_realtimeKeepAlive) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  key: ValueKey(_syncIntervalMinutes),
                  initialValue: _syncIntervalMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Background sync interval',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  items: SyncScheduler.allowedIntervals
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text('Every $m minutes'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _syncIntervalMinutes = v);
                    await SettingsService.setSyncIntervalMinutes(v);
                    await SyncScheduler.scheduleAlarm();
                  },
                ),
              ],
              _ActionTile(
                icon: Icons.battery_charging_full,
                title: 'Disable battery optimization',
                subtitle: 'Required for 24/7 SMS capture',
                onTap: () => BatteryService().requestIgnoreOptimization(),
              ),
              _ActionTile(
                icon: Icons.phonelink_setup,
                title: 'Device-specific guide',
                subtitle: 'Xiaomi, Oppo, Vivo, Samsung, Huawei…',
                onTap: () => BatteryService().showAllGuides(),
              ),
              if (_realtimeKeepAlive)
                _ActionTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Restart keepalive service',
                  subtitle: 'Shows the persistent notification',
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await SyncScheduler.cancelAlarm();
                    final ok = await ForegroundService().start(
                      restartIfRunning: true,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Keepalive service running'
                              : 'Could not start keepalive service',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsSection(
            icon: Icons.palette_outlined,
            title: 'Theme',
            children: [
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
            ],
          ),
        ],
      ),
    );
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (help != null) ...[
          const SizedBox(height: 2),
          Text(
            help,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: hint, labelText: title),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onAdd,
              child: const Text('Add'),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (s) => InputChip(
                    label: Text(s),
                    onDeleted: () => onRemove(s),
                    deleteIconColor: scheme.onSurfaceVariant,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Icon(Icons.chevron_right, color: scheme.outline),
        onTap: onTap,
      ),
    );
  }
}
