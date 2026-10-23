// lib/data/local/database_helper.dart
//
// لایهٔ پایگاه دادهٔ محلی (SQLite) برای اپ «معلم انگلیسی من»
// این کلاس فقط مدیریت اتصال به دیتابیس و ساخت اسکیمای اولیه را بر عهده دارد.
// منطق ورود/احراز هویت و رابط کاربری در فایل‌های دیگری پیاده‌سازی می‌شوند.

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// هلپر سینگلتون دیتابیس محلی.
///
/// - فایل دیتابیس: `english_teacher.db` داخل پوشهٔ اسناد اپ
/// - نسخه: 1
/// - همزمان‌سازی مقداردهی اولیه با نگه‌داشتن یک Future مشترک، امن است.
class DatabaseHelper {
  DatabaseHelper._private();

  /// تنها نمونهٔ اشتراکی
  static final DatabaseHelper instance = DatabaseHelper._private();

  static const String _databaseName = 'english_teacher.db';
  static const int _databaseVersion = 1;

  /// حافظهٔ Future اتصال: فراخوانی‌های همزمان database را یکسان برمی‌گردانند
  /// و فقط یک بار دیتابیس باز می‌شود.
  Future<Database>? _dbFuture;

  // ───────────────────────── SQL statements ─────────────────────────

  /// جدول حساب‌های کاربری محلی — مرحلهٔ ۱ (حساب‌ها و ذخیره‌سازی)
  /// هر حساب یک ایمیل یکتا دارد و رمز عبور فقط به صورت هش ذخیره می‌شود.
  static const String _createAccounts = 'CREATE TABLE accounts(id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL, name TEXT NOT NULL, password_hash TEXT NOT NULL, salt TEXT NOT NULL, created_at INTEGER NOT NULL, last_login_at INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL, firebase_uid TEXT)';

  /// جدول تکالیف دست‌نویس اسکن‌شده — مرحلهٔ ۲ (اسکن)
  /// تصویرهای تکلیف و متن استخراج‌شده از آن‌ها را نگه می‌دارد.
  static const String _createHomeworks = 'CREATE TABLE homeworks(id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, title TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, image_paths TEXT, extracted_text TEXT, is_deleted INTEGER NOT NULL DEFAULT 0)';

  /// جدول قواعد گرامری شخصی هر حساب — مرحلهٔ ۴ (گرامر)
  /// «قواعد من»: هر قاعده با فرمول، مثال و اشتباهات رایج ذخیره می‌شود.
  static const String _createGrammarRules = 'CREATE TABLE grammar_rules(id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, category TEXT NOT NULL, title TEXT NOT NULL, explanation TEXT NOT NULL, formula TEXT, examples TEXT, common_mistakes TEXT, first_seen_at INTEGER NOT NULL, is_starred INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL)';

  /// جدول واژگان — مرحلهٔ ۳ (ترجمه)، ۴ (گرامر) و ۶ (تمرین‌ها)
  /// داده‌های تکرار با فاصله (spaced repetition) هم اینجاست:
  /// next_review_at، interval_days، ease و repetitions.
  static const String _createWords = 'CREATE TABLE words(id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, word TEXT NOT NULL, meaning TEXT NOT NULL, pronunciation TEXT, pos TEXT, example TEXT, source TEXT, next_review_at INTEGER, interval_days INTEGER NOT NULL DEFAULT 1, ease REAL NOT NULL DEFAULT 2.5, repetitions INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0)';

  /// جدول فلش‌کارت‌ها — مرحلهٔ ۳ (ترجمه)، ۴ (گرامر) و ۶ (تمرین‌ها)
  /// مشابه واژگان، با پشتیبانی از دسته‌بندی (deck) و تکرار با فاصله.
  static const String _createFlashcards = 'CREATE TABLE flashcards(id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, front TEXT NOT NULL, back TEXT NOT NULL, deck TEXT, next_review_at INTEGER, interval_days INTEGER NOT NULL DEFAULT 1, ease REAL NOT NULL DEFAULT 2.5, repetitions INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0)';

