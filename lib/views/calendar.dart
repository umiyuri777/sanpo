import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sanpo/import.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarView();
}

class _CalendarView extends State<CalendarView>{
  DateTime _selectedDay = DateTime.now();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'デバッグ情報',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugLocationsView()),
              );
            },
          ),
        ],
      ),
      body: TableCalendar(
        firstDay: DateTime.utc(2010, 1, 1),
        lastDay: DateTime.utc(2030, 1, 1),
        focusedDay: DateTime.now(),

        // // 日付が選択された時の処理
        // selectedDayPredicate: (day) {
        //   return isSameDay(_selectedDay, day);
        // },

        // 日付が選択された時の処理
        onDaySelected: (selectedDay, focusedDay) {
          // setState(() {
          //   _selectedDay = selectedDay;
          // });

          Navigator.push(context, MaterialPageRoute(builder: (context) => MapView()));

        },
        availableCalendarFormats: const {
          CalendarFormat.month: 'Month',
        },
      ),
    );
  }
}