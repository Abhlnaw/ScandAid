import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'models/scan.dart';
import 'screens/scan_editor.dart';
import 'services/analysis_service.dart';
import 'services/photo_service.dart';
import 'services/scan_repository.dart';
import 'widgets/scan_photo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScandAidApp());
}

const ink = Color(0xFF183B38);
const accent = Color(0xFF137E70);

class ScandAidApp extends StatelessWidget {
  final ScanRepository? repository;
  const ScandAidApp({super.key, this.repository});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ScandAid',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        surface: const Color(0xFFFAFBF7),
      ),
      scaffoldBackgroundColor: const Color(0xFFFAFBF7),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAFBF7),
        foregroundColor: ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0E8E1)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    home: HomeScreen(repository: repository),
  );
}

void showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst(
            RegExp(r'^(Bad state: |FormatException: |Exception: )'),
            '',
          ),
        ),
      ),
    );
String dateLabel(DateTime time) {
  final t = time.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[t.month - 1]} ${t.day}, ${t.year} · ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

Future<void> shareExport(
  BuildContext context,
  String data,
  String filename,
) async {
  final saved = await FilePicker.saveFile(
    fileName: filename,
    bytes: Uint8List.fromList(utf8.encode(data)),
    mimeType: 'application/json',
    dialogTitle: 'Save private ScandAid backup',
  );
  if (saved != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup saved. Keep it somewhere private.')),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ScanRepository? repository;
  const HomeScreen({super.key, this.repository});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final repo = widget.repository ?? ScanRepository();
  final photos = PhotoService();
  int tab = 0;
  bool loading = true, picking = false;
  Object? loadError;
  String filter = '';
  @override
  void initState() {
    super.initState();
    repo.addListener(refresh);
    load();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      await repo.load();
      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loadError = e;
          loading = false;
        });
      }
      return;
    }
    try {
      final photo = await photos.recover();
      if (photo != null && mounted) {
        await openEditor(photo);
      }
    } catch (e) {
      if (mounted) {
        showError(
          context,
          'A pending camera photo could not be recovered. You can choose it again.',
        );
      }
    }
  }

  @override
  void dispose() {
    repo.removeListener(refresh);
    if (widget.repository == null) repo.dispose();
    super.dispose();
  }

  Future<void> openEditor(PreparedPhoto photo) async =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ScanEditor(photo: photo, repository: repo),
        ),
      );
  Future<void> pick(ImageSource source) async {
    setState(() => picking = true);
    try {
      final photo = await photos.pick(source);
      if (photo != null && mounted) await openEditor(photo);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  bool get cameraAvailable =>
      kIsWeb ||
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.blur_on_rounded, color: accent),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'ScandAid',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5),
            ),
          ),
        ],
      ),
      actions: [
        if (MediaQuery.sizeOf(context).width > 520)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Chip(
              avatar: Icon(
                repo.serverEnabled ? Icons.hub_outlined : Icons.lock_outline,
                size: 16,
              ),
              label: Text(
                repo.serverEnabled ? 'Your server' : 'On this device',
              ),
            ),
          ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : loadError != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text('Your saved records could not be opened.'),
                  SelectableText('$loadError'),
                  TextButton(onPressed: load, child: const Text('Retry')),
                ],
              ),
            ),
          )
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: switch (tab) {
                0 => dashboard(),
                1 => history(),
                _ => SettingsPanel(repository: repo),
              },
            ),
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Overview',
        ),
        NavigationDestination(
          icon: Icon(Icons.photo_library_outlined),
          selectedIcon: Icon(Icons.photo_library),
          label: 'History',
        ),
        NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
      ],
    ),
  );
  Widget dashboard() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    children: [
      const Text(
        'A clearer picture\nof your progress.',
        style: TextStyle(
          fontSize: 38,
          height: 1.12,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -1.3,
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Keep a private photo journal. Trace a wound, measure it,\nand compare the changes over time.',
        style: TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF566C65)),
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.add_a_photo_outlined,
              size: 34,
              color: Color(0xFFB8EDCD),
            ),
            const SizedBox(height: 18),
            const Text(
              'Start with a photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use even lighting and place a ruler beside the wound.\nKeep the camera directly above the skin.',
              style: TextStyle(color: Color(0xFFD0E1D9), height: 1.6),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (cameraAvailable)
                  FilledButton.icon(
                    onPressed: picking ? null : () => pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take photo'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: picking ? null : () => pick(ImageSource.gallery),
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(picking ? 'Opening…' : 'Choose photo'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          stat('${repo.scans.length}', 'saved photos', Icons.photo_outlined),
          stat(
            '${repo.scans.map((s) => s.woundName.toLowerCase()).toSet().length}',
            'tracked wounds',
            Icons.timeline,
          ),
          stat(
            '${repo.scans.where((s) => s.calibration != null).length}',
            'calibrated scans',
            Icons.straighten,
          ),
        ],
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Latest entries',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => tab = 1),
            child: const Text('View history'),
          ),
        ],
      ),
      if (repo.scans.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Your first photo will appear here.'),
          ),
        )
      else
        ...repo.scans.take(3).map(entry),
      const SizedBox(height: 22),
      const Text(
        'A tracking tool, not a diagnosis. Image analysis cannot determine infection, depth, or how urgently a wound needs care. Seek professional care if you are concerned.',
        style: TextStyle(color: Color(0xFF60746B), fontSize: 12, height: 1.5),
      ),
    ],
  );
  Widget stat(String value, String label, IconData icon) => SizedBox(
    width: 200,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  Text(label),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget entry(Scan s) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          base64Decode(s.imageBase64),
          width: 58,
          height: 64,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(
        s.woundName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${dateLabel(s.createdAt)}\n${s.areaCm2 == null ? '${s.areaPixels} px² · no scale reference' : '${s.areaCm2!.toStringAsFixed(2)} cm² · calibrated'}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ScanDetail(scan: s, repository: repo),
        ),
      ),
    ),
  );
  Widget history() {
    final list = repo.scans.where(
      (s) => s.woundName.toLowerCase().contains(filter.toLowerCase()),
    );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Your photo journal',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Use the same wound name to group follow-up photos.'),
        const SizedBox(height: 20),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search wounds',
          ),
          onChanged: (v) => setState(() => filter = v),
        ),
        const SizedBox(height: 18),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No matching entries. Add a photo from Overview.'),
          ),
        ...list.map(entry),
      ],
    );
  }
}