  /// جدول تمرین‌ها و آزمون‌ها — مرحلهٔ ۶ (تمرین‌ها)
  /// نوع تمرین در فیلد type و جزئیات سؤال‌ها به صورت JSON در payload.
  static const String _createExercises = 'CREATE TABLE exercises(id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, type TEXT NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0)';

  /// جدول نمره‌ها — مرحلهٔ ۶ (تمرین‌ها)
  /// نتیجهٔ هر آزمون حل‌شده با نمره، سقف نمره و زمان برگزاری.
  static const String _createScores = 'CREATE TABLE scores(id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, exercise_id TEXT, score REAL NOT NULL, total REAL NOT NULL, taken_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)';

  /// جدول پیام‌های گفتگو با معلم هوش مصنوعی — مرحلهٔ ۵ (معلم هوش مصنوعی)
  /// نقش پیام (کاربر/دستیار) در فیلد role نگه‌داری می‌شود.
  static const String _createChatMessages = 'CREATE TABLE chat_messages(id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, role TEXT NOT NULL, content TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0)';

  /// ایندکس‌ها برای جست‌وجوی سریع رکوردهای هر حساب
  static const List<String> _createIndexes = [
    'CREATE INDEX idx_homeworks_account ON homeworks(account_id)',
    'CREATE INDEX idx_grammar_account ON grammar_rules(account_id)',
    'CREATE INDEX idx_words_account ON words(account_id)',
    'CREATE INDEX idx_flashcards_account ON flashcards(account_id)',
    'CREATE INDEX idx_exercises_account ON exercises(account_id)',
    'CREATE INDEX idx_scores_account ON scores(account_id)',
    'CREATE INDEX idx_chat_account ON chat_messages(account_id)',
  ];

  // ───────────────────────── Public API ─────────────────────────

  /// دیتابیس بازشده؛ اولین فراخوانی آن را می‌سازد و باز می‌کند،
  /// فراخوانی‌های بعدی همان نمونه را برمی‌گردانند.
  ///
  /// ضدگیر: بازشدن دیتابیس سقف زمانی دارد؛ اگر بار اول هنگ کرد یا
  /// خطا داد، یک بار دیگر از نو تلاش می‌شود تا اپ روی لودینگ نماند.
  Future<Database> get database {
    _dbFuture ??= _openWithRetry();
    return _dbFuture!;
  }

  Future<Database> _openWithRetry() async {
    try {
      return await _initDatabase().timeout(const Duration(seconds: 15));
    } catch (_) {
      return await _initDatabase().timeout(const Duration(seconds: 15));
    }
  }

  /// بستن اتصال و پاک کردن حافظه تا فراخوانی بعدی دوباره باز شود.
  Future<void> close() async {
    final future = _dbFuture;
    _dbFuture = null;
    if (future != null) {
      final db = await future;
      await db.close();
    }
  }

  // ───────────────────────── Internal ─────────────────────────

  Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDir.path, _databaseName);

    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onConfigure: (db) async {
        // فعال‌سازی کلیدهای خارجی برای حذف آبشاری (ON DELETE CASCADE)
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute(_createAccounts);
        await db.execute(_createHomeworks);
        await db.execute(_createGrammarRules);
        await db.execute(_createWords);
        await db.execute(_createFlashcards);
        await db.execute(_createExercises);
        await db.execute(_createScores);
        await db.execute(_createChatMessages);
        for (final indexSql in _createIndexes) {
          await db.execute(indexSql);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // مهاجرت‌های مرحله‌های بعدی (۲ به بعد) اینجا اضافه می‌شوند
        if (oldVersion < 2) {
          /* فعلاً مهاجری لازم نیست */
        }
      },
    );
  }
}
