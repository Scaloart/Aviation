import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/nav_log_entry.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class NavLogSpreadsheetScreen extends StatefulWidget {
  const NavLogSpreadsheetScreen({super.key});

  @override
  State<NavLogSpreadsheetScreen> createState() => _NavLogSpreadsheetScreenState();
}

class _NavLogSpreadsheetScreenState extends State<NavLogSpreadsheetScreen> {
  late NavLogDataSource _navLogDataSource;
  List<NavLogEntry> _navLogEntries = <NavLogEntry>[];

  @override
  void initState() {
    super.initState();
    _navLogEntries = _getNavLogData();
    _navLogDataSource = NavLogDataSource(navLogEntries: _navLogEntries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Log de Navigation',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 44, color: Colors.black87),
        ),
      ),
      body: SfDataGrid(
        source: _navLogDataSource,
        allowEditing: true,
        selectionMode: SelectionMode.single,
        navigationMode: GridNavigationMode.cell,
        columnWidthMode: ColumnWidthMode.fill,
        columns: <GridColumn>[
          GridColumn(columnName: 'waypoint', label: const Center(child: Text('Waypoint'))),
          GridColumn(columnName: 'vorRad', label: const Center(child: Text('VOR RAD'))),
          GridColumn(columnName: 'vorDist', label: const Center(child: Text('VOR DIST'))),
          GridColumn(columnName: 'freq', label: const Center(child: Text('FREQ'))),
          GridColumn(columnName: 'dtk', label: const Center(child: Text('DTK'))),
          GridColumn(columnName: 'safeAlt', label: const Center(child: Text('ALT (S)'))),
          GridColumn(columnName: 'distLeg', label: const Center(child: Text('DIST LEG'))),
          GridColumn(columnName: 'distRem', label: const Center(child: Text('DIST REM'))),
          GridColumn(columnName: 'timingEte', label: const Center(child: Text('ETE'))),
          GridColumn(columnName: 'timingAte', label: const Center(child: Text('ATE'))),
          GridColumn(columnName: 'timingEta', label: const Center(child: Text('ETA'))),
          GridColumn(columnName: 'timingAta', label: const Center(child: Text('ATA'))),
          GridColumn(columnName: 'fuelCons', label: const Center(child: Text('CONS'))),
          GridColumn(columnName: 'fuelCumul', label: const Center(child: Text('CUMUL'))),
          GridColumn(columnName: 'ats', label: const Center(child: Text('ATS'))),
        ],
      ),
    );
  }

  List<NavLogEntry> _getNavLogData() {
    return [
      NavLogEntry(
        waypoint: 'START',
        vorRad: '112.5',
        vorDist: '10',
        freq: '118.1',
        dtk: '360',
        safeAlt: '5000',
        distLeg: '100',
        timingEte: '00:30',
        fuelCons: '10.5',
        ats: '120',
      ),
      NavLogEntry(
        waypoint: 'POINT A',
        vorRad: '113.2',
        vorDist: '25',
        freq: '121.5',
        dtk: '090',
        safeAlt: '6000',
        distLeg: '150',
        timingEte: '00:45',
        fuelCons: '10.2',
        ats: '130',
      ),
    ];
  }
}

class NavLogDataSource extends DataGridSource {
  dynamic newCellValue;
  TextEditingController editingController = TextEditingController();

  NavLogDataSource({required List<NavLogEntry> navLogEntries}) {
    _navLogEntries = navLogEntries;
    _updateDataGridRows();
  }

  List<DataGridRow> _dataGridRows = [];
  List<NavLogEntry> _navLogEntries = [];

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
        cells: row.getCells().map<Widget>((e) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8.0),
        child: Text(e.value.toString()),
      );
    }).toList());
  }

  @override
  Widget? buildEditWidget(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column, submitCell) {
    final dynamic oldValue = dataGridRow.getCells()[rowColumnIndex.columnIndex].value ?? '';
    editingController.text = oldValue.toString();
    return Container(
      padding: const EdgeInsets.all(8.0),
      alignment: Alignment.center,
      child: TextField(
        autofocus: true,
        controller: editingController,
        textAlign: TextAlign.center,
        onChanged: (String value) {
          if (value.isNotEmpty) {
            newCellValue = value;
          } else {
            newCellValue = null;
          }
        },
        onSubmitted: (String value) {
          submitCell();
        },
      ),
    );
  }

  @override
  Future<void> onCellSubmit(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column) async {
    final dynamic oldValue = dataGridRow.getCells()[rowColumnIndex.columnIndex].value ?? '';
    final int dataRowIndex = _dataGridRows.indexOf(dataGridRow);

    if (newCellValue == null || oldValue == newCellValue) {
      return;
    }

    final String columnName = column.columnName;
    _navLogEntries[dataRowIndex].updateField(columnName, newCellValue.toString());
    _updateDataGridRows();
    notifyListeners();
  }

  void _updateDataGridRows() {
    _dataGridRows = _navLogEntries.map<DataGridRow>((e) {
      return DataGridRow(cells: [
        DataGridCell<String>(columnName: 'waypoint', value: e.waypoint),
        DataGridCell<String>(columnName: 'vorRad', value: e.vorRad),
        DataGridCell<String>(columnName: 'vorDist', value: e.vorDist),
        DataGridCell<String>(columnName: 'freq', value: e.freq),
        DataGridCell<String>(columnName: 'dtk', value: e.dtk),
        DataGridCell<String>(columnName: 'safeAlt', value: e.safeAlt),
        DataGridCell<String>(columnName: 'distLeg', value: e.distLeg),
        DataGridCell<String>(columnName: 'distRem', value: e.distRem),
        DataGridCell<String>(columnName: 'timingEte', value: e.timingEte),
        DataGridCell<String>(columnName: 'timingAte', value: e.timingAte),
        DataGridCell<String>(columnName: 'timingEta', value: e.timingEta),
        DataGridCell<String>(columnName: 'timingAta', value: e.timingAta),
        DataGridCell<String>(columnName: 'fuelCons', value: e.fuelCons),
        DataGridCell<String>(columnName: 'fuelCumul', value: e.fuelCumul),
        DataGridCell<String>(columnName: 'ats', value: e.ats),
      ]);
    }).toList();
  }
}

