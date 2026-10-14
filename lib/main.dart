import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const AganApp()); }

class Store {
  static Database? _db;
  static Future<Database> get db async {
    if (_db != null) return _db!;
    final location = join(await getDatabasesPath(), 'agan_ponsel_v1.db');
    _db = await openDatabase(location, version: 2, onUpgrade: (d, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await d.execute('CREATE TABLE IF NOT EXISTS customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT NOT NULL, note TEXT NOT NULL)');
        await d.execute('CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, amount INTEGER NOT NULL, created_at TEXT NOT NULL)');
        await d.execute('CREATE TABLE IF NOT EXISTS digital_transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, operator TEXT NOT NULL, destination TEXT NOT NULL, nominal INTEGER NOT NULL, fee INTEGER NOT NULL, created_at TEXT NOT NULL)');
      }
    }, onCreate: (d, v) async {
      await d.execute('CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, stock INTEGER NOT NULL DEFAULT 0, cost INTEGER NOT NULL DEFAULT 0, price INTEGER NOT NULL DEFAULT 0)');
      await d.execute('CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL, name TEXT NOT NULL, qty INTEGER NOT NULL, total INTEGER NOT NULL, profit INTEGER NOT NULL, created_at TEXT NOT NULL)');
      await d.execute('CREATE TABLE services(id INTEGER PRIMARY KEY AUTOINCREMENT, customer TEXT NOT NULL, phone TEXT NOT NULL, device TEXT NOT NULL, issue TEXT NOT NULL, fee INTEGER NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL)');
      await d.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT NOT NULL, note TEXT NOT NULL)');
      await d.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, amount INTEGER NOT NULL, created_at TEXT NOT NULL)');
      await d.execute('CREATE TABLE digital_transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, operator TEXT NOT NULL, destination TEXT NOT NULL, nominal INTEGER NOT NULL, fee INTEGER NOT NULL, created_at TEXT NOT NULL)');
    });
    return _db!;
  }
}

class AganApp extends StatelessWidget {
  const AganApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(title: 'AGAN PONSEL', debugShowCheckedModeBanner: false, theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF6F8FC), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0875E8)), appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0875E8), foregroundColor: Colors.white), cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))), home: const Home());
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState() => _HomeState(); }
class _HomeState extends State<Home> {
  int tab = 0;
  int revision = 0;
  final pages = const ['Beranda', 'Kasir', 'Produk & Stok', 'Service HP', 'Lainnya'];
  void open(Widget page) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => page)); if (mounted) setState(() => revision++); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(toolbarHeight: 66, title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('AGAN PONSEL', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), Text(pages[tab] == 'Beranda' ? 'HP • ACCESSORIES • SERVICE • PULSA' : pages[tab], style: const TextStyle(fontSize: 10, letterSpacing: 0.7))]), actions: [IconButton(onPressed: () => open(const ReportsPage()), icon: const Icon(Icons.notifications_none_rounded))]),
    body: IndexedStack(index: tab, children: [Dashboard(key: ValueKey(revision)), Products(key: ValueKey('pos$revision')), InventoryPage(key: ValueKey('stock$revision')), Services(key: ValueKey('svc$revision')), MorePage(open: open)]),
    bottomNavigationBar: NavigationBar(height: 68, backgroundColor: Colors.white, indicatorColor: const Color(0xFFDDEBFF), selectedIndex: tab, onDestinationSelected: (v) => setState(() {tab = v; revision++;}), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'), NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), label: 'Kasir'), NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Produk'), NavigationDestination(icon: Icon(Icons.handyman_outlined), label: 'Service'), NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Lainnya')]),
  );
}

String rupiah(int v) => 'Rp${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
InputDecoration field(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder());
Future<void> notice(BuildContext c, String text) async { if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(text))); }

