import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';
import 'package:todo_application/JSON/users.dart';
import 'package:todo_application/SQLite/database_helper.dart';
import 'package:todo_application/layout/todo_app/cubit/states.dart';
import 'package:todo_application/modules/todo_app/archived_tasks/archived_tasks.dart';
import 'package:todo_application/modules/todo_app/done_tasks/done_tasks.dart';
import 'package:todo_application/modules/todo_app/new_tasks/new_tasks.dart';

class AppCubit extends Cubit<AppStates> {
  AppCubit() : super(AppInitialState());
  Database? database;
  DatabaseHelper dbHelper = DatabaseHelper(); // Define dbHelper here

  List<Map> newTasks = [];
  List<Map> doneTasks = [];
  List<Map> archivedTasks = [];

  bool isBottomSheetShown = false;
  IconData fabIcon = Icons.edit;

  static AppCubit get(context) => BlocProvider.of(context);

  var currentIndexType = 0;

  List<Widget> screens = [
    NewTasksScreen(),
    DoneTasksScreen(),
    ArchivedTasksScreen(),
  ];

  List<String> titles = [
    "New Tasks",
    "Done Tasks",
    "Archived Tasks",
  ];

  String loggedInUserName = ''; // Define loggedInUserName here

  void changeIndex(int index) {
    currentIndexType = index;
    emit(AppChangeBottomNavBarState());
  }

  void createDatabase() {
  openDatabase(
    "todo.db",
    version: 1,
    onCreate: (database, version) async {
      print('database created');

      await database.execute(
        "CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT, date TEXT, time TEXT, status TEXT)"
      );

      // Check if the 'user_id' column already exists in the 'tasks' table
      var columns = await database.rawQuery("PRAGMA table_info(tasks)");
      var hasUserIdColumn = columns.any((column) => column['name'] == 'user_id');

      // If 'user_id' column does not exist, add it
      if (!hasUserIdColumn) {
        await database.execute(
          "ALTER TABLE tasks ADD COLUMN user_id INTEGER",
        );
      }
    },
    onOpen: (database) {
      print("database opened");

      getFromDatabase(database);
    },
  ).then((value) {
    database = value;
    emit(AppCreateDatabaseState());
  });
}






  void insertToDatabase({
  required String title,
  required String time,
  required String date,
  required BuildContext context,
}) async {
  // Check if the number of tasks is less than 5
  if (newTasks.length + doneTasks.length + archivedTasks.length >= 5) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cannot add more than 5 todos'),
      ),
    );
    return;
  }

  Users? currentUser = await dbHelper.getUser(loggedInUserName);
  if (currentUser == null) {
    print('Error: Unable to find the currently logged-in user');
    return;
  }

  await database!.transaction((txn) {
    return txn.rawInsert(
      'INSERT INTO tasks (title, date, time, status, user_id) VALUES (?, ?, ?, ?, ?)',
      [title, date, time, 'new', currentUser.usrId],
    ).then((value) {
      emit(AppInsertDatabaseState());
      getFromDatabase(database);
    }).catchError((error) {
      print('Error When Inserting New Record${error.toString()}');
    });
  });
}




  void updateData({
    required String status,
    required int id,
  }) {
    database!.rawUpdate(
        'UPDATE tasks SET status = ? WHERE id = ?', [status, id]).then((value) {
      getFromDatabase(database);
      emit(AppUpdateDatabaseState());
    });
  }

  void deleteData({
    required int id,
  }) {
    database!.rawDelete('DELETE FROM tasks WHERE id = ?', [id]).then((value) {
      getFromDatabase(database);
      emit(AppDeleteDatabaseState());
    });
  }

  void getFromDatabase(database) async{
  newTasks = [];
  doneTasks = [];
  archivedTasks = [];
  emit(AppGetDatabaseLoadingState());

  // Get the user ID of the currently logged-in user
  Users? currentUser = await dbHelper.getUser(loggedInUserName);
  if (currentUser == null) {
    // Handle error if user is not found
    print('Error: Unable to find the currently logged-in user');
    return;
  }

  // Fetch tasks associated with the user's ID
  database!.rawQuery('SELECT * FROM tasks WHERE user_id = ?', [currentUser.usrId]).then((value) {
    value.forEach((element) {
      if (element['status'] == 'new')
        newTasks.add(element);
      else if (element['status'] == 'done')
        doneTasks.add(element);
      else
        archivedTasks.add(element);
    });
    emit(AppGetDatabaseState());
  });
}


  void ChangeBottomSheetState({
    required bool isShow,
    required IconData icon,
  }) {
    isBottomSheetShown = isShow;
    fabIcon = icon;
    emit(AppChangeBottomSheetState());
  }
}
