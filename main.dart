import 'dart:async';
import 'dart:io' show Platform;

import 'package:android_remote_pro/android_remote_pro.dart';
import 'package:android_remote_pro/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FFalconRemoteApp());
}

/// Standard Android TV key codes.
/// These are intentionally defined locally so the UI is not tied to
/// a specific helper class from the remote-control plugin.
class TvKey {
  static const home = 3;
  static const back = 4;

  static const dpadUp = 19;
  static const dpadDown = 20;
  static const dpadLeft = 21;
  static const dpadRight = 22;
  static const dpadCenter = 23;

  static const volumeUp = 24;
  static const volumeDown = 25;
  static const power = 26;

  static const menu = 82;
  static const playPause = 85;
  static const stop = 86;
  static const next = 87;
  static const previous = 88;
  static const rewind = 89;
  static const fastForward = 90;

  static const volumeMute = 164;
  static const info = 165;
  static const channelUp = 166;
  static const channelDown = 167;
  static const guide = 172;
  static const settings = 176;
  static const tvInput = 178;
}

class FFalconRemoteApp extends StatelessWidget {
  const FFalconRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FFALCON Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF43A5FF),
        scaffoldBackgroundColor: const Color(0xFF090C10),
        cardTheme: const CardThemeData(
          color: Color(0xFF11161D),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const RemoteHome(),
    );
  }
}

class RemoteHome extends StatefulWidget {
  const RemoteHome({super.key});

  @override
  State<RemoteHome> createState() => _RemoteHomeState();
}

class _RemoteHomeState extends State<RemoteHome> {
  AndroidRemotePro? _remote;
  StreamSubscription? _scanSub;

  final Map<String, Device> _devices = {};
  Device? _connected;
  bool _scanning = false;
  bool _connecting = false;
  String _status = 'TV를 검색해 주세요';

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _remote = AndroidRemotePro();
      _scanSub = _remote!.scanStream().listen(
        _onScanEvent,
        onError: (Object e) {
          if (!mounted) return;
          setState(() => _status = '검색 오류: $e');
        },
      );