class SettingsPanel extends StatefulWidget {
  final ScanRepository repository;
  const SettingsPanel({super.key, required this.repository});
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final url = TextEditingController(text: widget.repository.server);
  late bool enabled = widget.repository.serverEnabled;
  bool busy = false;
  String? health;
  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  Future<void> check() async {
    setState(() {
      busy = true;
      health = null;
    });
    final api = AnalysisService();
    try {
      final data = await api.health(url.text);
      if (mounted) {
        setState(
          () => health =
              'Segmentation: ${data['segmentation']}\nClassification: ${data['classification']}',
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      api.close();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    try {
      if (enabled) AnalysisService.endpoint(url.text, '/health');
      await widget.repository.settings(url.text.trim(), enabled);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settings saved.')));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> importBackup() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null) return;
      final size = await picked.length();
      if (size != null && size > 160 * 1024 * 1024) {
        throw const FormatException('Backup exceeds the 160 MB limit.');
      }
      final bytes = await picked.readAsBytes();
      final count = await widget.repository.importExport(utf8.decode(bytes));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported $count new entries. Existing entries were kept.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Made to stay private',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: ink),
      ),
      const SizedBox(height: 12),
      const Text(
        'Photos and notes stay on this device. Location metadata is removed from imported photos. App storage is not encrypted; use your device lock and disk encryption. No analytics or automatic uploads.',
        style: TextStyle(height: 1.6),
      ),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assisted analysis',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Run the included inference server to enable MedSAM / GrabCut segmentation and an experimental wound classifier. Manual outlines work offline.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: url,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Inference server',
                  hintText: 'http://127.0.0.1:8000',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: enabled,
                onChanged: (v) => setState(() => enabled = v),
                title: const Text('Send photos to this server for analysis'),
                subtitle: const Text(
                  'Each Analyze action sends the prepared photo and region to this address. Use only a server you trust.',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : check,
                    icon: const Icon(Icons.network_check),
                    label: Text(busy ? 'Checking…' : 'Test connection'),
                  ),
                  FilledButton(
                    onPressed: widget.repository.writing ? null : save,
                    child: const Text('Save settings'),
                  ),
                ],
              ),
              if (health != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SelectableText(health!),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Your records',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      const Text(
        'Exports contain your photos and notes. Choose carefully where you save or share them. Browser storage can be cleared; keep exports if you need a durable backup.',
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: Builder(
          builder: (shareContext) => OutlinedButton.icon(
            onPressed: widget.repository.scans.isEmpty
                ? null
                : () async {
                    try {
                      await shareExport(
                        shareContext,
                        widget.repository.export(),
                        'scandaid-records.json',
                      );
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
            icon: const Icon(Icons.ios_share),
            label: const Text('Export all records'),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: widget.repository.writing ? null : importBackup,
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Restore from export'),
        ),
      ),
      const SizedBox(height: 28),
      const Text(
        'About measurements',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      const Text(
        'Area counts pixels inside the reviewed outline or mask. Centimeters require a known-length reference beside the wound in the same plane. Perspective, curved skin, lighting and different outlines affect comparisons. A photo cannot measure depth or volume.',
        style: TextStyle(height: 1.6),
      ),
    ],
  );
}

class ScanDetail extends StatelessWidget {
  final Scan scan;
  final ScanRepository repository;
  const ScanDetail({super.key, required this.scan, required this.repository});
  @override
  Widget build(BuildContext context) {
    final previous = repository
        .forWound(scan.woundName)
        .where((s) => s.createdAt.isBefore(scan.createdAt));
    final baseline = previous.isEmpty ? null : previous.first;
    return Scaffold(
      appBar: AppBar(
        title: Text(scan.woundName),
        actions: [
          Builder(
            builder: (shareContext) => IconButton(
              tooltip: 'Export entry',
              icon: const Icon(Icons.ios_share),
              onPressed: () async {
                try {
                  await shareExport(
                    shareContext,
                    jsonEncode({
                      'format': 'scandaid-export',
                      'version': 1,
                      'scans': [scan.toJson()],
                    }),
                    'scandaid-${scan.id}.json',
                  );
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
            ),
          ),
          IconButton(
            tooltip: 'Delete entry',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete this entry?'),
                  content: const Text(
                    'This removes the photo, analysis and notes from this device. Export first if you need a copy.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Keep entry'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                try {
                  await repository.delete(scan.id);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(dateLabel(scan.createdAt)),
              const SizedBox(height: 16),
              ScanPhoto(
                bytes: base64Decode(scan.imageBase64),
                width: scan.width,
                height: scan.height,
                points: scan.outline,
                mask: scan.maskBase64,
                calibration: scan.calibration,
              ),
              const SizedBox(height: 16),
              ResultsCard(scan: scan),
              if (baseline != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Compared with the previous entry',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
                const SizedBox(height: 10),
                if (baseline.areaCm2 != null &&
                    scan.areaCm2 != null &&
                    baseline.areaCm2! > 0)
                  Text(
                    'Area change: ${((scan.areaCm2! / baseline.areaCm2! - 1) * 100).toStringAsFixed(1)}% since ${dateLabel(baseline.createdAt)}.\nPhoto measurements alone do not establish healing.',
                    style: const TextStyle(height: 1.5),
                  )
                else
                  const Text(
                    'Calibrate both photos to compare physical area. Pixel areas across photos are not comparable.',
                  ),
                const SizedBox(height: 16),
                ScanPhoto(
                  bytes: base64Decode(baseline.imageBase64),
                  width: baseline.width,
                  height: baseline.height,
                  points: baseline.outline,
                  mask: baseline.maskBase64,
                  calibration: baseline.calibration,
                ),
              ],
              if (scan.notes.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Your notes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SelectableText(scan.notes),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ResultsCard extends StatelessWidget {
  final Scan scan;
  const ResultsCard({super.key, required this.scan});
  @override
  Widget build(BuildContext context) {
    final c = scan.classification;
    final ranked = c.scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scan.areaCm2 == null
                  ? '${scan.areaPixels} px²'
                  : '${scan.areaCm2!.toStringAsFixed(2)} cm²',
              style: const TextStyle(
                fontSize: 36,
                color: ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              scan.areaCm2 == null
                  ? 'Outlined area · no scale reference'
                  : 'Estimated area · calibrated reference',
            ),
            if (scan.lengthCm != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Extent: ${scan.lengthCm!.toStringAsFixed(2)} × ${scan.widthCm!.toStringAsFixed(2)} cm (image axes)',
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Region: ${scan.segmentationSource}',
              style: const TextStyle(color: Color(0xFF566C65)),
            ),
            const Divider(height: 32),
            const Text(
              'Experimental classification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              c.label,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            if (c.reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(c.reason!, style: const TextStyle(height: 1.5)),
              ),
            if (ranked.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...ranked
                  .take(3)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.key)),
                          Text('${(e.value * 100).toStringAsFixed(1)}%'),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              const Text(
                'Model scores are not clinical confidence or probabilities of a diagnosis.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              c.source,
              style: const TextStyle(fontSize: 12, color: Color(0xFF566C65)),
            ),
            if (scan.redPixelFraction != null) ...[
              const Divider(height: 32),
              Text(
                'Red-dominant pixels: ${(scan.redPixelFraction! * 100).toStringAsFixed(1)}% of the selected region.',
              ),
              const SizedBox(height: 6),
              const Text(
                'A color descriptor affected by lighting and skin tone. It does not indicate inflammation or infection.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
