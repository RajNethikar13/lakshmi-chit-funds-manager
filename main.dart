import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'db.dart';

String money(num n) => '₹${NumberFormat('#,##,##0').format(n)}';

String fmtDate(String s) =>
    DateFormat('dd MMM yyyy').format(DateTime.parse(s));


CellValue excelValue(Object? value) {
  if (value == null) return TextCellValue('');
  if (value is int) return IntCellValue(value);
  if (value is double) return DoubleCellValue(value);
  if (value is num) return DoubleCellValue(value.toDouble());
  if (value is bool) return BoolCellValue(value);
  return TextCellValue(value.toString());
}

String excelText(Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  if (value is TextCellValue) return value.value.text ?? '';
  if (value is IntCellValue) return '${value.value}';
  if (value is DoubleCellValue) return '${value.value}';
  if (value is BoolCellValue) return '${value.value}';
  if (value is DateCellValue) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
  if (value is DateTimeCellValue) return value.asDateTimeLocal().toIso8601String();
  if (value is TimeCellValue) return value.toString();
  if (value is FormulaCellValue) return value.formula;
  return value.toString();
}

int excelInt(Data? cell, [int fallback = 0]) {
  final text = excelText(cell).trim();
  return int.tryParse(text) ?? double.tryParse(text)?.round() ?? fallback;
}

void addExcelSheet(Excel excel, String name, List<String> headers, List<Map<String, Object?>> rows) {
  final sheet = excel[name];
  sheet.appendRow(headers.map(excelValue).toList());
  for (final row in rows) {
    sheet.appendRow(headers.map((h) => excelValue(row[h])).toList());
  }
  for (var i = 0; i < headers.length; i++) {
    sheet.setColumnWidth(i, 18);
  }
}

Future<void> exportExcel(BuildContext context, String scope) async {
  try {
    final data = await AppDb.instance.backupData();
    final excel = Excel.createExcel();

    final info = excel['Sheet1'];
    info.appendRow([TextCellValue('Lakshmi Chit Manager')]);
    info.appendRow([TextCellValue('Export type'), TextCellValue(scope)]);
    info.appendRow([TextCellValue('Exported at'), TextCellValue(DateTime.now().toIso8601String())]);

    if (scope == 'Full Backup' || scope == 'Groups' || scope == 'Members') {
      addExcelSheet(excel, 'Templates', ['id','name','months','members','installment','due_day','max_payout'], data['templates'] ?? []);
      addExcelSheet(excel, 'Groups', ['id','name','template_id','start_date'], data['groups_tbl'] ?? []);
    }
    if (scope == 'Full Backup' || scope == 'Groups' || scope == 'Members') {
      addExcelSheet(excel, 'Members', ['id','name','mobile','address','group_id','member_no','lift_month','lift_amount','lift_date'], data['members'] ?? []);
      addExcelSheet(excel, 'Payments', ['id','member_id','month_no','due_amount','paid_amount','paid_date','status','mode','notes'], data['payments'] ?? []);
      addExcelSheet(excel, 'Ledger', ['id','type','amount','date','member_id','group_id','category','notes'], data['ledger'] ?? []);
    }
    if (scope == 'Full Backup' || scope == 'Schemes') {
      addExcelSheet(excel, 'Templates', ['id','name','months','members','installment','due_day','max_payout'], data['templates'] ?? []);
      if (scope == 'Schemes') {
        addExcelSheet(excel, 'Groups', ['id','name','template_id','start_date'], data['groups_tbl'] ?? []);
      }
    }

    if (scope == 'Analysis') {
      final a = await AppDb.instance.analysis(period: 'Yearly', year: DateTime.now().year);
      addExcelSheet(excel, 'Analysis', ['metric','amount'], [
        {'metric':'Total received','amount':a['received'] ?? 0},
        {'metric':'Total given out','amount':a['given'] ?? 0},
        {'metric':'Cash movement','amount':a['net'] ?? 0},
        {'metric':'Outstanding installments','amount':a['outstanding'] ?? 0},
      ]);
      final profits = await AppDb.instance.completedGroupProfits();
      addExcelSheet(excel, 'Group Profit', ['group','scheme','start_date','end_date','received','given_out','profit','completed'], profits);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Could not create Excel file.');

    final safe = scope.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final name = 'lakshmi_chit_${safe}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      text: 'Lakshmi Chit Manager - $scope',
      fileNameOverrides: [name],
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel export failed: $e')));
    }
  }
}