      // Start automatically after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
    } else {
      _status = '현재 버전은 Android 휴대폰용입니다';
    }
  }

  void _onScanEvent(dynamic raw) {
    if (!mounted || raw == null) return;
    try {
      final obj = raw as Map;
      final event = obj['event'];

      if (event == 'found') {
        final device = Device.fromJsonString(obj['device'] as String);
        setState(() {
          _devices[device.name] = device;
          _status = '${_devices.length}개의 TV를 찾았습니다';
        });
      } else if (event == 'removed') {
        final name = obj['name'] as String;
        setState(() => _devices.remove(name));
      }
    } catch (e) {
      setState(() => _status = '검색 결과 처리 오류: $e');
    }
  }

  Future<void> _startScan() async {
    if (_remote == null || _scanning) return;
    setState(() {
      _devices.clear();
      _scanning = true;
      _status = 'FFALCON / Android TV 검색 중…';
    });
    try {
      await _remote!.startScan();
      // Leave scan running briefly so mDNS has time to discover the TV.
      await Future<void>.delayed(const Duration(seconds: 8));
    } catch (e) {
      if (mounted) setState(() => _status = '검색 실패: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(Device d) async {
    if (_remote == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _connecting = true;
      _status = '${d.name} 연결 중…';
    });

    try {
      await _remote!.connect(d.host, port: d.port);
      if (!mounted) return;
      setState(() {
        _connected = d;
        _status = '${d.name} 연결됨';
      });

      // Some Android TV Remote v2 implementations display a pairing code
      // on the first connection. If that happens, the user can open the
      // optional PIN helper from the top-right menu.
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '연결 실패: $e');
      _showError(
        'TV와 휴대폰이 같은 Wi-Fi인지 확인해 주세요.\n\n'
        '처음 연결이면 TV 화면에 페어링 코드가 표시될 수 있습니다.',
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _sendKey(int keyCode) async {
    if (_connected == null || _remote == null) {
      _showError('먼저 TV를 연결해 주세요.');
      return;
    }
    HapticFeedback.selectionClick();
    try {
      await _remote!.sendKey(keyCode);
    } catch (e) {
      if (mounted) {
        setState(() => _status = '명령 전송 실패: $e');
      }
    }
  }

  Future<void> _showPairingHelper() async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TV 페어링 코드'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          decoration: const InputDecoration(
            labelText: 'TV 화면에 표시된 코드',
            hintText: '예: A1B2C3',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('전송'),
          ),
        ],
      ),
    );

    if (pin == null || pin.isEmpty || _remote == null) return;

    // android_remote_pro's public example focuses on automatic pairing.
    // Different native versions may expose the pairing-code method with
    // different names. Dynamic dispatch lets this helper support those
    // variants without breaking compilation.
    dynamic plugin = _remote;
    Object? lastError;

    for (final methodName in const [
      'sendPin',
      'sendPairingCode',
      'pair',
    ]) {
      try {
        switch (methodName) {
          case 'sendPin':
            await plugin.sendPin(pin);
            break;
          case 'sendPairingCode':
            await plugin.sendPairingCode(pin);
            break;
          case 'pair':
            await plugin.pair(pin);
            break;
        }
        if (mounted) setState(() => _status = '페어링 코드 전송 완료');
        return;
      } catch (e) {
        lastError = e;
      }
    }

    _showError(
      '현재 플러그인 버전은 별도 PIN 전송 메서드를 노출하지 않는 것 같습니다.\n\n'
      '대부분의 경우 연결 버튼을 누르면 페어링이 자동으로 진행됩니다.\n'
      '오류: $lastError',
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FFALCON Remote'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _remote?.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceList = _devices.values.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FFALCON',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.3),
            ),
            Text(
              'FF32S55 Remote',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '페어링 코드',
            onPressed: _showPairingHelper,
            icon: const Icon(Icons.pin_outlined),
          ),
          IconButton(
            tooltip: 'TV 다시 검색',
            onPressed: _scanning ? null : _startScan,
            icon: _scanning
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: _connected == null
            ? _buildDiscovery(deviceList)
            : _buildRemote(),
      ),
    );
  }

  Widget _buildDiscovery(List<Device> devices) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Column(
        children: [
          _StatusCard(status: _status, connected: false),
          const SizedBox(height: 16),
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tv_outlined,
                          size: 62,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _scanning ? 'TV를 찾고 있습니다…' : '검색된 TV가 없습니다',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '휴대폰과 FF32S55를 같은 Wi-Fi에 연결한 뒤\n다시 검색해 주세요.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _scanning ? null : _startScan,
                          icon: const Icon(Icons.wifi_find),
                          label: const Text('TV 검색'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final d = devices[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: const CircleAvatar(
                            child: Icon(Icons.tv),
                          ),
                          title: Text(
                            d.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('${d.host}:${d.port}'),
                          trailing: _connecting
                              ? const CircularProgressIndicator()
                              : FilledButton(
                                  onPressed: () => _connect(d),
                                  child: const Text('연결'),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemote() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        _StatusCard(status: _status, connected: true),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _RemoteButton(
                icon: Icons.power_settings_new,
                label: 'POWER',
                onTap: () => _sendKey(TvKey.power),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RemoteButton(
                icon: Icons.input,
                label: 'INPUT',
                onTap: () => _sendKey(TvKey.tvInput),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RemoteButton(
                icon: Icons.settings,
                label: 'SETTINGS',
                onTap: () => _sendKey(TvKey.settings),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        _Dpad(onKey: _sendKey),
        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: _RemoteButton(
                icon: Icons.arrow_back,
                label: 'BACK',
                onTap: () => _sendKey(TvKey.back),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RemoteButton(
                icon: Icons.home_filled,
                label: 'HOME',
                onTap: () => _sendKey(TvKey.home),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RemoteButton(
                icon: Icons.menu,
                label: 'MENU',
                onTap: () => _sendKey(TvKey.menu),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _Rocker(
                title: 'VOLUME',
                topIcon: Icons.add,
                bottomIcon: Icons.remove,
                onTop: () => _sendKey(TvKey.volumeUp),
                onBottom: () => _sendKey(TvKey.volumeDown),
              ),
            ),
            const SizedBox(width: 14),
            _RoundAction(
              icon: Icons.volume_off,
              label: 'MUTE',
              onTap: () => _sendKey(TvKey.volumeMute),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Rocker(
                title: 'CHANNEL',
                topIcon: Icons.keyboard_arrow_up,
                bottomIcon: Icons.keyboard_arrow_down,
                onTop: () => _sendKey(TvKey.channelUp),
                onBottom: () => _sendKey(TvKey.channelDown),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  tooltip: 'Previous',
                  onPressed: () => _sendKey(TvKey.previous),
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton(
                  tooltip: 'Rewind',
                  onPressed: () => _sendKey(TvKey.rewind),
                  icon: const Icon(Icons.fast_rewind_rounded),
                ),
                FilledButton.tonal(
                  onPressed: () => _sendKey(TvKey.playPause),
                  child: const Icon(Icons.play_arrow_rounded),
                ),
                IconButton(
                  tooltip: 'Fast forward',
                  onPressed: () => _sendKey(TvKey.fastForward),
                  icon: const Icon(Icons.fast_forward_rounded),
                ),
                IconButton(
                  tooltip: 'Next',
                  onPressed: () => _sendKey(TvKey.next),
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _sendKey(TvKey.info),
                icon: const Icon(Icons.info_outline),
                label: const Text('INFO'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _sendKey(TvKey.guide),
                icon: const Icon(Icons.view_list_outlined),
                label: const Text('GUIDE'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _connected = null;
              _status = 'TV를 검색해 주세요';
            });
            _startScan();
          },
          child: const Text('다른 TV 연결'),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.connected});

  final String status;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(
              connected ? Icons.wifi : Icons.wifi_find,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(status)),
            if (connected)
              const Icon(Icons.check_circle, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RemoteButton extends StatelessWidget {
  const _RemoteButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF151B23),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 7),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dpad extends StatelessWidget {
  const _Dpad({required this.onKey});

  final Future<void> Function(int key) onKey;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, int key, {String? text}) {
      return SizedBox.square(
        dimension: 78,
        child: Material(
          color: const Color(0xFF171E27),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onKey(key),
            child: Center(
              child: text != null
                  ? Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    )
                  : Icon(icon, size: 34),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            button(Icons.keyboard_arrow_up, TvKey.dpadUp),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                button(Icons.keyboard_arrow_left, TvKey.dpadLeft),
                button(Icons.circle, TvKey.dpadCenter, text: 'OK'),
                button(Icons.keyboard_arrow_right, TvKey.dpadRight),
              ],
            ),
            button(Icons.keyboard_arrow_down, TvKey.dpadDown),
          ],
        ),
      ),
    );
  }
}

class _Rocker extends StatelessWidget {
  const _Rocker({
    required this.title,
    required this.topIcon,
    required this.bottomIcon,
    required this.onTop,
    required this.onBottom,
  });

  final String title;
  final IconData topIcon;
  final IconData bottomIcon;
  final VoidCallback onTop;
  final VoidCallback onBottom;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          IconButton(onPressed: onTop, icon: Icon(topIcon, size: 30)),
          Text(title, style: const TextStyle(fontSize: 10)),
          IconButton(onPressed: onBottom, icon: Icon(bottomIcon, size: 30)),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox.square(
          dimension: 64,
          child: FilledButton.tonal(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Icon(icon),
          ),
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
