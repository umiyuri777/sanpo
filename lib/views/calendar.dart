import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class TableCalendarView extends StatefulWidget {
  const TableCalendarView({super.key});

  @override
  State<TableCalendarView> createState() => _TableCalendarView();
}

class _TableCalendarView extends State<TableCalendarView>{
  DateTime _selectedDay = DateTime.now();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
      ),
      body: TableCalendar(
        firstDay: DateTime.utc(2010, 1, 1),
        lastDay: DateTime.utc(2030, 1, 1),
        focusedDay: DateTime.now(),
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
          });
        },
        availableCalendarFormats: const {
          CalendarFormat.month: 'Month',
        },
      ),
    );
  }
}