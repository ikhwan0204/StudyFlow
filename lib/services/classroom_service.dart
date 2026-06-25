// lib/services/classroom_service.dart
import 'package:googleapis/classroom/v1.dart';
import 'auth_service.dart';
import 'google_auth_client.dart';

class ClassroomAssignment {
  final String courseTitle;
  final String title;
  final DateTime? dueDate;
  final String? description;
  final String courseId;
  final String courseWorkId;

  ClassroomAssignment({
    required this.courseTitle,
    required this.title,
    this.dueDate,
    this.description,
    required this.courseId,
    required this.courseWorkId,
  });
}

class ClassroomService {
  // True kalau user sign-in guna Google (jadi ada akses Classroom)
  static bool get isAvailable => AuthService.googleUser != null;

  static Future<List<ClassroomAssignment>> fetchAllAssignments({
    DateTime? since,
  }) async {
    final googleUser = AuthService.googleUser;
    if (googleUser == null) {
      throw Exception('Sila sign in dengan Google untuk akses Classroom');
    }

    final authHeaders = await googleUser.authHeaders;
    final client = ClassroomApi(GoogleAuthClient(authHeaders));

    final List<ClassroomAssignment> allAssignments = [];
    final coursesResponse = await client.courses.list(
      courseStates: ['ACTIVE'],
    );
    final courses = coursesResponse.courses ?? [];

    for (final course in courses) {
      if (course.id == null) continue;

      final courseWorkResponse = await client.courses.courseWork.list(
        course.id!,
      );
      final courseWorkList = courseWorkResponse.courseWork ?? [];

      for (final work in courseWorkList) {
        DateTime? dueDate;
        if (work.dueDate != null) {
          dueDate = DateTime(
            work.dueDate!.year ?? DateTime.now().year,
            work.dueDate!.month ?? 1,
            work.dueDate!.day ?? 1,
            work.dueTime?.hours ?? 23,
            work.dueTime?.minutes ?? 59,
          );
        }

        // Skip assignment yang due date sebelum cutoff 'since'
        if (since != null && dueDate != null && dueDate.isBefore(since)) {
          continue;
        }

        print('DEBUG-RAW: ${work.title} | work.dueDate=${work.dueDate} | computed dueDate=$dueDate');


        allAssignments.add(
          ClassroomAssignment(
            courseTitle: course.name ?? 'Untitled Course',
            title: work.title ?? 'Untitled Assignment',
            dueDate: dueDate,
            description: work.description,
            courseId: course.id!,
            courseWorkId: work.id ?? '',
          ),
        );
      }
    }
    return allAssignments;
  }
}