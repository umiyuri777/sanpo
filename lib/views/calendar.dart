import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sanpo/import.dart';
import 'dart:io';
import 'package:sanpo/database/database_helper.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarView();
}

class _CalendarView extends State<CalendarView>{
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  final DatabaseHelper _db = DatabaseHelper();
  // 日付(00:00固定) -> サムネ画像のパス
  final Map<DateTime, String> _thumbnailByDate = {};

  @override
  void initState() {
    super.initState();
    _loadThumbnailsForMonth(_focusedDay);
  }

  // 指定した月の範囲にある写真から、各日付の代表サムネを作る
  Future<void> _loadThumbnailsForMonth(DateTime month) async {
    // 月初と月末(23:59:59)
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final photos = await _db.getPhotoRecordsByDateRange(start, end);

    final Map<DateTime, String> map = {};
    for (final p in photos) {
      final d = DateTime(p.timestamp.year, p.timestamp.month, p.timestamp.day);
      // 最初に見つかった1枚をその日のサムネにする
      map.putIfAbsent(d, () => p.imagePath);
    }

    if (mounted) {
      setState(() {
        _thumbnailByDate
          ..clear()
          ..addAll(map);
      });
    }
  }

  // 共通のセルビルダー（写真があれば背景に表示、なければ黒）
  Widget _buildDayCell(DateTime day, {bool isSelected = false, bool isToday = false}) {
    final dateKey = DateTime(day.year, day.month, day.day);
    final path = _thumbnailByDate[dateKey];

    final border = isSelected
        ? Border.all(color: Colors.orangeAccent, width: 2)
        : (isToday ? Border.all(color: Colors.white70, width: 1.5) : null);

    return Container(
      decoration: BoxDecoration(
        color: path == null ? Colors.black : null,
        borderRadius: BorderRadius.circular(8),
        image: path != null
            ? DecorationImage(
                image: FileImage(File(path)),
                fit: BoxFit.cover,
              )
            : null,
        border: border,
      ),
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.all(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${day.day}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
      ),
      body: TableCalendar(
        firstDay: DateTime.utc(2010, 1, 1),
        lastDay: DateTime.utc(2030, 1, 1),
        focusedDay: _focusedDay,

        // 日付が選択された時の処理
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },

        // 日付が選択された時の処理
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });

          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => MapView(selectedDate: selectedDay)
            )
          );
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
          _loadThumbnailsForMonth(focusedDay);
        },

        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) => _buildDayCell(day),
          todayBuilder: (context, day, focusedDay) =>
              _buildDayCell(day, isToday: true),
          selectedBuilder: (context, day, focusedDay) =>
              _buildDayCell(day, isSelected: true),
        ),

        availableCalendarFormats: const {
          CalendarFormat.month: 'Month',
        },
      ),
    );
  }
}