class Dashboard extends StatefulWidget { const Dashboard({super.key}); @override State<Dashboard> createState() => _DashboardState(); }
class _DashboardState extends State<Dashboard> {
  Future<List<int>> totals() async {
    final d = await Store.db;
    final sales = await d.rawQuery('SELECT COALESCE(SUM(total),0) AS total, COALESCE(SUM(profit),0) AS profit, COUNT(*) AS count FROM sales');
    final services = await d.rawQuery("SELECT COUNT(*) AS n FROM services WHERE status != 'Selesai'");
    return [sales.first['total'] as int, sales.first['profit'] as int, sales.first['count'] as int, services.first['n'] as int];
  }
  @override Widget build(BuildContext context) => FutureBuilder<List<int>>(future: totals(), builder: (c, s) {
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    final v = s.data!;
    return RefreshIndicator(onRefresh: () async => setState(() {}), child: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [const CircleAvatar(radius: 24, child: Icon(Icons.person)), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Selamat Datang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), Text('Pemilik Toko • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(color: Colors.black54))])]))),
      const SizedBox(height: 12),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.7, mainAxisSpacing: 10, crossAxisSpacing: 10, children: [
        metric('Penjualan', rupiah(v[0]), Icons.shopping_cart, const Color(0xFFDBF9E9), Colors.green),
        metric('Keuntungan', rupiah(v[1]), Icons.bar_chart, const Color(0xFFDDEBFF), Colors.blue),
        metric('Transaksi', '${v[2]}', Icons.receipt_long, const Color(0xFFFFEAC9), Colors.orange),
        metric('Service Aktif', '${v[3]}', Icons.build, const Color(0xFFFFDDE3), Colors.red),
      ]), const SizedBox(height: 22), const Text('Menu Utama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, childAspectRatio: .85, mainAxisSpacing: 8, children: [
        shortcut(context, 'Kasir', Icons.point_of_sale, const Products()), shortcut(context, 'Produk', Icons.inventory_2, const InventoryPage()), shortcut(context, 'Service', Icons.handyman, const Services()), shortcut(context, 'Pulsa & Data', Icons.phone_android, const DigitalPage()),
        shortcut(context, 'Pelanggan', Icons.people, const CustomersPage()), shortcut(context, 'Laporan', Icons.bar_chart, const ReportsPage()), shortcut(context, 'Pengeluaran', Icons.wallet, const ExpensesPage()), shortcut(context, 'Pengaturan', Icons.settings, const SettingsPage()),
      ]), const SizedBox(height: 12), const Text('Data tersimpan di perangkat Android ini.', style: TextStyle(color: Colors.black54)),
    ]));
  });
}
Widget metric(String label, String value, IconData icon, Color bg, Color fg) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(17)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: fg), Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: fg), maxLines: 1, overflow: TextOverflow.ellipsis), Text(label, style: const TextStyle(fontSize: 11))]));
Widget shortcut(BuildContext context, String label, IconData icon, Widget page) => InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)), child: Column(children: [Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFE4EFFF), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: const Color(0xFF0875E8))), const SizedBox(height: 7), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))]));

