import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../ms_format.dart';
import '../ms_sizes.dart';
import '../ms_tokens.dart';

/// Day · month · year wheels with Russian month names — offline, no extra
/// localisation package. Used for document expiry dates.
class MsDateWheel extends StatefulWidget {
  const MsDateWheel({
    super.key,
    required this.initial,
    required this.onChanged,
    this.firstYear,
    this.years = 20,
  });

  final DateTime initial;
  final ValueChanged<DateTime> onChanged;
  final int? firstYear;
  final int years;

  @override
  State<MsDateWheel> createState() => _MsDateWheelState();
}

class _MsDateWheelState extends State<MsDateWheel> {
  late int _day = widget.initial.day;
  late int _month = widget.initial.month;
  late int _year = widget.initial.year;
  late final int _firstYear = widget.firstYear ?? widget.initial.year;

  late final FixedExtentScrollController _d =
      FixedExtentScrollController(initialItem: _day - 1);
  late final FixedExtentScrollController _m =
      FixedExtentScrollController(initialItem: _month - 1);
  late final FixedExtentScrollController _y =
      FixedExtentScrollController(initialItem: _year - _firstYear);

  static final List<String> _months = [
    for (var m = 1; m <= 12; m++)
      DateFormat('MMMM', kMsLocale).format(DateTime(2000, m, 1)),
  ];

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  void _emit() {
    if (_day > _daysInMonth) {
      _day = _daysInMonth;
      _d.jumpToItem(_day - 1);
    }
    widget.onChanged(DateTime(_year, _month, _day));
  }

  @override
  void dispose() {
    _d.dispose();
    _m.dispose();
    _y.dispose();
    super.dispose();
  }

  Widget _wheel(FixedExtentScrollController c, int count,
      String Function(int) label, ValueChanged<int> onSelected) {
    final ms = context.ms;
    return CupertinoPicker(
      scrollController: c,
      itemExtent: MsSize.wheelItemH,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: ms.surface.withValues(alpha: MsAlpha.chipCountOn)),
      onSelectedItemChanged: (i) => setState(() {
        onSelected(i);
        _emit();
      }),
      children: [
        for (var i = 0; i < count; i++)
          Center(
            child: Text(label(i),
                style: MsText.body.copyWith(color: ms.ink),
                maxLines: 1),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MsSize.wheelH,
      child: Row(children: [
        Expanded(
          flex: 2,
          child: _wheel(_d, 31, (i) => '${i + 1}', (i) => _day = i + 1),
        ),
        Expanded(
          flex: 4,
          child: _wheel(_m, 12, (i) => _months[i], (i) => _month = i + 1),
        ),
        Expanded(
          flex: 3,
          child: _wheel(_y, widget.years, (i) => '${_firstYear + i}',
              (i) => _year = _firstYear + i),
        ),
      ]),
    );
  }
}