Future<void> importExcel(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) throw Exception('The selected file could not be read.');

    final excel = Excel.decodeBytes(bytes);
    final requiredSheets = ['Templates', 'Groups', 'Members', 'Payments', 'Ledger'];
    for (final name in requiredSheets) {
      if (!excel.tables.containsKey(name)) {
        throw Exception('This is not a Lakshmi Chit full backup. Missing sheet: $name');
      }
    }

    List<Map<String, Object?>> readSheet(String name) {
      final sheet = excel.tables[name]!;
      if (sheet.rows.isEmpty) return [];
      final headers = sheet.rows.first.map(excelText).toList();
      return sheet.rows.skip(1).where((r) => r.any((c) => excelText(c).trim().isNotEmpty)).map((r) {
        final out = <String, Object?>{};
        for (var i = 0; i < headers.length; i++) {
          final h = headers[i];
          if (h.isEmpty) continue;
          final value = excelText(i < r.length ? r[i] : null);
          out[h] = value.isEmpty ? null : value;
        }
        return out;
      }).toList();
    }

    final templates = readSheet('Templates');
    final groups = readSheet('Groups');
    final members = readSheet('Members');
    final payments = readSheet('Payments');
    final ledger = readSheet('Ledger');

    await AppDb.instance.restoreData({
      'templates': templates,
      'groups_tbl': groups,
      'members': members,
      'payments': payments,
      'ledger': ledger,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored successfully.')),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext c) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lakshmi Chit Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff244b82),
        ),
        useMaterial3: true,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _Home();
}

class _Home extends State<Home> {
  int tab = 0;

  final pages = const [
    Dashboard(),
    GroupsPage(),
    MembersPage(),
    TemplatesPage(),
    AnalysisPage(),
  ];

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lakshmi Chit Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (x) {
          setState(() => tab = x);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Members',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Schemes',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analysis',
          ),
        ],
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _Dashboard();
}

class _Dashboard extends State<Dashboard> {
  Map<String, int> d = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    d = await AppDb.instance.dashboard();