class Products extends StatefulWidget { const Products({super.key}); @override State<Products> createState() => _ProductsState(); }
class _ProductsState extends State<Products> {
  Future<List<Map<String, Object?>>> load() async => (await Store.db).query('products', orderBy: 'id DESC');
  Future<void> add() async {
    final name = TextEditingController(), stock = TextEditingController(text: '0'), cost = TextEditingController(text: '0'), price = TextEditingController(text: '0');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Tambah produk'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: field('Nama produk')), const SizedBox(height: 8), TextField(controller: stock, keyboardType: TextInputType.number, decoration: field('Stok')), const SizedBox(height: 8), TextField(controller: cost, keyboardType: TextInputType.number, decoration: field('Modal / unit')), const SizedBox(height: 8), TextField(controller: price, keyboardType: TextInputType.number, decoration: field('Harga jual / unit'))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan'))]));
    if (ok == true && name.text.trim().isNotEmpty && (int.tryParse(stock.text) ?? -1) >= 0 && (int.tryParse(cost.text) ?? -1) >= 0 && (int.tryParse(price.text) ?? -1) >= 0) {
      await (await Store.db).insert('products', {'name': name.text.trim(), 'stock': int.parse(stock.text), 'cost': int.parse(cost.text), 'price': int.parse(price.text)});
      setState(() {});
    } else if (ok == true && mounted) { await notice(context, 'Periksa nama dan angka produk'); }
    for (final x in [name, stock, cost, price]) { x.dispose(); }
  }
  Future<void> sell(Map<String, Object?> p) async {
    final qty = TextEditingController(text: '1');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Jual ${p['name']}'), content: TextField(controller: qty, keyboardType: TextInputType.number, decoration: field('Jumlah')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Konfirmasi jual'))]));
    final n = int.tryParse(qty.text) ?? 0;
    qty.dispose();
    if (ok != true) return;
    if (n <= 0) { if (mounted) await notice(context, 'Jumlah harus lebih dari 0'); return; }
    final d = await Store.db;
    try {
      await d.transaction((txn) async {
        final current = (await txn.query('products', where: 'id = ?', whereArgs: [p['id']])).first;
        if ((current['stock'] as int) < n) throw StateError('Stok tidak cukup');
        final total = (current['price'] as int) * n;
        final profit = ((current['price'] as int) - (current['cost'] as int)) * n;
        await txn.update('products', {'stock': (current['stock'] as int) - n}, where: 'id = ?', whereArgs: [p['id']]);
        await txn.insert('sales', {'product_id': p['id'], 'name': current['name'], 'qty': n, 'total': total, 'profit': profit, 'created_at': DateTime.now().toIso8601String()});
      });
      if (mounted) { setState(() {}); await notice(context, 'Penjualan tersimpan'); }
    } catch (e) { if (mounted) await notice(context, 'Gagal: $e'); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: FutureBuilder<List<Map<String, Object?>>>(future: load(), builder: (c, s) => !s.hasData ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(12), children: [for (final p in s.data!) Card(child: ListTile(title: Text('${p['name']}'), subtitle: Text('Stok ${p['stock']} • Modal ${rupiah(p['cost'] as int)} • Jual ${rupiah(p['price'] as int)}'), trailing: FilledButton.tonal(onPressed: () => sell(p), child: const Text('Jual'))))])), floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add), label: const Text('Produk')));
}

class Services extends StatefulWidget { const Services({super.key}); @override State<Services> createState() => _ServicesState(); }
class _ServicesState extends State<Services> {
  Future<List<Map<String, Object?>>> load() async => (await Store.db).query('services', orderBy: 'id DESC');
  Future<void> add() async {
    final customer = TextEditingController(), phone = TextEditingController(), device = TextEditingController(), issue = TextEditingController(), fee = TextEditingController(text: '0');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Service baru'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [for (final item in [(customer, 'Nama pelanggan'), (phone, 'Nomor HP'), (device, 'Merek / tipe HP'), (issue, 'Kerusakan'), (fee, 'Estimasi biaya')]) ...[TextField(controller: item.$1, keyboardType: item.$1 == fee ? TextInputType.number : TextInputType.text, decoration: field(item.$2)), const SizedBox(height: 8)]])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan'))]));
    if (ok == true && customer.text.trim().isNotEmpty && device.text.trim().isNotEmpty && (int.tryParse(fee.text) ?? -1) >= 0) {
      await (await Store.db).insert('services', {'customer': customer.text.trim(), 'phone': phone.text.trim(), 'device': device.text.trim(), 'issue': issue.text.trim(), 'fee': int.parse(fee.text), 'status': 'Diterima', 'created_at': DateTime.now().toIso8601String()});
      setState(() {});
    } else if (ok == true && mounted) { await notice(context, 'Isi nama, perangkat, dan biaya dengan benar'); }
    for (final x in [customer, phone, device, issue, fee]) { x.dispose(); }
  }
  Future<void> changeStatus(Map<String, Object?> item) async {
    final status = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [for (final x in ['Diterima', 'Dikerjakan', 'Menunggu sparepart', 'Selesai']) ListTile(title: Text(x), onTap: () => Navigator.pop(ctx, x))])));
    if (status != null) { await (await Store.db).update('services', {'status': status}, where: 'id = ?', whereArgs: [item['id']]); setState(() {}); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: FutureBuilder<List<Map<String, Object?>>>(future: load(), builder: (c, s) => !s.hasData ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(12), children: [for (final item in s.data!) Card(child: ListTile(title: Text('${item['customer']} • ${item['device']}'), subtitle: Text('${item['issue']}\n${rupiah(item['fee'] as int)} • ${item['status']}'), isThreeLine: true, trailing: const Icon(Icons.chevron_right), onTap: () => changeStatus(item)))])), floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add), label: const Text('Service')));
}

