import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/event_model.dart';
import '../../../services/event_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/colors.dart';

/// Displays a calendar of events for tourists, allowing selection and viewing of event details.
class EventCalendarScreen extends StatefulWidget {
  const EventCalendarScreen({super.key});

  @override
  State<EventCalendarScreen> createState() => _EventCalendarScreenState();
}

class _EventCalendarScreenState extends State<EventCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Future<List<Event>> _eventsFuture;
  List<Event> _allEvents = [];

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadEvents();
  }

  Future<List<Event>> _loadEvents() async {
    final events = await EventService.getAllEvents();
    setState(() {
      _allEvents = events;
    });
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.events),
        elevation: 0,
        backgroundColor: AppColors.backgroundColor,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: FutureBuilder<List<Event>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading events'));
          } else {
            // final events = snapshot.data ?? [];
            return SingleChildScrollView(
              child: Column(
                children: [
                  Image.asset(
                    AppConstants.logoAsset,
                    width: double.infinity,
                    height: AppConstants.calendarLogoHeight,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: AppConstants.calendarTitleSpacing),
                  const Text(
                    AppConstants.eventCalendarTitle,
                    style: TextStyle(
                      fontSize: AppConstants.calendarTitleFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: AppConstants.calendarTitleSpacing),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: AppConstants.calendarCardMargin),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppConstants.calendarCardPadding),
                      child: TableCalendar<Event>(
                        rowHeight: AppConstants.calendarRowHeight,
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2100, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        calendarFormat: CalendarFormat.month,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: AppColors.primaryOrange.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: AppColors.primaryTeal,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: const BoxDecoration(
                            color: AppColors.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                          cellMargin: EdgeInsets.zero,
                          defaultTextStyle: const TextStyle(
                            fontSize: AppConstants.calendarDayFontSize,
                            color: AppColors.textDark,
                          ),
                          weekendTextStyle: const TextStyle(
                            fontSize: AppConstants.calendarDayFontSize,
                            color: AppColors.primaryOrange,
                          ),
                          outsideTextStyle: const TextStyle(
                            fontSize: AppConstants.calendarDayFontSize,
                            color: AppColors.textLight,
                          ),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            fontSize: AppConstants.calendarWeekdayFontSize,
                            color: AppColors.textLight,
                          ),
                          weekendStyle: TextStyle(
                            fontSize: AppConstants.calendarWeekdayFontSize,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.calendarBelowSpacing),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime(
                              _focusedDay.year,
                              _focusedDay.month - 1,
                              1,
                            );
                          });
                        },
                        child: const Text(
                          AppConstants.thisMonth,
                          style: TextStyle(color: AppColors.primaryTeal),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime(
                              _focusedDay.year,
                              _focusedDay.month + 1,
                              1,
                            );
                          });
                        },
                        child: const Text(
                          AppConstants.nextMonth,
                          style: TextStyle(color: AppColors.primaryTeal),
                        ),
                      ),
                    ],
                  ),
                  // Show events for selected day or focused day
                  ..._getEventsForDay(_selectedDay ?? _focusedDay).map(
                    (event) => Card(
                      margin: const EdgeInsets.symmetric(horizontal: AppConstants.calendarEventCardMargin, vertical: AppConstants.calendarEventCardVertical),
                      child: ListTile(
                        leading: const Icon(
                          Icons.event,
                          color: AppColors.primaryTeal,
                        ),
                        title: Text(
                          event.title,
                          style: const TextStyle(color: AppColors.textDark),
                        ),
                        subtitle: Text(
                          '${_formatDate(event.startdate)}\n${event.location}',
                          style: const TextStyle(color: AppColors.textLight),
                        ),
                        onTap: () => _showEventDetailsForDay([event]),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  /// Returns the list of events for a given day.
  List<Event> _getEventsForDay(DateTime day) {
    return _allEvents.where((event) =>
      event.startdate.year == day.year &&
      event.startdate.month == day.month &&
      event.startdate.day == day.day
    ).toList();
  }

  /// Formats a [DateTime] as a readable string.
  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Shows a dialog with details for the given [events].
  void _showEventDetailsForDay(List<Event> events) {
    // Show a simple dialog with event details
    if (events.isEmpty) return;
    final event = events.first;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              event.title,
              style: const TextStyle(color: AppColors.primaryTeal),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(event.startdate),
                  style: const TextStyle(color: AppColors.textLight),
                ),
                const SizedBox(height: AppConstants.calendarEventDetailsSpacing),
                Text(
                  event.location,
                  style: const TextStyle(color: AppColors.textDark),
                ),
                const SizedBox(height: AppConstants.calendarEventDetailsSpacing),
                Text(
                  event.description,
                  style: const TextStyle(color: AppColors.textLight),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: AppColors.primaryTeal),
                ),
              ),
            ],
          ),
    );
  }
}

/// Extension for getting the month name from a [DateTime].
extension DateTimeMonthName on DateTime {
  String monthName() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}