    if (mounted) {
      setState(() {});
    }
  }

  Widget stat(String a, String b, IconData i) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(i),
        ),
        title: Text(a),
        subtitle: Text(
          b,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            'Business Overview',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          stat(
            'Active groups',
            '${d['groups'] ?? 0}',
            Icons.groups,
          ),
          stat(
            'Members',
            '${d['members'] ?? 0}',
            Icons.people,
          ),
          stat(
            'Amount received',
            money(d['received'] ?? 0),
            Icons.south_west,
          ),
          stat(
            'Amount given out',
            money(d['given'] ?? 0),
            Icons.north_east,
          ),
          stat(
            'Outstanding',
            money(d['outstanding'] ?? 0),
            Icons.warning_amber,
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.touch_app),
              title: Text('Tap groups or members'),
              subtitle: Text(
                'Open details, edit or delete records, and mark monthly payments.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => exportExcel(c, 'Full Backup'),
                  icon: const Icon(Icons.download),
                  label: const Text('Full Excel Backup'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => importExcel(c),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Restore'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _Groups();
}

class _Groups extends State<GroupsPage> {
  List<Map<String, Object?>> xs = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    xs = await AppDb.instance.groups();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> form([Map<String, Object?>? old]) async {
    final ts = await AppDb.instance.templates();

    if (ts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Create a scheme first.'),
          ),
        );
      }
      return;
    }

    final n = TextEditingController(
      text: old == null ? '' : old['name'] as String,
    );

    int tid = old == null
        ? ts.first['id'] as int
        : old['template_id'] as int;

    DateTime start = old == null
        ? DateTime.now()
        : DateTime.parse(old['start_date'] as String);

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, s) => AlertDialog(
          title: Text(
            old == null ? 'New Group' : 'Edit Group',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: n,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                ),
              ),
              DropdownButton<int>(
                isExpanded: true,
                value: tid,
                items: ts
                    .map(
                      (t) => DropdownMenuItem(
                        value: t['id'] as int,
                        child: Text(t['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    s(() => tid = v);
                  }
                },
              ),
              ListTile(
                title: Text(
                  'Start: ${DateFormat('dd MMM yyyy').format(start)}',
                ),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final z = await showDatePicker(
                    context: c,
                    initialDate: start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );

                  if (z != null) {
                    s(() => start = z);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && n.text.trim().isNotEmpty) {
      if (old == null) {
        await AppDb.instance.addGroup(
          n.text.trim(),
          tid,
          start,
        );
      } else {
        await AppDb.instance.updateGroup(
          old['id'] as int,
          n.text.trim(),
          tid,
          start,
        );
      }

      load();
    }
  }

  Future<void> del(Map<String, Object?> g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          'Delete ${g['name']} and its members/payment records?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AppDb.instance.deleteGroup(g['id'] as int);
      load();
    }
  }

  @override
  Widget build(BuildContext c) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Chit Groups',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Export Excel',
                  onPressed: () => exportExcel(c, 'Groups'),
                  icon: const Icon(Icons.download),
                ),
                FilledButton.icon(
                  onPressed: () => form(),
                  icon: const Icon(Icons.add),
                  label: const Text('New Group'),
                ),
              ],
            ),
          ],
        ),
        ...xs.map(
          (g) => Card(
            child: ListTile(
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(
                  builder: (_) => GroupDetail(g),
                ),
              ).then((_) => load()),
              leading: const CircleAvatar(
                child: Icon(Icons.groups),
              ),
              title: Text(g['name'] as String),
              subtitle: Text(
                '${g['template_name']}\n'
                'Start: ${fmtDate(g['start_date'] as String)}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'e') {
                    form(g);
                  }

                  if (v == 'd') {
                    del(g);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'e',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'd',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GroupDetail extends StatefulWidget {
  final Map<String, Object?> g;

  const GroupDetail(
    this.g, {
    super.key,
  });

  @override
  State<GroupDetail> createState() => _GroupDetail();
}

class _GroupDetail extends State<GroupDetail> {
  List<Map<String, Object?>> ms = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    ms = (await AppDb.instance.members())
        .where(
          (m) => m['group_id'] == widget.g['id'],
        )
        .toList();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.g['name'] as String),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              title: Text(widget.g['template_name'] as String),
              subtitle: Text(
                '${widget.g['months']} months • '
                '${money(widget.g['installment'] as int)}/month • '
                '${widget.g['members']} members',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Members (${ms.length})',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...ms.map(
            (m) => Card(
              child: ListTile(
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) => MemberDetail(
                      m['id'] as int,
                    ),
                  ),
                ).then((_) => load()),
                title: Text(m['name'] as String),
                subtitle: Text(
                  'Member #${m['member_no']} • ${m['mobile']}',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _Members();
}

class _Members extends State<MembersPage> {
  List<Map<String, Object?>> xs = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    xs = await AppDb.instance.members();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> form([Map<String, Object?>? old]) async {
    final gs = await AppDb.instance.groups();

    if (gs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a group first.'),
        ),
      );
      return;
    }

    final n = TextEditingController(
      text: old == null ? '' : old['name'] as String,
    );

    final ph = TextEditingController(
      text: old == null ? '' : old['mobile'] as String,
    );

    final a = TextEditingController(
      text: old == null
          ? ''
          : (old['address'] as String? ?? ''),
    );

    final no = TextEditingController(
      text: old == null ? '' : '${old['member_no']}',
    );

    int gid = old == null
        ? gs.first['id'] as int
        : old['group_id'] as int;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, s) => AlertDialog(
          title: Text(
            old == null ? 'Add Member' : 'Edit Member',
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: n,
                  decoration: const InputDecoration(
                    labelText: 'Customer name',
                  ),
                ),
                TextField(
                  controller: ph,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                  ),
                ),
                TextField(
                  controller: a,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                  ),
                ),
                TextField(
                  controller: no,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Member number',
                  ),
                ),
                DropdownButton<int>(
                  isExpanded: true,
                  value: gid,
                  items: gs
                      .map(
                        (g) => DropdownMenuItem(
                          value: g['id'] as int,
                          child: Text(
                            '${g['name']} • ${g['template_name']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      s(() => gid = v);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && n.text.trim().isNotEmpty) {
      if (old == null) {
        await AppDb.instance.addMember(
          n.text.trim(),
          ph.text.trim(),
          a.text.trim(),
          gid,
          int.tryParse(no.text) ?? 0,
        );
      } else {
        await AppDb.instance.updateMember(
          old['id'] as int,
          n.text.trim(),
          ph.text.trim(),
          a.text.trim(),
          gid,
          int.tryParse(no.text) ?? 0,
        );
      }

      load();
    }
  }

  Future<void> del(Map<String, Object?> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete member?'),
        content: Text(
          'Delete ${m['name']} and all payment records?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AppDb.instance.deleteMember(
        m['id'] as int,
      );
      load();
    }
  }

  Future<void> wa(Map<String, Object?> m) async {
    final phone = (m['mobile'] as String)
        .replaceAll(RegExp(r'[^0-9+]'), '');

    final text = Uri.encodeComponent(
      'Dear ${m['name']}, your monthly chit installment is '
      '${money(m['installment'] as int)}. '
      'Please make the payment on time. Thank you.',
    );

    await launchUrl(
      Uri.parse(
        'https://wa.me/$phone?text=$text',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext c) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Members',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Export Excel',
                  onPressed: () => exportExcel(c, 'Members'),
                  icon: const Icon(Icons.download),
                ),
                FilledButton.icon(
                  onPressed: () => form(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
        ...xs.map(
          (m) => Card(
            child: ListTile(
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(
                  builder: (_) => MemberDetail(
                    m['id'] as int,
                  ),
                ),
              ).then((_) => load()),
              leading: CircleAvatar(
                child: Text('${m['member_no']}'),
              ),
              title: Text(m['name'] as String),
              subtitle: Text(
                '${m['group_name']} • '
                '${money(m['installment'] as int)}/month\n'
                '${m['mobile']}',
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => wa(m),
                    icon: const Icon(Icons.chat),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'e') {
                        form(m);
                      }

                      if (v == 'd') {
                        del(m);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'e',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'd',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MemberDetail extends StatefulWidget {
  final int id;

  const MemberDetail(
    this.id, {
    super.key,
  });

  @override
  State<MemberDetail> createState() => _MemberDetail();
}

class _MemberDetail extends State<MemberDetail> {
  Map<String, Object?>? m;
  List<Map<String, Object?>> ps = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    m = await AppDb.instance.member(widget.id);
    ps = await AppDb.instance.payments(widget.id);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> pay(int month) async {
    final old = ps
        .where(
          (x) => x['month_no'] == month,
        )
        .toList();

    final p = old.isEmpty ? null : old.first;

    final amount = TextEditingController(
      text: '${p == null ? 0 : p['paid_amount']}',
    );

    String mode = p == null ? 'Cash' : p['mode'] as String;
    DateTime paidDate = p != null && p['paid_date'] != null
        ? DateTime.tryParse(p['paid_date'] as String) ?? DateTime.now()
        : DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, s) => AlertDialog(
          title: Text(
            'Month $month payment',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Due: ${money(m!['installment'] as int)}',
              ),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount received',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Payment date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(paidDate)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final z = await showDatePicker(
                    context: c,
                    initialDate: paidDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (z != null) s(() => paidDate = z);
                },
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: mode,
                items: const [
                  'Cash',
                  'UPI',
                  'Bank',
                  'Other',
                ]
                    .map(
                      (x) => DropdownMenuItem(
                        value: x,
                        child: Text(x),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    s(() => mode = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final a = int.tryParse(amount.text) ?? 0;
      final due = m!['installment'] as int;

      final status = a <= 0
          ? 'Pending'
          : a < due
              ? 'Partial'
              : 'Paid';

      await AppDb.instance.savePayment(
        memberId: widget.id,
        month: month,
        due: due,
        paid: a,
        status: status,
        mode: mode,
        date: paidDate,
      );

      load();
    }
  }

  Future<void> lift() async {
    final mo = TextEditingController(
      text: '${m!['lift_month'] ?? ''}',
    );

    final am = TextEditingController(
      text: '${m!['lift_amount'] ?? ''}',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Record Chit Lift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mo,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lift month',
              ),
            ),
            TextField(
              controller: am,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount given (₹)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AppDb.instance.saveLift(
        widget.id,
        int.tryParse(mo.text) ?? 0,
        int.tryParse(am.text) ?? 0,
        DateTime.now(),
      );
    }

    load();
  }

  @override
  Widget build(BuildContext c) {
    if (m == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final months = m!['months'] as int;
    final install = m!['installment'] as int;
    final liftMonth = m!['lift_month'] as int?;

    final received = ps.fold<int>(
      0,
      (a, x) => a + (x['paid_amount'] as int),
    );

    final outstanding = ps.fold<int>(
      0,
      (a, x) {
        final z =
            (x['due_amount'] as int) -
            (x['paid_amount'] as int);

        return a + (z > 0 ? z : 0);
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(m!['name'] as String),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              title: Text(
                '${m!['group_name']} • '
                '${money(install)}/month',
              ),
              subtitle: Text(
                '${m!['mobile']}\n'
                '${liftMonth == null ? 'Chit not lifted' : 'Lifted in month $liftMonth • Given ${money(m!['lift_amount'] as int)}'}',
              ),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    title: const Text('Received'),
                    subtitle: Text(
                      money(received),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: ListTile(
                    title: const Text('Outstanding'),
                    subtitle: Text(
                      money(outstanding),
                    ),
                  ),
                ),
              ),
            ],
          ),

          FilledButton.icon(
            onPressed: lift,
            icon: const Icon(Icons.payments),
            label: Text(
              liftMonth == null
                  ? 'Record Chit Lift'
                  : 'Edit Chit Lift',
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Monthly Payments',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          ...List.generate(
            months,
            (i) {
              final no = i + 1;

              final xs = ps
                  .where(
                    (x) => x['month_no'] == no,
                  )
                  .toList();

              final p = xs.isEmpty
                  ? null
                  : xs.first;

              final a = p == null
                  ? 0
                  : p['paid_amount'] as int;

              final st = p == null
                  ? 'Pending'
                  : p['status'] as String;

              final bal = install - a;

              String statusText;
              IconData statusIcon;
              Color statusColor;

              if (st == 'Paid') {
                statusText = 'Paid ${money(a)}';
                statusIcon = Icons.check_circle;
                statusColor = Colors.green;
              } else if (st == 'Partial') {
                statusText =
                    'Partial ${money(a)} • Balance ${money(bal)}';
                statusIcon = Icons.timelapse;
                statusColor = Colors.orange;
              } else {
                statusText = 'Pending';
                statusIcon =
                    Icons.radio_button_unchecked;
                statusColor = Colors.grey;
              }

              return Card(
                child: ListTile(
                  onTap: () => pay(no),
                  leading: CircleAvatar(
                    child: Text('$no'),
                  ),
                  title: Text(
                    'Month $no • Due ${money(install)}',
                  ),
                  subtitle: Text(statusText),
                  trailing: Icon(
                    statusIcon,
                    color: statusColor,
                  ),
                ),
              );
            },
          ),

          Text(
            'Remaining scheduled months after lift: '
            '${months - (liftMonth ?? 0)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _Templates();
}

class _Templates extends State<TemplatesPage> {
  List<Map<String, Object?>> xs = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    xs = await AppDb.instance.templates();
    if (mounted) setState(() {});
  }

  Future<void> form([Map<String, Object?>? o]) async {
    final n = TextEditingController(text: o == null ? '' : o['name'] as String);
    final m = TextEditingController(text: '${o == null ? 25 : o['months']}');
    final mem = TextEditingController(text: '${o == null ? 25 : o['members']}');
    final i = TextEditingController(text: '${o == null ? 16000 : o['installment']}');
    final d = TextEditingController(text: '${o == null ? 5 : o['due_day']}');
    final max = TextEditingController(text: '${o == null ? 500000 : o['max_payout']}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(o == null ? 'New Scheme' : 'Edit Scheme'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: n, decoration: const InputDecoration(labelText: 'Scheme name')),
              TextField(controller: m, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Months')),
              TextField(controller: mem, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Members')),
              TextField(controller: i, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly installment')),
              TextField(controller: d, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Due day')),
              TextField(controller: max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maximum amount a person receives')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok == true && n.text.trim().isNotEmpty) {
      final months = int.tryParse(m.text) ?? 25;
      final members = int.tryParse(mem.text) ?? 25;
      final installment = int.tryParse(i.text) ?? 16000;
      final due = int.tryParse(d.text) ?? 5;
      final maxPayout = int.tryParse(max.text) ?? 0;
      if (o == null) {
        await AppDb.instance.addTemplate(n.text.trim(), months, members, installment, due, maxPayout);
      } else {
        await AppDb.instance.updateTemplate(o['id'] as int, n.text.trim(), months, members, installment, due, maxPayout);
      }
      load();
    }
  }

  Future<void> del(Map<String, Object?> o) async {
    try {
      await AppDb.instance.deleteTemplate(o['id'] as int);
      load();
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Cannot delete'),
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Saved Schemes', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(tooltip: 'Export Excel', onPressed: () => exportExcel(c, 'Schemes'), icon: const Icon(Icons.download)),
                FilledButton.icon(onPressed: () => form(), icon: const Icon(Icons.add), label: const Text('New')),
              ],
            ),
          ],
        ),
        ...xs.map(
          (x) => Card(
            child: ListTile(
              title: Text(x['name'] as String),
              subtitle: Text(
                '${x['months']} months • ${x['members']} members • ${money(x['installment'] as int)}/month • Due ${x['due_day']}\n'
                'Maximum payout per person: ${money((x['max_payout'] as int?) ?? 0)}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'e') form(x);
                  if (v == 'd') del(x);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'e', child: Text('Edit')),
                  PopupMenuItem(value: 'd', child: Text('Delete')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _Analysis();
}

class _Analysis extends State<AnalysisPage> {
  String period = 'Yearly';
  int year = DateTime.now().year;
  int? month;
  int? quarter;
  int? groupId;
  int? templateId;
  List<Map<String, Object?>> groups = [];
  List<Map<String, Object?>> templates = [];
  Map<String, int> d = {};
  List<Map<String, Object?>> profits = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    groups = await AppDb.instance.groups();
    templates = await AppDb.instance.templates();
    d = await AppDb.instance.analysis(
      period: period,
      year: year,
      month: month,
      quarter: quarter,
      groupId: groupId,
      templateId: templateId,
    );
    profits = await AppDb.instance.completedGroupProfits(
      groupId: groupId,
      templateId: templateId,
    );
    if (mounted) setState(() {});
  }

  void refresh() => load();

  @override
  Widget build(BuildContext c) {
    final net = d['net'] ?? 0;
    final years = List<int>.generate(7, (i) => DateTime.now().year - 2 + i);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Business Analysis', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
            IconButton(tooltip: 'Export Excel', onPressed: () => exportExcel(c, 'Analysis'), icon: const Icon(Icons.download)),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: period,
                  decoration: const InputDecoration(labelText: 'Period'),
                  items: const ['Monthly', 'Quarterly', 'Yearly']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        period = v;
                        month = period == 'Monthly' ? (month ?? DateTime.now().month) : null;
                        quarter = period == 'Quarterly' ? (quarter ?? ((DateTime.now().month - 1) ~/ 3 + 1)) : null;
                      });
                      refresh();
                    }
                  },
                ),
                DropdownButtonFormField<int>(
                  value: year,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: years.map((x) => DropdownMenuItem(value: x, child: Text('$x'))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => year = v);
                      refresh();
                    }
                  },
                ),
                if (period == 'Monthly')
                  DropdownButtonFormField<int>(
                    value: month,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: List.generate(12, (i) => i + 1).map((x) => DropdownMenuItem(value: x, child: Text(DateFormat('MMMM').format(DateTime(2000, x, 1))))).toList(),
                    onChanged: (v) {
                      setState(() => month = v);
                      refresh();
                    },
                  ),
                if (period == 'Quarterly')
                  DropdownButtonFormField<int>(
                    value: quarter,
                    decoration: const InputDecoration(labelText: 'Quarter'),
                    items: const [1, 2, 3, 4].map((x) => DropdownMenuItem(value: x, child: Text('Q$x'))).toList(),
                    onChanged: (v) {
                      setState(() => quarter = v);
                      refresh();
                    },
                  ),
                DropdownButtonFormField<int?>(
                  value: groupId,
                  decoration: const InputDecoration(labelText: 'Group'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All groups')),
                    ...groups.map((g) => DropdownMenuItem<int?>(value: g['id'] as int, child: Text(g['name'] as String))),
                  ],
                  onChanged: (v) {
                    setState(() => groupId = v);
                    refresh();
                  },
                ),
                DropdownButtonFormField<int?>(
                  value: templateId,
                  decoration: const InputDecoration(labelText: 'Scheme'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All schemes')),
                    ...templates.map((t) => DropdownMenuItem<int?>(value: t['id'] as int, child: Text(t['name'] as String))),
                  ],
                  onChanged: (v) {
                    setState(() => templateId = v);
                    refresh();
                  },
                ),
              ],
            ),
          ),
        ),
        Card(child: ListTile(title: const Text('Total received'), trailing: Text(money(d['received'] ?? 0)))),
        Card(child: ListTile(title: const Text('Total given out'), trailing: Text(money(d['given'] ?? 0)))),
        Card(child: ListTile(title: const Text('Cash movement'), subtitle: const Text('Received minus payouts for the selected period.'), trailing: Text(money(net)))),
        Card(child: ListTile(title: const Text('Outstanding installments'), trailing: Text(money(d['outstanding'] ?? 0)))),
        const SizedBox(height: 8),
        const Text('Completed Group Profit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (profits.isEmpty)
          const Card(child: ListTile(title: Text('No completed groups for the selected filters.'))),
        ...profits.map(
          (p) => Card(
            child: ListTile(
              title: Text('${p['group']} • ${p['scheme']}'),
              subtitle: Text('Completed: ${p['end_date']}\nReceived ${money(p['received'] as int)} • Given out ${money(p['given_out'] as int)}'),
              trailing: Text(money(p['profit'] as int), style: TextStyle(fontWeight: FontWeight.bold, color: (p['profit'] as int) >= 0 ? Colors.green : Colors.red)),
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Profit rule'),
            subtitle: Text('Final group profit is calculated only after the group reaches its scheduled end date: total member payments received minus chit payouts given to that group.'),
          ),
        ),
      ],
    );
  }
}
