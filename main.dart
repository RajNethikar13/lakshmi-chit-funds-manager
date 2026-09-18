import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.init();
  runApp(const ChitApp());
}

class ChitApp extends StatelessWidget {
  const ChitApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lakshmi Chit Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff173d73)),
        useMaterial3: true,
      ),
      home: const Home(),
    );
  }
}

String money(num n) => '₹${NumberFormat('#,##,##0').format(n)}';

class Home extends StatefulWidget {
  const Home({super.key});
  @override State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int index = 0;
  final pages = const [
    Dashboard(),
    GroupsPage(),
    MembersPage(),
    TemplatesPage(),
    AnalysisPage(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lakshmi Chit Manager',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Schemes'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analysis'),
        ],
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override State<Dashboard> createState() => _DashboardState();
}
class _DashboardState extends State<Dashboard> {
  Map<String,int> d = {};
  @override void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    d = await AppDb.instance.dashboard();
    if (mounted) setState(() {});
  }
  Widget stat(String title, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(child: Icon(icon)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        )),
      ]),
    ),
  );
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: refresh,
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Business Overview', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        stat('Active groups', '${d['groups'] ?? 0}', Icons.groups),
        stat('Members', '${d['members'] ?? 0}', Icons.people),
        stat('Amount received', money(d['received'] ?? 0), Icons.south_west),
        stat('Amount given out', money(d['given'] ?? 0), Icons.north_east),
        stat('Outstanding', money(d['outstanding'] ?? 0), Icons.warning_amber),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Prototype'),
            subtitle: const Text('Next build adds the full 25-month payment matrix, chit-lift workflow, overdue automation and detailed profit analysis.'),
          ),
        ),
      ],
    ),
  );
}

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});
  @override State<TemplatesPage> createState() => _TemplatesPageState();
}
class _TemplatesPageState extends State<TemplatesPage> {
  List<Map<String,Object?>> items = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { items = await AppDb.instance.templates(); if(mounted)setState((){}); }

  Future<void> create() async {
    final name = TextEditingController(text: 'New Chit Scheme');
    final months = TextEditingController(text: '25');
    final members = TextEditingController(text: '25');
    final installment = TextEditingController(text: '16000');
    final due = TextEditingController(text: '5');
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Create Scheme Template'),
        content: SingleChildScrollView(child: Column(children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Scheme name')),
          TextField(controller: months, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of months')),
          TextField(controller: members, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of members')),
          TextField(controller: installment, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly installment (₹)')),
          TextField(controller: due, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Due day')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    if (result == true && name.text.trim().isNotEmpty) {
      final m = int.tryParse(months.text) ?? 25;
      await AppDb.instance.addTemplate(
        name.text.trim(), m, int.tryParse(members.text) ?? 25,
        int.tryParse(installment.text) ?? 0, int.tryParse(due.text) ?? 5,
      );
      load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(padding: const EdgeInsets.all(12), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Saved Schemes', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        FilledButton.icon(onPressed: create, icon: const Icon(Icons.add), label: const Text('New')),
      ]),
      const SizedBox(height: 8),
      ...items.map((x) => Card(child: ListTile(
        leading: const Icon(Icons.description),
        title: Text(x['name'] as String),
        subtitle: Text('${x['months']} months • ${x['members']} members • ${money(x['installment'] as int)}/month • Due ${x['due_day']}'),
      ))),
    ]),
  );
}

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});
  @override State<GroupsPage> createState() => _GroupsPageState();
}
class _GroupsPageState extends State<GroupsPage> {
  List<Map<String,Object?>> groups = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { groups = await AppDb.instance.groups(); if(mounted)setState((){}); }

