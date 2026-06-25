import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// app_theme import removed (unused in this file)
import 'package:study_app/widgets/custom_card.dart';
import 'package:study_app/screens/subject/subject_shell.dart';
import 'package:study_app/providers/subject_provider.dart';
import 'package:study_app/providers/chapter_provider.dart';
import 'package:study_app/providers/study_provider.dart';
import 'package:study_app/providers/note_provider.dart';
import 'package:study_app/models/subject.dart';
import 'package:study_app/screens/subject/dialogs/add_subject_dialog.dart';
import 'package:study_app/screens/global/search_screen.dart';
import 'package:study_app/widgets/notification_sheet.dart';
import 'package:study_app/services/classroom_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showOnlyWithDueDate = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subjects'),
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyWithDueDate
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
            ),
            tooltip: 'Tunjuk yang ada due date je',
            onPressed: () {
              setState(() => _showOnlyWithDueDate = !_showOnlyWithDueDate);
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync from Google Classroom',
            onPressed: () => _syncFromClassroom(context),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => _showNotifications(context),
          ),
        ],
      ),
      body: Consumer<SubjectProvider>(
        builder: (context, subjectProvider, child) {
          final allSubjects = subjectProvider.subjects;
          final subjects = _showOnlyWithDueDate
              ? allSubjects.where((s) => s.dueDate != null).toList()
              : allSubjects;

          if (allSubjects.isEmpty) {
            return const Center(child: Text("No subjects yet. Add one!"));
          }

          if (subjects.isEmpty) {
            return const Center(child: Text("Tiada subject dengan due date."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: subjects.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return _buildSubjectCard(context, subject);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddSubjectDialog(
              onSubjectAdded: (subject) {
                Provider.of<SubjectProvider>(
                  context,
                  listen: false,
                ).addSubjectModel(subject);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${subject.name} added successfully!'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Subject subject) {
    // Generate a vibrant gradient based on the selected color
    final baseColor = Color(subject.colorValue);
    final hsl = HSLColor.fromColor(baseColor);
    final gradient = LinearGradient(
      colors: [
        hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor(),
        hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor(),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Consumer<ChapterProvider>(
      builder: (context, chapterProvider, child) {
        final chaptersCount = chapterProvider
            .getChaptersForSubject(subject.id)
            .length;

        return CustomCard(
          gradient: gradient,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SubjectShell(subject: subject)),
            );
          },
          onLongPress: () => _showDeleteSubjectDialog(context, subject),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            _showDeleteSubjectDialog(context, subject),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildStatChip(
                    context,
                    Icons.menu_book_rounded,
                    '$chaptersCount Chapters',
                  ),
                  // Will connect StudyTime later dynamically
                  Consumer<StudyProvider>(
                    builder: (context, studyProvider, child) {
                      final mins = studyProvider.getTotalStudyTimeForSubject(
                        subject.id,
                      );
                      final hoursStr = mins >= 60
                          ? '${mins ~/ 60}h ${mins % 60}m'
                          : '${mins}m';
                      return _buildStatChip(
                        context,
                        Icons.timer_rounded,
                        hoursStr,
                      );
                    },
                  ),
                  if (subject.dueDate != null)
                    _buildStatChip(
                      context,
                      Icons.event_rounded,
                      'Due ${_formatDueDate(subject.dueDate!, subject.dueTime)}',
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDueDate(DateTime date, TimeOfDay? time) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr = '${date.day} ${months[date.month - 1]}';
    if (time == null) return dateStr;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$dateStr, $hour:$minute $period';
  }

  // color option helper removed (unused after dialog integration)

  void _showDeleteSubjectDialog(BuildContext context, Subject subject) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Subject?'),
          content: Text(
            'Are you sure you want to delete "${subject.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final subjectId = subject.id;

                // Get all chapters to delete their specific data
                final chapterIds = Provider.of<ChapterProvider>(
                  context,
                  listen: false,
                ).getChaptersForSubject(subjectId).map((c) => c.id).toList();

                // Delete notes and sessions for each chapter
                for (final cId in chapterIds) {
                  Provider.of<NoteProvider>(
                    context,
                    listen: false,
                  ).deleteNotesForChapter(cId);
                  Provider.of<StudyProvider>(
                    context,
                    listen: false,
                  ).deleteSessionsForChapter(cId);
                }

                // Delete subject-level notes
                Provider.of<NoteProvider>(
                  context,
                  listen: false,
                ).deleteNotesForChapter(subjectId);

                // Delete subject-level sessions
                Provider.of<StudyProvider>(
                  context,
                  listen: false,
                ).deleteSessionsForSubject(subjectId);

                // Delete all chapters in subject
                Provider.of<ChapterProvider>(
                  context,
                  listen: false,
                ).deleteChaptersForSubject(subjectId);

                // Finally delete subject
                Provider.of<SubjectProvider>(
                  context,
                  listen: false,
                ).deleteSubject(subjectId);
                Navigator.pop(context);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNotifications(BuildContext context) {
    NotificationSheet.show(context);
  }

  Future<void> _syncFromClassroom(BuildContext context) async {
    if (!ClassroomService.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with Google to use Classroom sync'),
        ),
      );
      return;
    }

    // Tanya user nak sync dari bila
    final cutoff = await showDialog<DateTime?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Since when does the assignment sync?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              ctx,
              DateTime(DateTime.now().year, DateTime.now().month, 1),
            ),
            child: const Text('This month only'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              ctx,
              DateTime.now().subtract(const Duration(days: 90)),
            ),
            child: const Text('Last 3 months'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('All (no filter)'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final assignments = await ClassroomService.fetchAllAssignments(
        since: cutoff,
      );
      final subjectProvider = Provider.of<SubjectProvider>(
        context,
        listen: false,
      );
      final existingIds = subjectProvider.subjects.map((s) => s.id).toSet();

      int added = 0;
      for (final a in assignments) {
        final id = '${a.courseId}_${a.courseWorkId}';
        if (existingIds.contains(id)) continue; // skip kalau dah pernah disync

        DateTime? dueDateOnly;
        TimeOfDay? dueTimeOnly;
        if (a.dueDate != null) {
          dueDateOnly = DateTime(
            a.dueDate!.year,
            a.dueDate!.month,
            a.dueDate!.day,
          );
          dueTimeOnly = TimeOfDay(
            hour: a.dueDate!.hour,
            minute: a.dueDate!.minute,
          );
        }

        final subject = Subject(
          id: id,
          name: '${a.courseTitle} - ${a.title}',
          colorValue: 0xFF6C63FF, // default ungu — boleh tukar nanti kat UI
          dueDate: dueDateOnly,
          dueTime: dueTimeOnly,
          notes: a.description ?? '',
        );

        subjectProvider.addSubjectModel(subject);
        added++;
      }

      if (context.mounted) {
        Navigator.pop(context); // tutup loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$added assignment baru disync (${assignments.length - added} dah ada sebelum ni)',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed $e')));
      }
    }
  }
}
