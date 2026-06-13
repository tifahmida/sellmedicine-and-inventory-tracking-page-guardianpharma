import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner_plus/flutter_barcode_scanner_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pharmacy_wrapper_page.dart';

// ============================================================
// InventoryListPage  (unchanged — kept as-is)
// ============================================================
class InventoryListPage extends StatefulWidget {
  const InventoryListPage({super.key});

  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> allMedicines = [];
  List<Map<String, dynamic>> filtered = [];
  bool loading = true;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    searchController.addListener(_filter);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .order('medicine_name');
      setState(() {
        allMedicines = List<Map<String, dynamic>>.from(res);
        filtered = allMedicines;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void _filter() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filtered = allMedicines.where((m) {
        final name = (m['medicine_name'] ?? '').toString().toLowerCase();
        final generic = (m['generic_name'] ?? '').toString().toLowerCase();
        final batch = (m['batch_number'] ?? '').toString().toLowerCase();
        return name.contains(q) || generic.contains(q) || batch.contains(q);
      }).toList();
    });
  }

  Color _expiryColor(String? s) {
    if (s == null) return Colors.grey;
    final d = DateTime.tryParse(s);
    if (d == null) return Colors.grey;
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.redAccent;
    if (days <= 30) return Colors.orange;
    return Colors.greenAccent;
  }

  String _expiryLabel(String? s) {
    if (s == null) return 'Expiry: N/A';
    final d = DateTime.tryParse(s);
    if (d == null) return 'Expiry: $s';
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return '⛔ EXPIRED ($s)';
    if (days == 0) return '⚠️ Expires TODAY';
    if (days <= 30) return '⚠️ Expires in $days days ($s)';
    return '✅ Expires: $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/guardianpharmapills.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.50)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.inventory_2, color: Colors.blueAccent),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Inventory & Medicine Lookup',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _load,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.blueAccent,
                      ),
                      hintText: 'Search by name, generic name, batch...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white38,
                              ),
                              onPressed: () => searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        )
                      : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.medication_outlined,
                                color: Colors.white24,
                                size: 60,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                searchController.text.isEmpty
                                    ? 'No medicines in inventory'
                                    : 'No results found',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final m = filtered[i];
                            final int qty = (m['quantity'] as int?) ?? 0;
                            final int spb = (m['strips_per_box'] as int?) ?? 10;
                            final int stripsRem =
                                (m['strips_remaining'] as int?) ?? (qty * spb);
                            final String batch =
                                m['batch_number']?.toString() ?? 'N/A';
                            final Color expColor = _expiryColor(
                              m['expiry_date']?.toString(),
                            );
                            final String mfr =
                                m['cartons']?['manufacturers']?['name']
                                    ?.toString() ??
                                'Unknown';
                            final String shelfNum =
                                m['shelf_number']?.toString() ?? '';
                            final String shelfSide =
                                m['shelf_side']?.toString() ?? '';

                            final bool isLowStock = qty > 0 && qty <= 5;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(
                                  255,
                                  255,
                                  255,
                                  0.10,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: expColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m['medicine_name'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            if ((m['generic_name'] ?? '')
                                                .isNotEmpty)
                                              Text(
                                                m['generic_name'],
                                                style: const TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            Text(
                                              '🔢 Batch: $batch',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '🏭 $mfr',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: qty > 0
                                              ? const Color.fromRGBO(
                                                  105,
                                                  240,
                                                  174,
                                                  0.15,
                                                )
                                              : const Color.fromRGBO(
                                                  255,
                                                  82,
                                                  82,
                                                  0.15,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: qty > 0
                                                ? const Color.fromRGBO(
                                                    105,
                                                    240,
                                                    174,
                                                    0.5,
                                                  )
                                                : const Color.fromRGBO(
                                                    255,
                                                    82,
                                                    82,
                                                    0.5,
                                                  ),
                                          ),
                                        ),
                                        child: Text(
                                          qty > 0
                                              ? '✅ In Stock'
                                              : '❌ Out of Stock',
                                          style: TextStyle(
                                            color: qty > 0
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(
                                    color: Colors.white12,
                                    height: 1,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _chip('📦 $qty boxes', Colors.blueAccent),
                                      _chip(
                                        '💊 $stripsRem strips remaining',
                                        Colors.tealAccent,
                                      ),
                                      if (shelfNum.isNotEmpty)
                                        _chip(
                                          '🗄️ Shelf $shelfNum',
                                          Colors.purpleAccent,
                                        ),
                                      if (shelfSide.isNotEmpty)
                                        _chip(
                                          '◀ $shelfSide ▶',
                                          Colors.cyanAccent,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (isLowStock)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: const Color.fromRGBO(
                                          255,
                                          152,
                                          0,
                                          0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color.fromRGBO(
                                            255,
                                            152,
                                            0,
                                            0.5,
                                          ),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber,
                                            color: Colors.orange,
                                            size: 14,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            '⚠️ LOW STOCK — Only few boxes left!',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: expColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: expColor.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      _expiryLabel(
                                        m['expiry_date']?.toString(),
                                      ),
                                      style: TextStyle(
                                        color: expColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

// ============================================================
// SellMedicineAndInventoryPage
// ============================================================
class SellMedicineAndInventoryPage extends StatefulWidget {
  final Map<String, dynamic>? preSelected;
  final bool openBarcode;

  const SellMedicineAndInventoryPage({
    super.key,
    this.preSelected,
    this.openBarcode = false,
  });

  @override
  State<SellMedicineAndInventoryPage> createState() =>
      _SellMedicineAndInventoryPageState();
}

class _SellMedicineAndInventoryPageState
    extends State<SellMedicineAndInventoryPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> allMedicines = [];
  List<Map<String, dynamic>> groupedMedicines = [];
  List<Map<String, dynamic>> filteredGrouped = [];
  bool loadingMedicines = true;
  final searchController = TextEditingController();

  List<Map<String, dynamic>> manufacturers = [];
  bool loadingManufacturers = true;

  final Map<String, int> _safeLimitsByKeyword = {
    'paracetamol': 5,
    'napa': 5,
    'sleeping': 2,
    'painkiller': 3,
    'antibiotic': 4,
  };
  static const int _defaultSafeLimit = 10;

  final List<String> _units = [
    'Tablets',
    'Syrup',
    'Powder',
    'Capsules',
    'Injection',
    'Custom',
  ];
  final List<String> _shelfSides = ['Left', 'Right', 'Middle', 'Top', 'Bottom'];

  final _substituteSearchCtrl = TextEditingController();
  bool _searchingSubstitute = false;
  bool _substitutedSearched = false;
  Map<String, dynamic>? _searchedMedicine;
  List<Map<String, dynamic>> _substituteResults = [];
  String _resolvedGeneric = '';
  String _substituteError = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadMedicines();
    _loadManufacturers();
    searchController.addListener(_filterGrouped);

    final preSelected = widget.preSelected;
    if (preSelected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSellDialog(preSelected);
      });
    }

    if (widget.openBarcode) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final code = await _scanBarcodeCamera();
        if (code != null && code.isNotEmpty) {
          searchController.text = code;
          _filterGrouped();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    _substituteSearchCtrl.dispose();
    super.dispose();
  }

  // ── LOAD DATA ─────────────────────────────────────────────

  Future<void> _loadMedicines() async {
    setState(() => loadingMedicines = true);
    try {
      final res = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .order('medicine_name')
          .order('expiry_date');
      setState(() {
        allMedicines = List<Map<String, dynamic>>.from(res);
        groupedMedicines = _buildGroupedList(allMedicines);
        filteredGrouped = groupedMedicines;
        loadingMedicines = false;
      });
    } catch (e) {
      _error('Failed to load medicines: $e');
      setState(() => loadingMedicines = false);
    }
  }

  List<Map<String, dynamic>> _buildGroupedList(List<Map<String, dynamic>> raw) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final m in raw) {
      final String name = (m['medicine_name'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      grouped.putIfAbsent(name, () => []).add(m);
    }

    final List<Map<String, dynamic>> result = [];
    grouped.forEach((key, batches) {
      batches.sort((a, b) {
        final da =
            DateTime.tryParse(a['expiry_date']?.toString() ?? '') ??
            DateTime(2100);
        final db =
            DateTime.tryParse(b['expiry_date']?.toString() ?? '') ??
            DateTime(2100);
        return da.compareTo(db);
      });

      int totalBoxes = 0;
      int totalStrips = 0;
      for (final b in batches) {
        totalBoxes += (b['quantity'] as int?) ?? 0;
        final spb = (b['strips_per_box'] as int?) ?? 10;
        totalStrips +=
            (b['strips_remaining'] as int?) ??
            ((b['quantity'] as int?) ?? 0) * spb;
      }

      String? earliestExpiry;
      for (final b in batches) {
        final expStr = b['expiry_date']?.toString();
        if (expStr != null && expStr.isNotEmpty) {
          if (earliestExpiry == null || expStr.compareTo(earliestExpiry) < 0) {
            earliestExpiry = expStr;
          }
        }
      }

      final first = batches.first;

      result.add({
        'medicine_name': first['medicine_name'],
        'generic_name': first['generic_name'],
        'total_boxes': totalBoxes,
        'total_strips': totalStrips,
        'batches': batches,
        'earliest_expiry': earliestExpiry,
        'cartons': first['cartons'],
        'price': first['price'],
      });
    });

    result.sort(
      (a, b) => (a['medicine_name'] as String).compareTo(
        b['medicine_name'] as String,
      ),
    );
    return result;
  }

  void _filterGrouped() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredGrouped = groupedMedicines.where((m) {
        final name = (m['medicine_name'] ?? '').toString().toLowerCase();
        final generic = (m['generic_name'] ?? '').toString().toLowerCase();
        return name.contains(q) || generic.contains(q);
      }).toList();
    });
  }

  Future<void> _loadManufacturers() async {
    setState(() => loadingManufacturers = true);
    try {
      final res = await supabase.from('manufacturers').select().order('name');
      setState(() {
        manufacturers = List<Map<String, dynamic>>.from(res);
        loadingManufacturers = false;
      });
    } catch (e) {
      setState(() => loadingManufacturers = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFifoBatches(
    String medicineName,
  ) async {
    final rows = await supabase
        .from('medicine_boxes')
        .select('*, cartons(*, manufacturers(name, country))')
        .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
        .eq('medicine_name', medicineName)
        .order('expiry_date');
    final list = List<Map<String, dynamic>>.from(rows);
    return list.where((r) => (r['quantity'] as int? ?? 0) > 0).toList();
  }

  // ── HELPERS ───────────────────────────────────────────────

  int _getSafeLimit(String medicineName) {
    final name = medicineName.toLowerCase();
    for (final entry in _safeLimitsByKeyword.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return _defaultSafeLimit;
  }

  bool _isExpired(String? expiryStr) {
    if (expiryStr == null) return false;
    final d = DateTime.tryParse(expiryStr);
    if (d == null) return false;
    return d.difference(DateTime.now()).inDays < 0;
  }

  Color _expiryColor(String? s) {
    if (s == null) return Colors.grey;
    final d = DateTime.tryParse(s);
    if (d == null) return Colors.grey;
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.redAccent;
    if (days <= 30) return Colors.orange;
    return Colors.greenAccent;
  }

  String _expiryLabel(String? s) {
    if (s == null) return 'Expiry: N/A';
    final d = DateTime.tryParse(s);
    if (d == null) return 'Expiry: $s';
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return '⛔ EXPIRED ($s)';
    if (days == 0) return '⚠️ Expires TODAY';
    if (days <= 30) return '⚠️ Expires in $days days ($s)';
    return '✅ Expires: $s';
  }

  // ── BARCODE SCANNING ──────────────────────────────────────

  Future<String?> _scanBarcodeCamera() async {
    try {
      final String scanned = await FlutterBarcodeScanner.scanBarcode(
        '#2196F3',
        'Cancel',
        true,
        ScanMode.BARCODE,
      );
      if (scanned == '-1' || scanned.isEmpty) return null;
      return scanned;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _lookupMedicineByBarcode(
    String barcodeValue,
  ) async {
    try {
      final byBatch = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .eq('batch_number', barcodeValue)
          .limit(1);

      final List<Map<String, dynamic>> batchResults =
          List<Map<String, dynamic>>.from(byBatch);
      if (batchResults.isNotEmpty) return batchResults.first;

      final byName = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .ilike('medicine_name', '%$barcodeValue%')
          .limit(1);

      final List<Map<String, dynamic>> nameResults =
          List<Map<String, dynamic>>.from(byName);
      if (nameResults.isNotEmpty) return nameResults.first;

      return null;
    } catch (e) {
      return null;
    }
  }

  // ── SELL DIALOG ───────────────────────────────────────────

  void _showSellDialog(Map<String, dynamic> groupedMedicine) async {
    final String medicineName =
        groupedMedicine['medicine_name']?.toString() ?? '';

    final List<Map<String, dynamic>> batches = await _fetchFifoBatches(
      medicineName,
    );

    if (batches.isEmpty) {
      _showOutOfStockDialog(groupedMedicine);
      return;
    }

    final allExpired = batches.every(
      (b) => _isExpired(b['expiry_date']?.toString()),
    );
    if (allExpired) {
      _error('All batches of this medicine are expired and cannot be sold.');
      return;
    }

    final validBatches = batches
        .where((b) => !_isExpired(b['expiry_date']?.toString()))
        .toList();

    if (validBatches.isEmpty) {
      _showOutOfStockDialog(groupedMedicine);
      return;
    }

    int totalBoxes = validBatches.fold(
      0,
      (s, b) => s + ((b['quantity'] as int?) ?? 0),
    );
    int totalStrips = 0;
    for (final b in validBatches) {
      final spb = (b['strips_per_box'] as int?) ?? 10;
      totalStrips +=
          (b['strips_remaining'] as int?) ??
          ((b['quantity'] as int?) ?? 0) * spb;
    }

    if (totalBoxes <= 0 || totalStrips <= 0) {
      _showOutOfStockDialog(groupedMedicine);
      return;
    }

    final firstBatch = validBatches.first;
    final int stripsPerBox = (firstBatch['strips_per_box'] as int?) ?? 10;
    final double pricePerBox =
        double.tryParse(firstBatch['price'].toString()) ?? 0.0;
    final double pricePerStrip = firstBatch['price_per_strip'] != null
        ? double.tryParse(firstBatch['price_per_strip'].toString()) ??
              (pricePerBox / stripsPerBox)
        : pricePerBox / stripsPerBox;
    final String genericName =
        groupedMedicine['generic_name']?.toString() ?? '';
    final String mfr =
        firstBatch['cartons']?['manufacturers']?['name']?.toString() ??
        'Unknown';

    final int safeLimit = _getSafeLimit(medicineName);
    final String earliestExpiry =
        validBatches.first['expiry_date']?.toString() ?? 'N/A';

    String saleType = 'strip';
    final qtyCtrl = TextEditingController(text: '1');
    final cartonQtyCtrl = TextEditingController(text: '1');
    final customerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    const int availableCartons = 1;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) {
          final double pricePerCarton = pricePerBox * totalBoxes;

          double unitPrice;
          if (saleType == 'strip') {
            unitPrice = pricePerStrip;
          } else if (saleType == 'box') {
            unitPrice = pricePerBox;
          } else {
            unitPrice = pricePerCarton;
          }

          final int enteredQty = saleType == 'carton'
              ? (int.tryParse(cartonQtyCtrl.text) ?? 1)
              : (int.tryParse(qtyCtrl.text) ?? 1);

          final double total = unitPrice * enteredQty;

          bool exceedsStock = false;
          String stockHintText = '';
          if (saleType == 'strip') {
            exceedsStock = enteredQty > totalStrips;
            stockHintText =
                'Available: $totalStrips strips ($totalBoxes boxes, ${validBatches.length} batch(es))';
          } else if (saleType == 'box') {
            exceedsStock = enteredQty > totalBoxes;
            stockHintText =
                'Available: $totalBoxes boxes (${validBatches.length} batch(es))';
          } else {
            exceedsStock = enteredQty > availableCartons;
            stockHintText =
                'Available: $availableCartons carton(s) ($totalBoxes boxes total)';
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  medicineName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (genericName.isNotEmpty)
                  Text(
                    genericName,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _infoRow('🏭 Manufacturer', mfr),
                        _infoRow('📅 Earliest Expiry', earliestExpiry),
                        _infoRow(
                          '📦 Total Stock',
                          '$totalBoxes boxes  •  $totalStrips strips',
                        ),
                        _infoRow('🔄 Active Batches', '${validBatches.length}'),
                        _infoRow('💊 Strips/Box', '$stripsPerBox strips'),
                        _infoRow(
                          '💰 Price/Box',
                          'BDT ${pricePerBox.toStringAsFixed(2)}',
                        ),
                        _infoRow(
                          '💊 Price/Strip',
                          'BDT ${pricePerStrip.toStringAsFixed(2)}',
                        ),
                        _infoRow(
                          '🏭 Price/Carton',
                          'BDT ${pricePerCarton.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(68, 138, 255, 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color.fromRGBO(68, 138, 255, 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.format_list_numbered,
                              color: Colors.blueAccent,
                              size: 13,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'FIFO Batch Order (oldest sold first):',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...validBatches.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final b = entry.value;
                          final bQty = (b['quantity'] as int?) ?? 0;
                          final bBatch = b['batch_number']?.toString() ?? 'N/A';
                          final bExp = b['expiry_date']?.toString() ?? 'N/A';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '$idx. Batch $bBatch — $bQty boxes — Exp: $bExp',
                              style: TextStyle(
                                color: idx == 1
                                    ? Colors.greenAccent
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Sell as:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _saleTypeChip(
                        'strip',
                        '💊 Strip',
                        saleType,
                        (v) => setDs(() {
                          saleType = v;
                          qtyCtrl.text = '1';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _saleTypeChip(
                        'box',
                        '📦 Box',
                        saleType,
                        (v) => setDs(() {
                          saleType = v;
                          qtyCtrl.text = '1';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _saleTypeChip(
                        'carton',
                        '🏭 Carton',
                        saleType,
                        (v) => setDs(() {
                          saleType = v;
                          cartonQtyCtrl.text = '1';
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (saleType == 'strip' || saleType == 'box') ...[
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: exceedsStock ? Colors.redAccent : Colors.white,
                      ),
                      onChanged: (_) => setDs(() {}),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.numbers,
                          color: exceedsStock
                              ? Colors.redAccent
                              : Colors.white70,
                        ),
                        hintText: 'Quantity',
                        hintStyle: const TextStyle(color: Colors.white38),
                        helperText: stockHintText,
                        helperStyle: TextStyle(
                          color: exceedsStock
                              ? Colors.redAccent
                              : Colors.white38,
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: exceedsStock
                            ? const Color.fromRGBO(255, 82, 82, 0.1)
                            : const Color.fromRGBO(255, 255, 255, 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: exceedsStock
                              ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: exceedsStock
                              ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                      ),
                    ),
                    if (exceedsStock) ...[
                      const SizedBox(height: 6),
                      _stockErrorBox(
                        saleType == 'strip'
                            ? '❌ Only $totalStrips strips available ($totalBoxes boxes)'
                            : '❌ Only $totalBoxes boxes available',
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                  if (saleType == 'carton') ...[
                    TextField(
                      controller: cartonQtyCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: exceedsStock ? Colors.redAccent : Colors.white,
                      ),
                      onChanged: (_) => setDs(() {}),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.widgets,
                          color: exceedsStock
                              ? Colors.redAccent
                              : Colors.white70,
                        ),
                        hintText: 'Number of cartons',
                        hintStyle: const TextStyle(color: Colors.white38),
                        helperText: stockHintText,
                        helperStyle: TextStyle(
                          color: exceedsStock
                              ? Colors.redAccent
                              : Colors.white38,
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: exceedsStock
                            ? const Color.fromRGBO(255, 82, 82, 0.1)
                            : const Color.fromRGBO(255, 255, 255, 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: exceedsStock
                              ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: exceedsStock
                              ? const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: exceedsStock
                            ? const Color.fromRGBO(255, 82, 82, 0.12)
                            : const Color.fromRGBO(255, 152, 0, 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: exceedsStock
                              ? const Color.fromRGBO(255, 82, 82, 0.5)
                              : const Color.fromRGBO(255, 152, 0, 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            exceedsStock
                                ? Icons.error_outline
                                : Icons.info_outline,
                            color: exceedsStock
                                ? Colors.redAccent
                                : Colors.orange,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              exceedsStock
                                  ? '❌ Not enough cartons in stock.\n   Available: $availableCartons carton(s)'
                                  : '1 carton = $totalBoxes boxes ($totalStrips strips total).\nSelling clears ALL stock for this entry.',
                              style: TextStyle(
                                color: exceedsStock
                                    ? Colors.redAccent
                                    : Colors.orange,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: customerCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Colors.white70,
                      ),
                      hintText: 'Customer name (optional)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: Colors.white70,
                      ),
                      hintText: 'Customer phone (optional)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 152, 0, 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color.fromRGBO(255, 152, 0, 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Safe limit: $safeLimit units (strips/boxes/cartons). Selling more requires OTP.',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(68, 138, 255, 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromRGBO(68, 138, 255, 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'BDT ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: exceedsStock
                      ? Colors.grey
                      : Colors.greenAccent,
                ),
                icon: Icon(
                  Icons.check_circle,
                  color: exceedsStock ? Colors.white54 : Colors.black,
                  size: 18,
                ),
                label: Text(
                  'Sell',
                  style: TextStyle(
                    color: exceedsStock ? Colors.white54 : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: exceedsStock
                    ? null
                    : () async {
                        final int qty = saleType == 'carton'
                            ? (int.tryParse(cartonQtyCtrl.text) ?? 1)
                            : (int.tryParse(qtyCtrl.text) ?? 1);
                        if (qty <= 0) {
                          _error('Quantity must be at least 1');
                          return;
                        }
                        final String customer = customerCtrl.text.trim();
                        final String phone = phoneCtrl.text.trim();
                        Navigator.pop(context);

                        if (qty > safeLimit) {
                          _showHighQtyWarning(
                            validBatches: validBatches,
                            qty: qty,
                            saleType: saleType,
                            unitPrice: unitPrice,
                            total: total,
                            customer: customer,
                            phone: phone,
                            medicineName: medicineName,
                            stripsPerBox: stripsPerBox,
                            safeLimit: safeLimit,
                          );
                        } else {
                          await _completeSaleWithFifo(
                            validBatches: validBatches,
                            saleType: saleType,
                            qty: qty,
                            unitPrice: unitPrice,
                            total: total,
                            customer: customer,
                            phone: phone,
                            medicineName: medicineName,
                            stripsPerBox: stripsPerBox,
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stockErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 82, 82, 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromRGBO(255, 82, 82, 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── OUT OF STOCK ──────────────────────────────────────────

  void _showOutOfStockDialog(Map<String, dynamic> medicine) {
    final String medicineName =
        medicine['medicine_name']?.toString() ?? 'This medicine';
    final String genericName = medicine['generic_name']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.remove_circle, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'Out of Stock',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 82, 82, 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color.fromRGBO(255, 82, 82, 0.4),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.inventory_2,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    medicineName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (genericName.isNotEmpty)
                    Text(
                      genericName,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    '❌ 0 boxes  •  0 strips',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This medicine is currently out of stock.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(156, 39, 176, 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color.fromRGBO(156, 39, 176, 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.purple, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Use the 🔍 Substitute tab to find a medicine with the same generic ingredient.',
                      style: TextStyle(color: Colors.purple, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 16),
            label: const Text(
              'Find Substitute',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              Navigator.pop(context);
              _tabController.animateTo(2);
              _substituteSearchCtrl.text =
                  medicine['medicine_name']?.toString() ?? '';
              _searchSubstitutes();
            },
          ),
        ],
      ),
    );
  }

  // ── HIGH QTY WARNING ──────────────────────────────────────

  void _showHighQtyWarning({
    required List<Map<String, dynamic>> validBatches,
    required int qty,
    required String saleType,
    required double unitPrice,
    required double total,
    required String customer,
    required String phone,
    required String medicineName,
    required int stripsPerBox,
    required int safeLimit,
  }) {
    final nameCtrl = TextEditingController(text: customer);
    final phoneCtrl2 = TextEditingController(text: phone);
    final ageCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ High Quantity Detected!',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(244, 67, 54, 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 82, 82, 0.4),
                  ),
                ),
                child: Text(
                  'You are selling $qty ${saleType}s of $medicineName.\n\nSafe limit is $safeLimit ${saleType}s.\n\nCustomer details required to proceed.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _dialogField(nameCtrl, 'Customer Full Name', Icons.person),
              const SizedBox(height: 10),
              _dialogField(
                phoneCtrl2,
                'Phone Number',
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _dialogField(
                ageCtrl,
                'Age',
                Icons.cake,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _dialogField(reasonCtrl, 'Reason for Purchase', Icons.note),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel Sale',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            icon: const Icon(Icons.lock_open, color: Colors.white, size: 16),
            label: const Text(
              'Send OTP',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final ph = phoneCtrl2.text.trim();
              final age = int.tryParse(ageCtrl.text.trim()) ?? 0;
              final reason = reasonCtrl.text.trim();
              if (name.isEmpty || ph.isEmpty || reason.isEmpty) {
                _error('Please fill all required fields');
                return;
              }
              Navigator.pop(context);
              _showOtpDialog(
                validBatches: validBatches,
                qty: qty,
                saleType: saleType,
                unitPrice: unitPrice,
                total: total,
                customerName: name,
                phone: ph,
                age: age,
                reason: reason,
                medicineName: medicineName,
                stripsPerBox: stripsPerBox,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── OTP DIALOG ────────────────────────────────────────────

  void _showOtpDialog({
    required List<Map<String, dynamic>> validBatches,
    required int qty,
    required String saleType,
    required double unitPrice,
    required double total,
    required String customerName,
    required String phone,
    required int age,
    required String reason,
    required String medicineName,
    required int stripsPerBox,
  }) {
    final otpCtrl = TextEditingController();
    bool otpError = false;
    bool otpSent = false;
    bool sending = false;
    bool verifying = false;
    String statusMessage = '';

    String formattedPhone = phone.trim();
    if (formattedPhone.startsWith('0') && formattedPhone.length == 11) {
      formattedPhone = '+880${formattedPhone.substring(1)}';
    } else if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+$formattedPhone';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) {
          Future<void> sendOtp() async {
            setDs(() {
              sending = true;
              statusMessage = '';
              otpError = false;
            });
            try {
              await supabase.auth.signInWithOtp(phone: formattedPhone);
              setDs(() {
                sending = false;
                otpSent = true;
                statusMessage =
                    '✅ OTP sent to $formattedPhone. Check your SMS.';
              });
            } catch (e) {
              setDs(() {
                sending = false;
                otpSent = false;
                statusMessage =
                    '❌ Failed to send OTP: $e\n\nMake sure the phone number is valid and Supabase phone auth is enabled.';
              });
            }
          }

          Future<void> verifyOtp() async {
            final token = otpCtrl.text.trim();
            if (token.length != 6) {
              setDs(() => otpError = true);
              return;
            }
            setDs(() {
              verifying = true;
              otpError = false;
            });
            try {
              final response = await supabase.auth.verifyOTP(
                phone: formattedPhone,
                token: token,
                type: OtpType.sms,
              );

              if (response.user != null || response.session != null) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await _saveSuspiciousLog(
                  medicineName: medicineName,
                  batchNumber:
                      validBatches.first['batch_number']?.toString() ?? 'N/A',
                  qty: qty,
                  customerName: customerName,
                  phone: phone,
                  age: age,
                  reason: reason,
                );
                await _completeSaleWithFifo(
                  validBatches: validBatches,
                  saleType: saleType,
                  qty: qty,
                  unitPrice: unitPrice,
                  total: total,
                  customer: customerName,
                  phone: phone,
                  medicineName: medicineName,
                  stripsPerBox: stripsPerBox,
                );
              } else {
                setDs(() {
                  verifying = false;
                  otpError = true;
                });
              }
            } catch (e) {
              setDs(() {
                verifying = false;
                otpError = true;
                statusMessage = '❌ Verification failed: $e';
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Row(
              children: [
                Icon(Icons.verified_user, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text(
                  'OTP Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(68, 138, 255, 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color.fromRGBO(68, 138, 255, 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.sms, color: Colors.blueAccent, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        otpSent
                            ? '📱 OTP sent to $formattedPhone'
                            : 'Send OTP to: $formattedPhone',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (!otpSent) ...[
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                          ),
                          onPressed: sending ? null : sendOtp,
                          icon: sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 16,
                                ),
                          label: Text(
                            sending ? 'Sending...' : 'Send OTP',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      if (statusMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: statusMessage.startsWith('✅')
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (otpSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (_) => setDs(() => otpError = false),
                    decoration: InputDecoration(
                      hintText: 'Enter OTP',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                      counterStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (otpError)
                    const Text(
                      '❌ Incorrect OTP. Try again.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  TextButton.icon(
                    onPressed: sending ? null : sendOtp,
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white38,
                      size: 14,
                    ),
                    label: const Text(
                      'Resend OTP',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              if (otpSent)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                  icon: verifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check, color: Colors.white, size: 16),
                  label: Text(
                    verifying ? 'Verifying...' : 'Verify & Sell',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: verifying ? null : verifyOtp,
                ),
            ],
          );
        },
      ),
    );
  }

  // ── SUSPICIOUS LOG ────────────────────────────────────────

  Future<void> _saveSuspiciousLog({
    required String medicineName,
    required String batchNumber,
    required int qty,
    required String customerName,
    required String phone,
    required int age,
    required String reason,
  }) async {
    try {
      await supabase.from('suspicious_logs').insert({
        'pharmacy_id': PharmacySession.pharmacyId,
        'pharmacy_name': PharmacySession.pharmacyName,
        'medicine_name': medicineName,
        'batch_number': batchNumber,
        'quantity': qty,
        'activity_type': 'high_quantity_purchase',
        'description':
            '$customerName (age $age, $phone) purchased $qty units of $medicineName. Reason: $reason',
        'flagged_by': 'system',
      });
    } catch (e) {
      debugPrint('Suspicious log error: $e');
    }
  }

  // ── COMPLETE SALE WITH FIFO ───────────────────────────────

  Future<void> _completeSaleWithFifo({
    required List<Map<String, dynamic>> validBatches,
    required String saleType,
    required int qty,
    required double unitPrice,
    required double total,
    required String customer,
    required String phone,
    required String medicineName,
    required int stripsPerBox,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;

      int stripsToDeduct;
      if (saleType == 'carton') {
        stripsToDeduct = validBatches.fold(
          0,
          (s, b) =>
              s +
              ((b['strips_remaining'] as int?) ??
                  ((b['quantity'] as int?) ?? 0) *
                      ((b['strips_per_box'] as int?) ?? stripsPerBox)),
        );
      } else if (saleType == 'box') {
        stripsToDeduct = qty * stripsPerBox;
      } else {
        stripsToDeduct = qty;
      }

      final int totalAvailableStrips = validBatches.fold(
        0,
        (s, b) =>
            s +
            ((b['strips_remaining'] as int?) ??
                ((b['quantity'] as int?) ?? 0) *
                    ((b['strips_per_box'] as int?) ?? stripsPerBox)),
      );

      if (stripsToDeduct > totalAvailableStrips) {
        _error('Not enough stock. Please refresh and try again.');
        return;
      }

      int remaining = stripsToDeduct;
      String firstBatchSold =
          validBatches.first['batch_number']?.toString() ?? 'N/A';

      final List<Map<String, dynamic>> salesBreakdown = [];

      for (final batch in validBatches) {
        if (remaining <= 0) break;

        final String batchId = batch['id'].toString();
        final String cartonId = batch['carton_id']?.toString() ?? '';
        final int spb = (batch['strips_per_box'] as int?) ?? stripsPerBox;
        final int currentStrips =
            (batch['strips_remaining'] as int?) ??
            ((batch['quantity'] as int?) ?? 0) * spb;

        if (currentStrips <= 0) continue;

        final int deductFromThis = remaining < currentStrips
            ? remaining
            : currentStrips;
        remaining -= deductFromThis;

        final int newStrips = (currentStrips - deductFromThis).clamp(
          0,
          currentStrips,
        );
        final int newBoxes = (spb > 0 && newStrips > 0)
            ? (newStrips / spb).ceil()
            : 0;

        if (newBoxes <= 0) {
          await supabase.from('medicine_boxes').delete().eq('id', batchId);
        } else {
          await supabase
              .from('medicine_boxes')
              .update({'quantity': newBoxes, 'strips_remaining': newStrips})
              .eq('id', batchId);
        }

        if (cartonId.isNotEmpty) {
          await _deleteCartonIfEmpty(cartonId);
        }

        salesBreakdown.add({
          'batchId': batchId,
          'batchNumber': batch['batch_number']?.toString() ?? 'N/A',
          'stripsDeducted': deductFromThis,
          'newBoxes': newBoxes,
          'newStrips': newStrips,
          'spb': spb,
        });
      }

      final String batchBreakdownDesc = salesBreakdown
          .map(
            (s) => 'Batch ${s['batchNumber']}: ${s['stripsDeducted']} strips',
          )
          .join(', ');

      await supabase.from('sales').insert({
        'medicine_name': medicineName,
        'batch_number': firstBatchSold,
        'sale_type': saleType,
        'quantity_sold': qty,
        'unit_price': unitPrice,
        'total_amount': total,
        'customer_name': customer.isEmpty ? null : customer,
        'customer_phone': phone.isEmpty ? null : phone,
        'sold_by': userId,
        'pharmacy_id': PharmacySession.pharmacyId,
      });

      debugPrint('FIFO sale breakdown: $batchBreakdownDesc');

      if (!mounted) return;
      _loadMedicines();
      _loadManufacturers();

      final int totalNewBoxes = salesBreakdown.fold(
        0,
        (s, b) => s + (b['newBoxes'] as int),
      );
      final int totalNewStrips = salesBreakdown.fold(
        0,
        (s, b) => s + (b['newStrips'] as int),
      );
      final int spbForReceipt = salesBreakdown.isNotEmpty
          ? salesBreakdown.first['spb'] as int
          : stripsPerBox;

      _showReceipt(
        medicineName: medicineName,
        batchNumber: firstBatchSold,
        saleType: saleType,
        qty: qty,
        unitPrice: unitPrice,
        total: total,
        customer: customer,
        phone: phone,
        newBoxes: totalNewBoxes,
        newStrips: totalNewStrips,
        spb: spbForReceipt,
        batchesUsed: salesBreakdown.length,
      );
    } catch (e) {
      _error('Sale failed: $e');
    }
  }

  Future<void> _deleteCartonIfEmpty(String cartonId) async {
    try {
      final remaining = await supabase
          .from('medicine_boxes')
          .select('id, quantity')
          .eq('carton_id', cartonId)
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '');

      bool hasStock = false;
      for (final box in List.from(remaining)) {
        if (((box['quantity'] as int?) ?? 0) > 0) {
          hasStock = true;
          break;
        }
      }
      if (!hasStock) {
        await supabase.from('cartons').delete().eq('id', cartonId);
      }
    } catch (e) {
      debugPrint('Carton delete check error: $e');
    }
  }

  // ── RECEIPT ───────────────────────────────────────────────

  void _showReceipt({
    required String medicineName,
    required String batchNumber,
    required String saleType,
    required int qty,
    required double unitPrice,
    required double total,
    required String customer,
    required String phone,
    required int newBoxes,
    required int newStrips,
    required int spb,
    int batchesUsed = 1,
  }) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hour = now.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final timeStr =
        '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $period';

    final int partialStrips = (spb > 0) ? (newStrips % spb) : 0;
    final bool hasPartialBox = newBoxes > 0 && partialStrips != 0;
    final bool isLowStockAfterSale = newBoxes > 0 && newBoxes <= 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text(
              'Sale Receipt',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_pharmacy_rounded,
                color: Colors.blueAccent,
                size: 36,
              ),
              const SizedBox(height: 6),
              Text(
                PharmacySession.pharmacyName ?? 'GuardianPharma',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                '$dateStr  •  $timeStr',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (customer.isNotEmpty)
                Text(
                  'Customer: $customer',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              if (phone.isNotEmpty)
                Text(
                  '📱 $phone',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              _infoRow('💊 Medicine', medicineName),
              _infoRow('🔢 Batch (primary)', batchNumber),
              if (batchesUsed > 1)
                _infoRow('🔄 Batches used (FIFO)', '$batchesUsed batches'),
              _infoRow('📦 Type', saleType.toUpperCase()),
              _infoRow('🔢 Quantity Sold', '$qty'),
              _infoRow('💰 Unit Price', 'BDT ${unitPrice.toStringAsFixed(2)}'),
              const Divider(color: Colors.white24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'BDT ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: newBoxes == 0
                      ? const Color.fromRGBO(255, 82, 82, 0.12)
                      : isLowStockAfterSale
                      ? const Color.fromRGBO(255, 152, 0, 0.12)
                      : const Color.fromRGBO(76, 175, 80, 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: newBoxes == 0
                        ? const Color.fromRGBO(255, 82, 82, 0.4)
                        : isLowStockAfterSale
                        ? const Color.fromRGBO(255, 152, 0, 0.4)
                        : const Color.fromRGBO(76, 175, 80, 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '📦 Remaining Stock',
                      style: TextStyle(
                        color: newBoxes == 0
                            ? Colors.redAccent
                            : isLowStockAfterSale
                            ? Colors.orange
                            : Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$newBoxes boxes',
                          style: TextStyle(
                            color: newBoxes == 0
                                ? Colors.redAccent
                                : isLowStockAfterSale
                                ? Colors.orange
                                : Colors.greenAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.medication,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$newStrips strips remaining',
                          style: TextStyle(
                            color: newStrips == 0
                                ? Colors.redAccent
                                : newStrips <= (spb * 2)
                                ? Colors.orange
                                : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (hasPartialBox) ...[
                      const SizedBox(height: 4),
                      Text(
                        '(1 partially used box — $partialStrips strips left in it)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (newBoxes == 0) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '⚠️ OUT OF STOCK',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else if (isLowStockAfterSale) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '⚠️ LOW STOCK — Only ≤5 boxes left! Reorder soon.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '✅ Sale saved & inventory updated!',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Done', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── ADD / EDIT MEDICINE BOX ───────────────────────────────

  void _showMedicineBoxDialog(
    String cartonId,
    String manufacturerName, {
    Map<String, dynamic>? existing,
  }) {
    final nameCtrl = TextEditingController(
      text: existing?['medicine_name'] ?? '',
    );
    final genericCtrl = TextEditingController(
      text: existing?['generic_name'] ?? '',
    );
    final batchCtrl = TextEditingController(
      text: existing?['batch_number'] ?? '',
    );
    final expiryCtrl = TextEditingController(
      text: existing?['expiry_date'] ?? '',
    );
    final qtyCtrl = TextEditingController(
      text: existing?['quantity']?.toString() ?? '',
    );
    final priceCtrl = TextEditingController(
      text: existing?['price']?.toString() ?? '',
    );
    final stripsCtrl = TextEditingController(
      text: existing?['strips_per_box']?.toString() ?? '10',
    );
    final stripPriceCtrl = TextEditingController(
      text: existing?['price_per_strip']?.toString() ?? '',
    );
    final customUnitCtrl = TextEditingController();
    final shelfNumCtrl = TextEditingController(
      text: existing?['shelf_number']?.toString() ?? '',
    );

    String? selectedShelfSide = existing?['shelf_side']?.toString();
    String selectedUnit = existing?['unit'] ?? 'Tablets';
    bool isCustomUnit = !_units.contains(selectedUnit);
    if (isCustomUnit) {
      customUnitCtrl.text = selectedUnit;
      selectedUnit = 'Custom';
    }

    final bool isEditing = existing != null;
    final String existingId = existing?['id']?.toString() ?? '';

    bool isScanning = false;
    String scanStatusMessage = '';
    bool scanSuccess = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) {
          Future<void> handleBarcodeScan() async {
            setDs(() {
              isScanning = true;
              scanStatusMessage = '';
            });

            final String? scanned = await _scanBarcodeCamera();

            if (scanned == null || scanned.isEmpty) {
              setDs(() {
                isScanning = false;
                scanStatusMessage = '';
              });
              return;
            }

            final Map<String, dynamic>? found = await _lookupMedicineByBarcode(
              scanned,
            );

            if (found != null) {
              setDs(() {
                isScanning = false;
                scanSuccess = true;
                scanStatusMessage =
                    '✅ Medicine found! Fields auto-filled. You can still edit them.';

                if ((found['medicine_name'] ?? '').toString().isNotEmpty)
                  nameCtrl.text = found['medicine_name'].toString();
                if ((found['generic_name'] ?? '').toString().isNotEmpty)
                  genericCtrl.text = found['generic_name'].toString();
                if ((found['batch_number'] ?? '').toString().isNotEmpty)
                  batchCtrl.text = found['batch_number'].toString();
                if ((found['expiry_date'] ?? '').toString().isNotEmpty)
                  expiryCtrl.text = found['expiry_date'].toString();
                if ((found['price'] ?? '').toString().isNotEmpty)
                  priceCtrl.text = found['price'].toString();
                if ((found['strips_per_box'] ?? '').toString().isNotEmpty)
                  stripsCtrl.text = found['strips_per_box'].toString();
                if ((found['price_per_strip'] ?? '').toString().isNotEmpty)
                  stripPriceCtrl.text = found['price_per_strip'].toString();
                final String foundUnit = found['unit']?.toString() ?? '';
                if (foundUnit.isNotEmpty && _units.contains(foundUnit)) {
                  selectedUnit = foundUnit;
                  isCustomUnit = false;
                }
              });
            } else {
              setDs(() {
                isScanning = false;
                scanSuccess = false;
                scanStatusMessage =
                    '⚠️ No medicine found for this barcode.\nPlease enter details manually below.';
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Row(
              children: [
                const Icon(Icons.medication, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Medicine Box' : 'Add Medicine Box',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(105, 240, 174, 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.business,
                          color: Colors.greenAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          manufacturerName,
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isScanning ? null : handleBarcodeScan,
                          icon: isScanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.white,
                                  size: 20,
                                ),
                          label: Text(
                            isScanning ? 'Scanning...' : '📷 Scan Barcode',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (scanStatusMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scanSuccess
                            ? const Color.fromRGBO(76, 175, 80, 0.12)
                            : const Color.fromRGBO(255, 152, 0, 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: scanSuccess
                              ? const Color.fromRGBO(76, 175, 80, 0.4)
                              : const Color.fromRGBO(255, 152, 0, 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            scanSuccess
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            color: scanSuccess
                                ? Colors.greenAccent
                                : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              scanStatusMessage,
                              style: TextStyle(
                                color: scanSuccess
                                    ? Colors.greenAccent
                                    : Colors.orange,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'or enter manually',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _dialogField(nameCtrl, 'Medicine Name *', Icons.medication),
                  const SizedBox(height: 10),
                  _dialogField(
                    genericCtrl,
                    'Generic Name (e.g. Paracetamol)',
                    Icons.science_outlined,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(batchCtrl, 'Batch Number *', Icons.numbers),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expiryCtrl,
                    readOnly: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                      ),
                      hintText: 'Expiry Date *',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 30),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDs(() {
                          expiryCtrl.text =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _dialogField(
                    qtyCtrl,
                    'Quantity (boxes) *',
                    Icons.inventory,
                    isNumber: true,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(
                    stripsCtrl,
                    'Strips per Box',
                    Icons.view_module,
                    isNumber: true,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(
                    priceCtrl,
                    'Price per Box (BDT) *',
                    Icons.attach_money,
                    isDecimal: true,
                  ),
                  const SizedBox(height: 10),
                  _dialogField(
                    stripPriceCtrl,
                    'Price per Strip (BDT)',
                    Icons.money,
                    isDecimal: true,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButton<String>(
                      value: selectedUnit,
                      dropdownColor: const Color(0xFF1A1A2E),
                      underline: const SizedBox(),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white54,
                      ),
                      items: _units
                          .map(
                            (u) => DropdownMenuItem(
                              value: u,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.category,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    u,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDs(() {
                        selectedUnit = v ?? selectedUnit;
                        isCustomUnit = selectedUnit == 'Custom';
                      }),
                    ),
                  ),
                  if (isCustomUnit) ...[
                    const SizedBox(height: 10),
                    _dialogField(customUnitCtrl, 'Custom Unit', Icons.edit),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(179, 136, 255, 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color.fromRGBO(179, 136, 255, 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.shelves,
                              color: Colors.purpleAccent,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Shelf Location (optional)',
                              style: TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _dialogField(
                          shelfNumCtrl,
                          'Shelf Number (e.g. A1, B2)',
                          Icons.tag,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButton<String>(
                            value: selectedShelfSide,
                            dropdownColor: const Color(0xFF1A1A2E),
                            underline: const SizedBox(),
                            isExpanded: true,
                            hint: const Text(
                              'Shelf Side (optional)',
                              style: TextStyle(color: Colors.white38),
                            ),
                            style: const TextStyle(color: Colors.white),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white54,
                            ),
                            items: _shelfSides
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.align_horizontal_center,
                                          color: Colors.white70,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          s,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDs(() => selectedShelfSide = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final batch = batchCtrl.text.trim();
                  final expiry = expiryCtrl.text.trim();
                  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  final strips = int.tryParse(stripsCtrl.text.trim()) ?? 10;
                  final stripPrice = double.tryParse(
                    stripPriceCtrl.text.trim(),
                  );
                  final unit = isCustomUnit
                      ? customUnitCtrl.text.trim()
                      : selectedUnit;
                  final shelfNum = shelfNumCtrl.text.trim();
                  final int initialStrips = qty * strips;

                  if (name.isEmpty || batch.isEmpty || expiry.isEmpty) {
                    _error('Fill all required fields (*)');
                    return;
                  }

                  try {
                    if (isEditing) {
                      await supabase
                          .from('medicine_boxes')
                          .update({
                            'medicine_name': name,
                            'generic_name': genericCtrl.text.trim().isEmpty
                                ? null
                                : genericCtrl.text.trim(),
                            'batch_number': batch,
                            'expiry_date': expiry,
                            'quantity': qty,
                            'strips_per_box': strips,
                            'strips_remaining': initialStrips,
                            'unit': unit,
                            'price': price,
                            'price_per_strip': stripPrice,
                            'shelf_number': shelfNum.isEmpty ? null : shelfNum,
                            'shelf_side': selectedShelfSide,
                          })
                          .eq('id', existingId);
                      _success('Medicine box updated!');
                    } else {
                      await supabase.from('medicine_boxes').insert({
                        'carton_id': cartonId,
                        'medicine_name': name,
                        'generic_name': genericCtrl.text.trim().isEmpty
                            ? null
                            : genericCtrl.text.trim(),
                        'batch_number': batch,
                        'expiry_date': expiry,
                        'quantity': qty,
                        'strips_per_box': strips,
                        'strips_remaining': initialStrips,
                        'unit': unit,
                        'price': price,
                        'price_per_strip': stripPrice,
                        'shelf_number': shelfNum.isEmpty ? null : shelfNum,
                        'shelf_side': selectedShelfSide,
                        'created_by': supabase.auth.currentUser?.id,
                        'pharmacy_id': PharmacySession.pharmacyId,
                      });
                      _success('Medicine box added!');
                    }
                    if (mounted) Navigator.pop(context);
                    _loadMedicines();
                  } catch (e) {
                    _error('Error: $e');
                  }
                },
                child: Text(
                  isEditing ? 'Update' : 'Add',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── ADD / EDIT MANUFACTURER ───────────────────────────────

  void _showManufacturerDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final countryCtrl = TextEditingController(text: existing?['country'] ?? '');
    final cartonNumCtrl = TextEditingController(text: '1');
    final boxesPerCartonCtrl = TextEditingController(text: '50');
    final bool isEditing = existing != null;
    final String existingId = existing?['id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          isEditing ? 'Edit Manufacturer' : 'Add Manufacturer',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, 'Manufacturer Name *', Icons.business),
              const SizedBox(height: 10),
              _dialogField(countryCtrl, 'Country', Icons.flag),
              if (!isEditing) ...[
                const SizedBox(height: 10),
                _dialogField(
                  cartonNumCtrl,
                  'Number of Cartons',
                  Icons.widgets,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  boxesPerCartonCtrl,
                  'Boxes per Carton (default 50)',
                  Icons.inventory_2,
                  isNumber: true,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(68, 138, 255, 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color.fromRGBO(68, 138, 255, 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blueAccent,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Total boxes = Boxes per Carton × Number of Cartons',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                _error('Manufacturer name required');
                return;
              }
              try {
                if (isEditing) {
                  await supabase
                      .from('manufacturers')
                      .update({
                        'name': name,
                        'country': countryCtrl.text.trim().isEmpty
                            ? null
                            : countryCtrl.text.trim(),
                      })
                      .eq('id', existingId);
                  _success('Manufacturer updated!');
                } else {
                  final cartonNum = int.tryParse(cartonNumCtrl.text) ?? 1;
                  final boxesPerCarton =
                      int.tryParse(boxesPerCartonCtrl.text) ?? 50;

                  final mfrRes = await supabase
                      .from('manufacturers')
                      .insert({
                        'name': name,
                        'country': countryCtrl.text.trim().isEmpty
                            ? null
                            : countryCtrl.text.trim(),
                      })
                      .select()
                      .single();

                  await supabase.from('cartons').insert({
                    'manufacturer_id': mfrRes['id'],
                    'carton_number': cartonNum,
                    'boxes_per_carton': boxesPerCarton,
                    'received_date': DateTime.now().toIso8601String().split(
                      'T',
                    )[0],
                    'created_by': supabase.auth.currentUser?.id,
                  });

                  _success(
                    'Manufacturer added! $cartonNum × $boxesPerCarton = ${cartonNum * boxesPerCarton} total boxes',
                  );
                }
                if (mounted) Navigator.pop(context);
                _loadManufacturers();
              } catch (e) {
                _error('Error: $e');
              }
            },
            child: Text(
              isEditing ? 'Update' : 'Add',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── VIEW MEDICINE BOXES ───────────────────────────────────

  void _viewMedicineBoxes(
    String manufacturerId,
    String manufacturerName,
  ) async {
    try {
      final cartonsRes = await supabase
          .from('cartons')
          .select()
          .eq('manufacturer_id', manufacturerId)
          .order('received_date', ascending: false);

      final List<Map<String, dynamic>> cartonList =
          List<Map<String, dynamic>>.from(cartonsRes);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A1A2E),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => StatefulBuilder(
          builder: (ctx, setSheet) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🏭 $manufacturerName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${cartonList.length} carton(s)',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddCartonDialog(
                            manufacturerId,
                            manufacturerName,
                          );
                        },
                        icon: const Icon(
                          Icons.add_box,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          'New Carton',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                cartonList.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: Text(
                            'No cartons found',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: cartonList.length,
                          itemBuilder: (_, ci) {
                            final carton = cartonList[ci];
                            final int displayNum = ci + 1;
                            return _buildCartonCard(
                              carton: carton,
                              displayNumber: displayNum,
                              manufacturerName: manufacturerName,
                              manufacturerId: manufacturerId,
                              onDeleted: () {
                                Navigator.pop(context);
                                _viewMedicineBoxes(
                                  manufacturerId,
                                  manufacturerName,
                                );
                              },
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _error('Error: $e');
    }
  }

  // ── CARTON CARD ───────────────────────────────────────────

  Widget _buildCartonCard({
    required Map<String, dynamic> carton,
    required int displayNumber,
    required String manufacturerName,
    required String manufacturerId,
    required VoidCallback onDeleted,
  }) {
    final String cartonId = carton['id'];
    final String receivedDate = carton['received_date']?.toString() ?? 'N/A';
    final String? cartonLabel = carton['carton_label']?.toString();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('medicine_boxes')
          .select()
          .eq('carton_id', cartonId)
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .order('expiry_date')
          .then((r) => List<Map<String, dynamic>>.from(r)),
      builder: (ctx, snapshot) {
        final List<Map<String, dynamic>> boxes = snapshot.data ?? [];

        int totalBoxes = 0;
        for (final box in boxes) {
          totalBoxes += (box['quantity'] as int?) ?? 0;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color.fromRGBO(68, 138, 255, 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(68, 138, 255, 0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.widgets,
                          color: Colors.blueAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cartonLabel ?? 'Carton #$displayNumber',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white54,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Received: $receivedDate',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditCartonDialog(
                              carton: carton,
                              displayNumber: displayNumber,
                              manufacturerId: manufacturerId,
                              manufacturerName: manufacturerName,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteCartonDialog(
                              cartonId: cartonId,
                              displayNumber: displayNumber,
                              manufacturerId: manufacturerId,
                              manufacturerName: manufacturerName,
                              onDeleted: onDeleted,
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showMedicineBoxDialog(cartonId, manufacturerName);
                          },
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 14,
                          ),
                          label: const Text(
                            'Add Box',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _cartonStat(
                          '📦 Boxes',
                          '$totalBoxes',
                          color: Colors.greenAccent,
                        ),
                        _cartonStat('💊 Medicines', '${boxes.length}'),
                      ],
                    ),
                  ],
                ),
              ),
              if (boxes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No medicine boxes added to this carton yet',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              else
                ...boxes.map((box) {
                  final expiry = DateTime.tryParse(box['expiry_date'] ?? '');
                  final daysLeft = expiry?.difference(DateTime.now()).inDays;
                  final bool isExpired = daysLeft != null && daysLeft < 0;
                  final bool isExpiringSoon =
                      daysLeft != null && daysLeft <= 30 && daysLeft >= 0;
                  final int qty = (box['quantity'] as int?) ?? 0;
                  final int spb = (box['strips_per_box'] as int?) ?? 10;
                  final int stripsRem =
                      (box['strips_remaining'] as int?) ?? (qty * spb);
                  final String batchNum =
                      box['batch_number']?.toString() ?? 'N/A';
                  final String shelfNum = box['shelf_number']?.toString() ?? '';
                  final String shelfSide = box['shelf_side']?.toString() ?? '';

                  final int fullBoxStrips = qty * spb;
                  final bool hasPartial = qty > 0 && stripsRem < fullBoxStrips;
                  final int partialLeft = (spb > 0)
                      ? (stripsRem % spb == 0 ? spb : stripsRem % spb)
                      : 0;

                  final bool isBatchLowStock = qty > 0 && qty <= 5;

                  return Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? const Color.fromRGBO(244, 67, 54, 0.1)
                          : isExpiringSoon
                          ? const Color.fromRGBO(255, 152, 0, 0.1)
                          : const Color.fromRGBO(255, 255, 255, 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isExpired
                            ? const Color.fromRGBO(255, 82, 82, 0.3)
                            : isExpiringSoon
                            ? const Color.fromRGBO(255, 152, 0, 0.3)
                            : const Color.fromRGBO(255, 255, 255, 0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    box['medicine_name'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if ((box['generic_name'] ?? '').isNotEmpty)
                                    Text(
                                      '🧬 ${box['generic_name']}',
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 11,
                                      ),
                                    ),
                                  Text(
                                    '🔢 Batch: $batchNum',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueAccent,
                                size: 16,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _showMedicineBoxDialog(
                                  cartonId,
                                  manufacturerName,
                                  existing: box,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              onPressed: () async {
                                try {
                                  await supabase
                                      .from('medicine_boxes')
                                      .delete()
                                      .eq('id', box['id']);
                                  await _deleteCartonIfEmpty(cartonId);
                                  _success('Medicine deleted!');
                                  _loadMedicines();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _viewMedicineBoxes(
                                      manufacturerId,
                                      manufacturerName,
                                    );
                                  }
                                } catch (e) {
                                  _error('Delete failed: $e');
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (isBatchLowStock && !isExpired)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(255, 152, 0, 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color.fromRGBO(255, 152, 0, 0.5),
                              ),
                            ),
                            child: const Text(
                              '⚠️ LOW STOCK — ≤5 boxes remaining!',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '📦 $qty boxes',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '💊 $spb strips/box',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '🔢 $stripsRem strips left',
                                    style: TextStyle(
                                      color: stripsRem == 0
                                          ? Colors.redAccent
                                          : Colors.greenAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (hasPartial) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '⚠️ Partial box: $partialLeft strips in current box',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (shelfNum.isNotEmpty || shelfSide.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.shelves,
                                color: Colors.purpleAccent,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              if (shelfNum.isNotEmpty)
                                Text(
                                  'Shelf: $shelfNum',
                                  style: const TextStyle(
                                    color: Colors.purpleAccent,
                                    fontSize: 11,
                                  ),
                                ),
                              if (shelfNum.isNotEmpty && shelfSide.isNotEmpty)
                                const Text(
                                  ' | ',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              if (shelfSide.isNotEmpty)
                                Text(
                                  'Side: $shelfSide',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          isExpired
                              ? '⛔ EXPIRED'
                              : isExpiringSoon
                              ? '⚠️ Expires in $daysLeft days'
                              : '✅ Expires: ${box['expiry_date']}',
                          style: TextStyle(
                            color: isExpired
                                ? Colors.redAccent
                                : isExpiringSoon
                                ? Colors.orange
                                : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // ── EDIT CARTON DIALOG ────────────────────────────────────

  void _showEditCartonDialog({
    required Map<String, dynamic> carton,
    required int displayNumber,
    required String manufacturerId,
    required String manufacturerName,
  }) {
    final String cartonId = carton['id'];
    final labelCtrl = TextEditingController(
      text: carton['carton_label']?.toString() ?? '',
    );
    final boxesCtrl = TextEditingController(
      text: carton['boxes_per_carton']?.toString() ?? '50',
    );
    DateTime receivedDate =
        DateTime.tryParse(carton['received_date']?.toString() ?? '') ??
        DateTime.now();
    final receivedCtrl = TextEditingController(
      text:
          carton['received_date']?.toString() ??
          DateTime.now().toIso8601String().split('T')[0],
    );

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text(
                    'Edit Carton',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Carton #$displayNumber',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  labelCtrl,
                  'Carton Label (optional)',
                  Icons.label_outline,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  boxesCtrl,
                  'Boxes per Carton',
                  Icons.inventory_2,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: receivedCtrl,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                    ),
                    hintText: 'Date Received',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: receivedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDs(() {
                        receivedDate = picked;
                        receivedCtrl.text =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () async {
                final label = labelCtrl.text.trim();
                final boxesPerCarton =
                    int.tryParse(boxesCtrl.text.trim()) ?? 50;
                try {
                  await supabase
                      .from('cartons')
                      .update({
                        'carton_label': label.isEmpty ? null : label,
                        'boxes_per_carton': boxesPerCarton,
                        'received_date': receivedCtrl.text.trim(),
                      })
                      .eq('id', cartonId);
                  _success('Carton updated!');
                  if (mounted) Navigator.pop(context);
                  _viewMedicineBoxes(manufacturerId, manufacturerName);
                } catch (e) {
                  _error('Update failed: $e');
                }
              },
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── DELETE CARTON DIALOG ──────────────────────────────────

  void _showDeleteCartonDialog({
    required String cartonId,
    required int displayNumber,
    required String manufacturerId,
    required String manufacturerName,
    required VoidCallback onDeleted,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Delete Carton',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Carton #$displayNumber?\n\nThis will also delete ALL medicine boxes inside this carton.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                await supabase
                    .from('medicine_boxes')
                    .delete()
                    .eq('carton_id', cartonId);
                await supabase.from('cartons').delete().eq('id', cartonId);
                _success('Carton #$displayNumber deleted!');
                _loadMedicines();
                _loadManufacturers();
                if (context.mounted) {
                  Navigator.pop(context);
                  _viewMedicineBoxes(manufacturerId, manufacturerName);
                }
              } catch (e) {
                _error('Delete failed: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── ADD NEW CARTON DIALOG ─────────────────────────────────

  void _showAddCartonDialog(String manufacturerId, String manufacturerName) {
    final cartonLabelCtrl = TextEditingController();
    final howManyCtrl = TextEditingController(text: '1');
    final boxesPerCartonCtrl = TextEditingController(text: '50');
    DateTime receivedDate = DateTime.now();
    final receivedCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().split('T')[0],
    );

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_box, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Add New Carton',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '🏭 $manufacturerName',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  cartonLabelCtrl,
                  'Carton Label (e.g. "Batch Jan 2025")',
                  Icons.label_outline,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  howManyCtrl,
                  'How many cartons to add',
                  Icons.widgets,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  boxesPerCartonCtrl,
                  'Boxes per Carton',
                  Icons.inventory_2,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: receivedCtrl,
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                    ),
                    hintText: 'Date Received *',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: receivedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDs(() {
                        receivedDate = picked;
                        receivedCtrl.text =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 152, 0, 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 152, 0, 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'New cartons will continue numbering from the highest existing carton number.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              icon: const Icon(Icons.add, color: Colors.white, size: 16),
              label: const Text(
                'Add Carton',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                final int howMany = int.tryParse(howManyCtrl.text.trim()) ?? 1;
                final int boxesPerCarton =
                    int.tryParse(boxesPerCartonCtrl.text.trim()) ?? 50;
                final String label = cartonLabelCtrl.text.trim();

                try {
                  final existingCartons = await supabase
                      .from('cartons')
                      .select('carton_number')
                      .eq('manufacturer_id', manufacturerId);

                  int maxExisting = 0;
                  for (final row in List.from(existingCartons)) {
                    final int num = (row['carton_number'] as int?) ?? 0;
                    if (num > maxExisting) maxExisting = num;
                  }

                  for (int i = 1; i <= howMany; i++) {
                    final int newCartonNumber = maxExisting + i;
                    await supabase.from('cartons').insert({
                      'manufacturer_id': manufacturerId,
                      'carton_number': newCartonNumber,
                      'boxes_per_carton': boxesPerCarton,
                      'received_date': receivedCtrl.text.trim(),
                      'carton_label': label.isEmpty ? null : label,
                      'created_by': supabase.auth.currentUser?.id,
                    });
                  }

                  _success(
                    '$howMany carton(s) added! Numbers: ${maxExisting + 1} to ${maxExisting + howMany}',
                  );
                  if (mounted) Navigator.pop(context);
                  _viewMedicineBoxes(manufacturerId, manufacturerName);
                } catch (e) {
                  _error('Error: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── SUBSTITUTE SEARCH ─────────────────────────────────────

  Future<void> _searchSubstitutes() async {
    final tradeName = _substituteSearchCtrl.text.trim();
    if (tradeName.isEmpty) {
      _error('Please enter a medicine name to search');
      return;
    }

    setState(() {
      _searchingSubstitute = true;
      _substitutedSearched = false;
      _searchedMedicine = null;
      _substituteResults = [];
      _resolvedGeneric = '';
      _substituteError = '';
    });

    try {
      final searchRes = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .ilike('medicine_name', '%$tradeName%')
          .order('medicine_name')
          .limit(1);

      final List<Map<String, dynamic>> found = List<Map<String, dynamic>>.from(
        searchRes,
      );

      if (found.isEmpty) {
        setState(() {
          _searchingSubstitute = false;
          _substitutedSearched = true;
          _substituteError =
              'No medicine found with name "$tradeName" in this pharmacy.\n\nMake sure the medicine is added to inventory.';
        });
        return;
      }

      final Map<String, dynamic> sourceMed = found.first;
      final String? genericName = sourceMed['generic_name']?.toString();

      if (genericName == null || genericName.trim().isEmpty) {
        setState(() {
          _searchedMedicine = sourceMed;
          _searchingSubstitute = false;
          _substitutedSearched = true;
          _substituteError =
              'The medicine "${sourceMed['medicine_name']}" has no generic name recorded.\n\nGo to Inventory → tap a manufacturer → edit this medicine → add its generic name (e.g. Paracetamol).';
        });
        return;
      }

      final subRes = await supabase
          .from('medicine_boxes')
          .select('*, cartons(*, manufacturers(name, country))')
          .eq('pharmacy_id', PharmacySession.pharmacyId ?? '')
          .ilike('generic_name', '%${genericName.trim()}%')
          .neq('id', sourceMed['id'])
          .order('medicine_name');

      setState(() {
        _searchedMedicine = sourceMed;
        _resolvedGeneric = genericName.trim();
        _substituteResults = List<Map<String, dynamic>>.from(subRes);
        _searchingSubstitute = false;
        _substitutedSearched = true;
      });
    } catch (e) {
      setState(() {
        _searchingSubstitute = false;
        _substitutedSearched = true;
        _substituteError = 'Search failed. Please try again.\n$e';
      });
    }
  }

  // ── HELPER WIDGETS ────────────────────────────────────────

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saleTypeChip(
    String value,
    String label,
    String selected,
    Function(String) onTap,
  ) {
    final bool isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent
              : const Color.fromRGBO(255, 255, 255, 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent
                : const Color.fromRGBO(255, 255, 255, 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumber = false,
    bool isDecimal = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType:
          keyboardType ??
          (isDecimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : isNumber
              ? TextInputType.number
              : TextInputType.text),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _cartonStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _error(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _success(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/guardianpharmapills.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.45)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(
                        Icons.local_pharmacy,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sell Medicine & Inventory',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              PharmacySession.pharmacyName ?? '',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () {
                          _loadMedicines();
                          _loadManufacturers();
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontSize: 11),
                    tabs: const [
                      Tab(text: '💊 Sell'),
                      Tab(text: '📦 Inventory'),
                      Tab(text: '🔍 Substitute'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSellTab(),
                      _buildInventoryTab(),
                      _buildSubstituteTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              heroTag: 'addManufacturer',
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Manufacturer',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: _showManufacturerDialog,
            )
          : null,
    );
  }

  // ── TAB 1: SELL ───────────────────────────────────────────

  Widget _buildSellTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    hintText: 'Search name, generic...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  onPressed: () async {
                    final String? scanned = await _scanBarcodeCamera();
                    if (scanned != null && scanned.isNotEmpty) {
                      searchController.text = scanned;
                      _filterGrouped();
                    }
                  },
                  tooltip: 'Scan Barcode',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: loadingMedicines
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                )
              : filteredGrouped.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.medication_outlined,
                        color: Colors.white24,
                        size: 60,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        searchController.text.isEmpty
                            ? 'No medicines in stock'
                            : 'No results for "${searchController.text}"',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredGrouped.length,
                  itemBuilder: (_, i) {
                    final m = filteredGrouped[i];
                    final int totalBoxes = (m['total_boxes'] as int?) ?? 0;
                    final int totalStrips = (m['total_strips'] as int?) ?? 0;
                    final List<Map<String, dynamic>> batches =
                        List<Map<String, dynamic>>.from(m['batches'] ?? []);
                    final String? earliestExpiry = m['earliest_expiry']
                        ?.toString();
                    final Color expColor = _expiryColor(earliestExpiry);
                    final String mfrName =
                        m['cartons']?['manufacturers']?['name']?.toString() ??
                        'Unknown';

                    final bool isLowStock = totalBoxes > 0 && totalBoxes <= 5;
                    final bool outOfStock = totalBoxes <= 0;

                    final int activeBatches = batches
                        .where((b) => !_isExpired(b['expiry_date']?.toString()))
                        .length;

                    return Card(
                      color: outOfStock
                          ? const Color.fromRGBO(100, 100, 100, 0.15)
                          : const Color.fromRGBO(255, 255, 255, 0.10),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => _showSellDialog(m),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: expColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    radius: 20,
                                    child: Icon(
                                      Icons.medication,
                                      color: expColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m['medicine_name'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if ((m['generic_name']?.toString() ??
                                                '')
                                            .isNotEmpty)
                                          Text(
                                            m['generic_name'],
                                            style: const TextStyle(
                                              color: Colors.blueAccent,
                                              fontSize: 12,
                                            ),
                                          ),
                                        Text(
                                          '🔄 $activeBatches active batch(es)',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (outOfStock)
                                    const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.grey,
                                    )
                                  else
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white54,
                                      size: 14,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (isLowStock)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(
                                      255,
                                      152,
                                      0,
                                      0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color.fromRGBO(
                                        255,
                                        152,
                                        0,
                                        0.5,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber,
                                        color: Colors.orange,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '⚠️ LOW STOCK — Reorder soon!',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _badge(
                                    '📦 $totalBoxes boxes total',
                                    totalBoxes > 0
                                        ? Colors.blueAccent
                                        : Colors.grey,
                                  ),
                                  _badge(
                                    '💊 $totalStrips strips total',
                                    totalBoxes > 0
                                        ? Colors.greenAccent
                                        : Colors.grey,
                                  ),
                                  _badge(
                                    _expiryLabel(earliestExpiry),
                                    expColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🏭 $mfrName  |  BDT ${m['price']}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                              if (outOfStock) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(
                                      150,
                                      150,
                                      150,
                                      0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    '❌ OUT OF STOCK — Tap to see options',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── TAB 2: INVENTORY ──────────────────────────────────────

  Widget _buildInventoryTab() {
    return loadingManufacturers
        ? const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          )
        : manufacturers.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined, color: Colors.white24, size: 60),
                SizedBox(height: 12),
                Text(
                  'No manufacturers yet',
                  style: TextStyle(color: Colors.white54),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button below to add one',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: manufacturers.length,
            itemBuilder: (_, i) {
              final m = manufacturers[i];
              return Card(
                color: const Color.fromRGBO(255, 255, 255, 0.10),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.business, color: Colors.white),
                  ),
                  title: Text(
                    m['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    m['country'] ?? 'Country N/A',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        onPressed: () => _showManufacturerDialog(existing: m),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () async {
                          await supabase
                              .from('manufacturers')
                              .delete()
                              .eq('id', m['id']);
                          _loadManufacturers();
                          _success('Deleted!');
                        },
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                  onTap: () => _viewMedicineBoxes(m['id'], m['name']),
                ),
              );
            },
          );
  }

  // ── TAB 3: SUBSTITUTE ─────────────────────────────────────

  Widget _buildSubstituteTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(156, 39, 176, 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color.fromRGBO(156, 39, 176, 0.3),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.swap_horiz, color: Colors.purple, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'How it works:',
                          style: TextStyle(
                            color: Colors.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '1. Type or scan the trade name (e.g. "Napa")\n2. App finds its generic (Paracetamol)\n3. All medicines with same generic shown',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _substituteSearchCtrl,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _searchSubstitutes(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.medication,
                          color: Colors.white70,
                        ),
                        hintText: 'Type trade name (e.g. Napa, Ace)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: _substituteSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.white38,
                                ),
                                onPressed: () {
                                  _substituteSearchCtrl.clear();
                                  setState(() {
                                    _searchedMedicine = null;
                                    _substituteResults = [];
                                    _substitutedSearched = false;
                                    _substituteError = '';
                                    _resolvedGeneric = '';
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                      ),
                      tooltip: 'Scan barcode to find substitute',
                      onPressed: _searchingSubstitute
                          ? null
                          : () async {
                              final String? scanned =
                                  await _scanBarcodeCamera();
                              if (scanned == null || scanned.isEmpty) return;
                              setState(() => _searchingSubstitute = true);
                              final Map<String, dynamic>? found =
                                  await _lookupMedicineByBarcode(scanned);
                              if (!mounted) return;
                              if (found == null) {
                                setState(() => _searchingSubstitute = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No medicine found for this barcode.',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              final String medicineName =
                                  found['medicine_name']?.toString() ?? '';
                              if (medicineName.isEmpty) {
                                setState(() => _searchingSubstitute = false);
                                _error(
                                  'No medicine name found for this barcode.',
                                );
                                return;
                              }
                              setState(() {
                                _substituteSearchCtrl.text = medicineName;
                                _searchingSubstitute = false;
                              });
                              _searchSubstitutes();
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: _searchingSubstitute
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search, color: Colors.white),
                      onPressed: _searchingSubstitute
                          ? null
                          : _searchSubstitutes,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: !_substitutedSearched
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz, color: Colors.white24, size: 64),
                      SizedBox(height: 12),
                      Text(
                        'Find Substitutes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Type or scan a medicine barcode above to find substitutes with the same generic ingredient',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : _substituteError.isNotEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 82, 82, 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color.fromRGBO(255, 82, 82, 0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.redAccent,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _substituteError,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_searchedMedicine != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(68, 138, 255, 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color.fromRGBO(68, 138, 255, 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.science_outlined,
                                color: Colors.blueAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 13),
                                    children: [
                                      const TextSpan(
                                        text: 'Generic resolved: ',
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                      TextSpan(
                                        text: _resolvedGeneric,
                                        style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '🔍 You searched for:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildMedicineCard(_searchedMedicine!, isSource: true),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.swap_horiz,
                              color: Colors.purple,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _substituteResults.isEmpty
                                  ? 'No substitutes found'
                                  : '${_substituteResults.length} substitute(s):',
                              style: TextStyle(
                                color: _substituteResults.isEmpty
                                    ? Colors.orange
                                    : Colors.purple,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_substituteResults.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(255, 152, 0, 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color.fromRGBO(255, 152, 0, 0.3),
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange,
                                  size: 36,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No other medicines with the same generic name available.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._substituteResults.map(
                            (m) => _buildMedicineCard(m, isSource: false),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> m, {required bool isSource}) {
    final int qty = (m['quantity'] as int?) ?? 0;
    final int spb = (m['strips_per_box'] as int?) ?? 10;
    final int stripsRem = (m['strips_remaining'] as int?) ?? (qty * spb);
    final bool expired = _isExpired(m['expiry_date']?.toString());
    final bool canSell = qty > 0 && !expired;
    final Color expColor = _expiryColor(m['expiry_date']?.toString());
    final String mfrName =
        m['cartons']?['manufacturers']?['name']?.toString() ?? 'Unknown';
    final String genericName = m['generic_name']?.toString() ?? '';
    final String batchNum = m['batch_number']?.toString() ?? 'N/A';
    final String shelfNum = m['shelf_number']?.toString() ?? '';
    final String shelfSide = m['shelf_side']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSource
            ? const Color.fromRGBO(68, 138, 255, 0.08)
            : expired
            ? const Color.fromRGBO(244, 67, 54, 0.08)
            : const Color.fromRGBO(156, 39, 176, 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSource
              ? const Color.fromRGBO(68, 138, 255, 0.4)
              : expired
              ? const Color.fromRGBO(255, 82, 82, 0.4)
              : const Color.fromRGBO(156, 39, 176, 0.4),
          width: isSource ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isSource
                      ? const Color.fromRGBO(68, 138, 255, 0.2)
                      : canSell
                      ? const Color.fromRGBO(156, 39, 176, 0.2)
                      : const Color.fromRGBO(244, 67, 54, 0.2),
                  radius: 22,
                  child: Icon(
                    Icons.medication,
                    color: isSource
                        ? Colors.blueAccent
                        : canSell
                        ? Colors.purple
                        : Colors.redAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['medicine_name']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (genericName.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSource
                                ? const Color.fromRGBO(68, 138, 255, 0.15)
                                : const Color.fromRGBO(156, 39, 176, 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSource
                                  ? const Color.fromRGBO(68, 138, 255, 0.4)
                                  : const Color.fromRGBO(156, 39, 176, 0.4),
                            ),
                          ),
                          child: Text(
                            '🧬 $genericName',
                            style: TextStyle(
                              color: isSource
                                  ? Colors.blueAccent
                                  : Colors.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        '🔢 Batch: $batchNum',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isSource)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canSell
                          ? Colors.greenAccent
                          : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: canSell
                        ? () => _showSellDialog({
                            'medicine_name': m['medicine_name'],
                            'generic_name': m['generic_name'],
                            'total_boxes': qty,
                            'total_strips': stripsRem,
                            'batches': [m],
                            'earliest_expiry': m['expiry_date']?.toString(),
                            'cartons': m['cartons'],
                            'price': m['price'],
                          })
                        : null,
                    child: Text(
                      canSell
                          ? 'Sell'
                          : expired
                          ? 'Expired'
                          : 'Out',
                      style: TextStyle(
                        color: canSell ? Colors.black : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.business, color: Colors.blueAccent, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    mfrName,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _badge('📦 $qty boxes', Colors.blueAccent),
                _badge('💊 $stripsRem strips', Colors.tealAccent),
                _badge('💰 BDT ${m['price']}', Colors.greenAccent),
                _badge(_expiryLabel(m['expiry_date']?.toString()), expColor),
                if (shelfNum.isNotEmpty)
                  _badge('🗄️ Shelf $shelfNum', Colors.purpleAccent),
                if (shelfSide.isNotEmpty)
                  _badge('◀ $shelfSide', Colors.cyanAccent),
              ],
            ),
            if (expired) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 82, 82, 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 82, 82, 0.5),
                  ),
                ),
                child: const Text(
                  '⛔ EXPIRED — Cannot be sold',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else if (qty <= 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(150, 150, 150, 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  '❌ OUT OF STOCK',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