  Future<void> create() async {
    final templates = await AppDb.instance.templates();
    if (templates.isEmpty) return;
    final name = TextEditingController();
    int templateId = templates.first['id'] as int;
    DateTime start = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Create Chit Group'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Group name')),
          DropdownButton<int>(
            isExpanded: true, value: templateId,
            items: templates.map((t) => DropdownMenuItem<int>(
              value: t['id'] as int,
              child: Text(t['name'] as String),
            )).toList(),
            onChanged: (v) { if(v != null)setD(()=>templateId=v); },
          ),
          ListTile(
            title: Text('Start: ${DateFormat('dd MMM yyyy').format(start)}'),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final picked = await showDatePicker(context: c, initialDate: start, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) setD(() => start = picked);
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create')),
        ],
      )),
    );
    if(ok == true && name.text.trim().isNotEmpty) {
      await AppDb.instance.addGroup(name.text.trim(), templateId, start);
      load();
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    body: ListView(padding: const EdgeInsets.all(12), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Chit Groups', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        FilledButton.icon(onPressed: create, icon: const Icon(Icons.add), label: const Text('New Group')),
      ]),
      if (groups.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No groups yet. Create a group using a saved scheme.'))),
      ...groups.map((g) => Card(child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.groups)),
        title: Text(g['name'] as String),
        subtitle: Text('${g['template_name']}\nStart: ${DateFormat('dd MMM yyyy').format(DateTime.parse(g['start_date'] as String))}'),
        isThreeLine: true,
        trailing: Text('${g['members']} members'),
      ))),
    ]),
  );
}

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});
  @override State<MembersPage> createState() => _MembersPageState();
}
class _MembersPageState extends State<MembersPage> {
  List<Map<String,Object?>> members = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { members = await AppDb.instance.members(); if(mounted)setState((){}); }

  Future<void> add() async {
    final groups = await AppDb.instance.groups();
    if(groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a chit group first.')));
      return;
    }
    final name = TextEditingController(), phone = TextEditingController(), address = TextEditingController(), no = TextEditingController();
    int groupId = groups.first['id'] as int;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Add Member'),
        content: SingleChildScrollView(child: Column(children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number')),
          TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
          TextField(controller: no, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Member number')),
          DropdownButton<int>(
            isExpanded: true, value: groupId,
            items: groups.map((g) => DropdownMenuItem<int>(value: g['id'] as int, child: Text('${g['name']} • ${g['template_name']}'))).toList(),
            onChanged: (v) { if(v != null)setD(()=>groupId=v); },
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      )),
    );
    if(ok == true && name.text.trim().isNotEmpty && phone.text.trim().isNotEmpty) {
      await AppDb.instance.addMember(name.text.trim(), phone.text.trim(), address.text.trim(), groupId, int.tryParse(no.text) ?? 0);
      load();
    }
  }

  Future<void> whatsapp(Map<String,Object?> m) async {
    final phone = (m['mobile'] as String).replaceAll(RegExp(r'[^0-9+]'), '');
    final text = Uri.encodeComponent('Dear ${m['name']}, your monthly chit installment is ${money(m['installment'] as int)}. Please make the payment on time. Thank you.');
    final uri = Uri.parse('https://wa.me/$phone?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override Widget build(BuildContext context) => Scaffold(
    body: ListView(padding: const EdgeInsets.all(12), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Members', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        FilledButton.icon(onPressed: add, icon: const Icon(Icons.person_add), label: const Text('Add')),
      ]),
      const SizedBox(height: 8),
      ...members.map((m) => Card(child: ListTile(
        leading: CircleAvatar(child: Text('${m['member_no']}')),
        title: Text(m['name'] as String),
        subtitle: Text('${m['group_name']} • ${money(m['installment'] as int)}/month\n${m['mobile']}'),
        isThreeLine: true,
        trailing: IconButton(onPressed: () => whatsapp(m), icon: const Icon(Icons.chat)),
      ))),
    ]),
  );
}

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});
  @override State<AnalysisPage> createState() => _AnalysisPageState();
}
class _AnalysisPageState extends State<AnalysisPage> {
  Map<String,int> d = {};
  @override void initState(){super.initState();load();}
  Future<void> load() async {d=await AppDb.instance.dashboard();if(mounted)setState((){});}
  @override Widget build(BuildContext context) {
    final movement = (d['received']??0)-(d['given']??0);
    return ListView(padding: const EdgeInsets.all(12), children: [
      const Text('Business Analysis', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      Card(child: ListTile(title: const Text('Total received'), trailing: Text(money(d['received']??0)))),
      Card(child: ListTile(title: const Text('Total given out'), trailing: Text(money(d['given']??0)))),
      Card(child: ListTile(title: const Text('Cash movement difference'), subtitle: const Text('Not the same as accounting profit.'), trailing: Text(money(movement)))),
      Card(child: ListTile(title: const Text('Outstanding installments'), trailing: Text(money(d['outstanding']??0)))),
      const SizedBox(height: 12),
      const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('The final version will separate collections, chit payouts, expenses, penalties and auction/dividend amounts so profit is calculated from the actual business rules rather than simply cash in minus cash out.'))),
    ]);
  }
}