class PageShell extends StatelessWidget {
  final String title; final Widget child; final Widget? fab;
  const PageShell({super.key, required this.title, required this.child, this.fab});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: child, floatingActionButton: fab);
}
class InventoryPage extends StatefulWidget { const InventoryPage({super.key}); @override State<InventoryPage> createState() => _InventoryPageState(); }
class _InventoryPageState extends State<InventoryPage> {
  Future<void> add() async {
    final values = await entry(context, 'Tambah Produk', ['Nama produk','Stok','Harga modal','Harga jual']);
    if (values == null) return;
    final n = values.skip(1).map((x) => int.tryParse(x)).toList();
    if (values[0].isEmpty || n.any((x) => x == null || x < 0)) { if(mounted) notice(context, 'Isi nama dan angka dengan benar'); return; }
    await (await Store.db).insert('products', {'name':values[0], 'stock':n[0], 'cost':n[1], 'price':n[2]}); setState((){});
  }
  @override Widget build(BuildContext context) => PageShell(title: 'Produk & Stok', fab: FloatingActionButton(onPressed: add, child: const Icon(Icons.add)), child: FutureBuilder<List<Map<String,Object?>>>(future: Store.db.then((d)=>d.query('products', orderBy:'id DESC')), builder:(c,s)=> !s.hasData ? const Center(child:CircularProgressIndicator()) : s.data!.isEmpty ? const Center(child:Text('Belum ada produk. Tekan + untuk menambah.')) : ListView(padding:const EdgeInsets.all(12), children:[for(final p in s.data!) Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.inventory_2_outlined)),title:Text('${p['name']}'),subtitle:Text('Stok: ${p['stock']} • Modal: ${rupiah(p['cost'] as int)}'),trailing:Text(rupiah(p['price'] as int),style:const TextStyle(fontWeight:FontWeight.bold)),onTap:() async {final v=await entry(context,'Perbarui Stok',['Jumlah stok baru'], initial:['${p['stock']}']);final stock=int.tryParse(v?.first ?? '');if(stock!=null&&stock>=0){await (await Store.db).update('products',{'stock':stock},where:'id=?',whereArgs:[p['id']]);setState((){});}}))]));
}
Future<List<String>?> entry(BuildContext context,String title,List<String> labels,{List<String>? initial}) async {
  final ctrls=List.generate(labels.length,(i)=>TextEditingController(text:initial!=null ? initial[i] : ''));
  final result=await showModalBottomSheet<List<String>>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>Padding(padding:EdgeInsets.fromLTRB(20,10,20,MediaQuery.viewInsetsOf(ctx).bottom+20),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:14),for(var i=0;i<labels.length;i++) Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:ctrls[i],keyboardType:RegExp('Stok|Harga|Nominal|Biaya|Admin|Jumlah|Pengeluaran',caseSensitive:false).hasMatch(labels[i])?TextInputType.number:TextInputType.text,decoration:field(labels[i]))),FilledButton(onPressed:()=>Navigator.pop(ctx,ctrls.map((e)=>e.text.trim()).toList()),child:const Text('Simpan'))]))));
  for(final c in ctrls){c.dispose();} return result;
}
class CustomersPage extends StatefulWidget { const CustomersPage({super.key}); @override State<CustomersPage> createState()=>_CustomersPageState(); }
class _CustomersPageState extends State<CustomersPage> {
  Future<void> add() async { final v=await entry(context,'Pelanggan Baru',['Nama','Nomor HP','Catatan']); if(v==null||v[0].isEmpty)return;await (await Store.db).insert('customers',{'name':v[0],'phone':v[1],'note':v[2]});setState((){}); }
  @override Widget build(BuildContext context)=>PageShell(title:'Pelanggan',fab:FloatingActionButton(onPressed:add,child:const Icon(Icons.add)),child:FutureBuilder<List<Map<String,Object?>>>(future:Store.db.then((d)=>d.query('customers',orderBy:'id DESC')),builder:(c,s)=>!s.hasData?const Center(child:CircularProgressIndicator()):ListView(children:[for(final x in s.data!) Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text('${x['name']}'),subtitle:Text('${x['phone']}\n${x['note']}'),isThreeLine:true))])));
}
class ExpensesPage extends StatefulWidget { const ExpensesPage({super.key}); @override State<ExpensesPage> createState()=>_ExpensesPageState(); }
class _ExpensesPageState extends State<ExpensesPage> {
  Future<void> add() async {final v=await entry(context,'Catat Pengeluaran',['Keterangan','Jumlah Pengeluaran']);final amount=int.tryParse(v?.last??'');if(v==null||v[0].isEmpty||amount==null||amount<=0)return;await (await Store.db).insert('expenses',{'description':v[0],'amount':amount,'created_at':DateTime.now().toIso8601String()});setState((){});}
  @override Widget build(BuildContext context)=>PageShell(title:'Pengeluaran',fab:FloatingActionButton(onPressed:add,child:const Icon(Icons.add)),child:FutureBuilder<List<Map<String,Object?>>>(future:Store.db.then((d)=>d.query('expenses',orderBy:'id DESC')),builder:(c,s)=>!s.hasData?const Center(child:CircularProgressIndicator()):ListView(children:[for(final x in s.data!)Card(child:ListTile(title:Text('${x['description']}'),subtitle:Text('${x['created_at']}'.substring(0,10)),trailing:Text(rupiah(x['amount'] as int))))])));
}
class DigitalPage extends StatefulWidget { const DigitalPage({super.key}); @override State<DigitalPage> createState()=>_DigitalPageState(); }
class _DigitalPageState extends State<DigitalPage> {
  Future<void> add() async {final v=await entry(context,'Catat Transaksi Digital',['Operator / Layanan','Nomor Tujuan','Nominal','Biaya Admin']);if(v==null)return;final n=int.tryParse(v[2]),f=int.tryParse(v[3]);if(v[0].isEmpty||n==null||f==null||n<0||f<0)return;await (await Store.db).insert('digital_transactions',{'operator':v[0],'destination':v[1],'nominal':n,'fee':f,'created_at':DateTime.now().toIso8601String()});setState((){});}
  @override Widget build(BuildContext context)=>PageShell(title:'Pulsa & Paket Data',fab:FloatingActionButton(onPressed:add,child:const Icon(Icons.add)),child:FutureBuilder<List<Map<String,Object?>>>(future:Store.db.then((d)=>d.query('digital_transactions',orderBy:'id DESC')),builder:(c,s)=>!s.hasData?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(12),children:[const Card(child:ListTile(leading:Icon(Icons.info_outline),title:Text('Pencatatan transaksi offline'),subtitle:Text('Tidak mengirim pulsa atau memproses pembayaran sungguhan.'))),for(final x in s.data!)Card(child:ListTile(title:Text('${x['operator']} • ${x['destination']}'),subtitle:Text('Admin ${rupiah(x['fee'] as int)}'),trailing:Text(rupiah(x['nominal'] as int))))])));
}
class ReportsPage extends StatelessWidget { const ReportsPage({super.key});
  Future<List<int>> load() async {final d=await Store.db;final a=(await d.rawQuery('SELECT COALESCE(SUM(total),0) t, COALESCE(SUM(profit),0) p, COUNT(*) c FROM sales')).first;final b=(await d.rawQuery('SELECT COALESCE(SUM(amount),0) t FROM expenses')).first;final e=(await d.rawQuery('SELECT COALESCE(SUM(fee),0) t FROM digital_transactions')).first;return [a['t'] as int,a['p'] as int,a['c'] as int,b['t'] as int,e['t'] as int];}
  @override Widget build(BuildContext context)=>PageShell(title:'Laporan Keuangan',child:FutureBuilder<List<int>>(future:load(),builder:(c,s)=>!s.hasData?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[metric('Total omzet penjualan',rupiah(s.data![0]),Icons.trending_up,const Color(0xFFDBF9E9),Colors.green),const SizedBox(height:10),metric('Laba kotor produk',rupiah(s.data![1]),Icons.bar_chart,const Color(0xFFDDEBFF),Colors.blue),const SizedBox(height:10),metric('Pengeluaran',rupiah(s.data![3]),Icons.payments,const Color(0xFFFFEAC9),Colors.orange),const SizedBox(height:10),metric('Pendapatan admin digital',rupiah(s.data![4]),Icons.phone_android,const Color(0xFFEFE1FF),Colors.deepPurple),const SizedBox(height:10),metric('Estimasi laba setelah pengeluaran',rupiah(s.data![1]+s.data![4]-s.data![3]),Icons.account_balance_wallet,const Color(0xFFE4F3F3),Colors.teal),const SizedBox(height:12),const Text('Ringkasan seluruh periode. Belum termasuk laba service, pajak, dan penyesuaian stok.',style:TextStyle(color:Colors.black54))])));
}
class SettingsPage extends StatelessWidget { const SettingsPage({super.key}); @override Widget build(BuildContext context)=>PageShell(title:'Pengaturan',child:ListView(children:const [Card(child:ListTile(leading:Icon(Icons.store),title:Text('AGAN PONSEL'),subtitle:Text('Profil toko • Versi Flutter offline'))),Card(child:ListTile(leading:Icon(Icons.storage),title:Text('Database lokal SQLite'),subtitle:Text('Tersimpan pada penyimpanan privat aplikasi Android'))),Card(child:ListTile(leading:Icon(Icons.backup_outlined),title:Text('Backup & Restore'),subtitle:Text('Belum tersedia di versi pengembangan ini'))),Card(child:ListTile(leading:Icon(Icons.print_outlined),title:Text('Printer Bluetooth'),subtitle:Text('Integrasi printer belum tersedia')))])); }
class MorePage extends StatelessWidget { final void Function(Widget) open; const MorePage({super.key,required this.open}); @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[for(final item in <(String,IconData,Widget)>[('Pulsa & Paket Data',Icons.phone_android, const DigitalPage()),('Pelanggan',Icons.people,const CustomersPage()),('Laporan Keuangan',Icons.bar_chart,const ReportsPage()),('Pengeluaran',Icons.wallet,const ExpensesPage()),('Pengaturan',Icons.settings,const SettingsPage())])Card(child:ListTile(leading:Icon(item.$2,color:const Color(0xFF0875E8)),title:Text(item.$1),trailing:const Icon(Icons.chevron_right),onTap:()=>open(item.$3)))]); }
