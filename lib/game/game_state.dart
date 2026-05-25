import 'dart:math';

enum Team {
  red,
  blue,
  neutral,
  assassin,
}

String teamToString(Team team) {
  switch (team) {
    case Team.red:
      return 'red';
    case Team.blue:
      return 'blue';
    case Team.neutral:
      return 'neutral';
    case Team.assassin:
      return 'assassin';
  }
}

Team teamFromString(String value) {
  switch (value) {
    case 'red':
      return Team.red;
    case 'blue':
      return Team.blue;
    case 'neutral':
      return Team.neutral;
    case 'assassin':
      return Team.assassin;
    default:
      return Team.neutral;
  }
}


class CodeNameCard {
  final String word;
  final Team team;
  bool revealed;

  CodeNameCard({
    required this.word,
    required this.team,
    this.revealed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'team': teamToString(team),
      'revealed': revealed,
    };
  }

  factory CodeNameCard.fromMap(Map<String, dynamic> map) {
    return CodeNameCard(
      word: map['word'] as String,
      team: teamFromString(map['team'] as String),
      revealed: (map['revealed'] as bool?) ?? false,
    );
  }
}


enum Role {
  spymaster,
  operative,
}

class Player {
  final String id;      
  final String name;    
  final Team team;      
  final Role role;      

  Player({
    required this.id,
    required this.name,
    required this.team,
    required this.role,
  });
}

class WordPack {
  final String id;        
  final String name;      
  final String lang;      
  final List<String> words;

  const WordPack({
    required this.id,
    required this.name,
    required this.lang,
    required this.words,
  });
}

const WordPack classicEasyHePack = WordPack(
  id: 'classic_easy_he',
  name: 'Classic Easy',
  lang: 'he',
  words: classicEasyHe,
);

const WordPack classicMediumHePack = WordPack(
  id: 'classic_medium_he',
  name: 'Classic Medium',
  lang: 'he',
  words: classicMediumHe,
);

const WordPack classicHardHePack = WordPack(
  id: 'classic_hard_he',
  name: 'Classic Hard',
  lang: 'he',
  words: classicHardHe,
);

const WordPack classicEasyEnPack = WordPack(
  id: 'classic_easy_en',
  name: 'Classic Easy',
  lang: 'en',
  words: classicEasyEn,
);

const WordPack classicMediumEnPack = WordPack(
  id: 'classic_medium_en',
  name: 'Classic Medium',
  lang: 'en',
  words: classicMediumEn,
);

const WordPack classicHardEnPack = WordPack(
  id: 'classic_hard_en',
  name: 'Classic Hard',
  lang: 'en',
  words: classicHardEn,
);

// ---------- SPORTS ----------
const WordPack sportsHePack = WordPack(
  id: 'sports_he',
  name: 'Sports',
  lang: 'he',
  words: sportsHe,
);

const WordPack sportsEnPack = WordPack(
  id: 'sports_en',
  name: 'Sports',
  lang: 'en',
  words: sportsEn,
);

// ---------- COUNTRIES ----------
const WordPack countriesHePack = WordPack(
  id: 'countries_he',
  name: 'Countries',
  lang: 'he',
  words: countriesHe,
);

const WordPack countriesEnPack = WordPack(
  id: 'countries_en',
  name: 'Countries',
  lang: 'en',
  words: countriesEn,
);

// ---------- FOOD ----------
const WordPack foodHePack = WordPack(
  id: 'food_he',
  name: 'Food',
  lang: 'he',
  words: foodHe,
);

const WordPack foodEnPack = WordPack(
  id: 'food_en',
  name: 'Food',
  lang: 'en',
  words: foodEn,
);

// ---------- ISRAEL ----------
const WordPack israelHePack = WordPack(
  id: 'israel_he',
  name: 'Israel',
  lang: 'he',
  words: israelHe,
);

const WordPack israelEnPack = WordPack(
  id: 'israel_en',
  name: 'Israel',
  lang: 'en',
  words: israelEn,
);



const List<WordPack> wordPacks = [
  // Classic levels HE
  classicEasyHePack,
  classicMediumHePack,
  classicHardHePack,

  // Classic levels EN
  classicEasyEnPack,
  classicMediumEnPack,
  classicHardEnPack,

  // Categories
  sportsHePack,
  sportsEnPack,
  countriesHePack,
  countriesEnPack,
  foodHePack,
  foodEnPack,
  israelHePack,
  israelEnPack,
];

List<String> buildWordPool({
  required String lang,
  List<String>? selectedPackIds,
}) {
  // ברירת מחדל (עד שיש UI): Classic Easy בלבד לפי שפה
  final ids = (selectedPackIds == null || selectedPackIds.isEmpty)
      ? ['classic_easy_$lang']
      : selectedPackIds;

  final pool = wordPacks
      .where((p) => p.lang == lang && ids.contains(p.id))
      .expand((p) => p.words)
      .toSet() // מסיר כפילויות בין packs
      .toList();

  if (pool.length < 25) {
    final fallbackId = 'classic_easy_$lang';
    return wordPacks
        .where((p) => p.lang == lang && p.id == fallbackId)
        .expand((p) => p.words)
        .toSet()
        .toList();
  }

  return pool;
}



class GameState {
  final List<CodeNameCard> board;
  Team currentTeam;
  bool isGameOver;
  Team? winnerTeam;

  int redRemaining;
  int blueRemaining;

  final List<Player> players;

  // 💡 רמז לתור הנוכחי
  String? currentHintWord;     // המילה שהמנהיג אמר
  int? currentHintNumber;      // המספר שהמנהיג אמר
  int remainingGuesses;        // כמה ניחושים עוד מותר בתור הזה
  bool waitingForHint;         // true = מחכים שהמנהיג ייתן רמז

  GameState({
    required this.board,
    this.currentTeam = Team.red,
    this.isGameOver = false,
    this.winnerTeam,
    required this.redRemaining,
    required this.blueRemaining,
    required this.players,
    this.currentHintWord,
    this.currentHintNumber,
    this.remainingGuesses = 0,
    this.waitingForHint = true,
  });


factory GameState.newGame(
  String lang, {
  List<String>? selectedPackIds,
}) {
  final List<String> words = buildWordPool(
    lang: lang,
    selectedPackIds: selectedPackIds,
  );

    // ניקח את 25 המילים הראשונות ונערבב
    final random = Random();
    final selectedWords = List<String>.from(words)..shuffle(random);
    final boardWords = selectedWords.take(25).toList();
    // נגדיר כמה קלפים מכל סוג (לפי שם-קוד הקלאסי)
    const redCount = 9;
    const blueCount = 8;
    const assassinCount = 1;
    const totalCards = 25;
    final neutralCount = totalCards - redCount - blueCount - assassinCount; // 7

    // נבנה רשימת צבעים לפי הכמויות
    final teamsList = <Team>[
      ...List.filled(redCount, Team.red),
      ...List.filled(blueCount, Team.blue),
      ...List.filled(neutralCount, Team.neutral),
      ...List.filled(assassinCount, Team.assassin),
    ]..shuffle(random);

    // נבנה לוח של CodeNameCard
    final board = List<CodeNameCard>.generate(totalCards, (index) {
      return CodeNameCard(
        word: boardWords[index],
        team: teamsList[index],
      );
    });

    final redOnBoard = teamsList.where((t) => t == Team.red).length;
    final blueOnBoard = teamsList.where((t) => t == Team.blue).length;

    // בינתיים, לוקאלית, נגדיר 2 מנהיגים ושני שחקנים רגילים לדוגמה
    final players = <Player>[
      Player(
        id: 'red_spymaster',
        name: 'Red Spymaster',
        team: Team.red,
        role: Role.spymaster,
      ),
      Player(
        id: 'red_op1',
        name: 'Red Operative',
        team: Team.red,
        role: Role.operative,
      ),
      Player(
        id: 'blue_spymaster',
        name: 'Blue Spymaster',
        team: Team.blue,
        role: Role.spymaster,
      ),
      Player(
        id: 'blue_op1',
        name: 'Blue Operative',
        team: Team.blue,
        role: Role.operative,
      ),
    ];

    return GameState(
      board: board,
      currentTeam: Team.red,
      isGameOver: false,
      winnerTeam: null,
      redRemaining: redOnBoard,
      blueRemaining: blueOnBoard,
      players: players,
      currentHintWord: null,
      currentHintNumber: null,
      remainingGuesses: 0,
      waitingForHint: true, // מתחילים תור בלי רמז – מחכים למנהיג
    );

  }

    void revealCard(int index) {
      if (isGameOver) return;
      if (waitingForHint) return; // מחכים למנהיג – אסור לנחש
      if (index < 0 || index >= board.length) return;

      final card = board[index];
      if (card.revealed) return;

      card.revealed = true;

      // 🔥 אם זה מרגל שחור – המשחק נגמר
      if (card.team == Team.assassin) {
        isGameOver = true;
        winnerTeam = (currentTeam == Team.red) ? Team.blue : Team.red;
        return;
      }

      // 🎯 עדכון ניקוד (כמה מילים נשארו)
      if (card.team == Team.red) {
        redRemaining--;
        if (redRemaining == 0) {
          isGameOver = true;
          winnerTeam = Team.red;
          return;
        }
      } else if (card.team == Team.blue) {
        blueRemaining--;
        if (blueRemaining == 0) {
          isGameOver = true;
          winnerTeam = Team.blue;
          return;
        }
      }

      // 🧮 מורידים ניחוש
      remainingGuesses--;

      final pickedOwnTeam = (card.team == currentTeam);
      final pickedNeutral = (card.team == Team.neutral);
      final pickedOpponent = (!pickedOwnTeam && card.team != Team.neutral);

      // 🟥🟦 אם בחרו את הצבע של היריב → סוף תור מיד
      if (pickedOpponent) {
        _endTurn();
        return;
      }

      // ⚪ אם בחרו ניטרלי → סוף תור מיד
      if (pickedNeutral) {
        _endTurn();
        return;
      }

      // אם בחרו צבע של עצמם:
      // אם נגמרו ניחושים → מסיימים תור
      if (remainingGuesses <= 0) {
        _endTurn();
        return;
      }

      // 🎉 אחרת – נשארים בתור וממשיכים לנחש
    }

    void _endTurn() {
      currentTeam = (currentTeam == Team.red) ? Team.blue : Team.red;
      waitingForHint = true;      // מחכים לרמז חדש מהמנהיג הבא
      currentHintWord = null;
      currentHintNumber = null;
      remainingGuesses = 0;
    }

    void endTurnEarly() {
      
    currentTeam = currentTeam == Team.red ? Team.blue : Team.red;

    waitingForHint = true;
    currentHintWord = null;
    currentHintNumber = null;
    remainingGuesses = 0;
  }


    void setHint(String word, int number) {
    if (isGameOver) return;
    if (!waitingForHint) return;  // כבר יש רמז פעיל

    if (number <= 0) {
      throw ArgumentError('Hint number must be positive');
    }

    currentHintWord = word;
    currentHintNumber = number;
    remainingGuesses = number + 1; // כמו במשחק: N + 1 ניחושים
    waitingForHint = false;
  }

   Map<String, dynamic> toMap() {
    return {
      'board': board.map((card) => card.toMap()).toList(),
      'currentTeam': teamToString(currentTeam),
      'isGameOver': isGameOver,
      'winnerTeam': winnerTeam != null ? teamToString(winnerTeam!) : null,
      'redRemaining': redRemaining,
      'blueRemaining': blueRemaining,
      'currentHintWord': currentHintWord,
      'currentHintNumber': currentHintNumber,
      'remainingGuesses': remainingGuesses,
      'waitingForHint': waitingForHint,
      // אם תרצה בהמשך אפשר להוסיף גם players פה
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map) {
    final List<dynamic> boardListDynamic = map['board'] as List<dynamic>;
    final List<CodeNameCard> boardFromMap = boardListDynamic
        .map((e) => CodeNameCard.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();

    final String currentTeamStr = map['currentTeam'] as String;
    final bool isGameOver = (map['isGameOver'] as bool?) ?? false;

    final String? winnerTeamStr = map['winnerTeam'] as String?;
    final Team? winnerTeam =
        winnerTeamStr != null ? teamFromString(winnerTeamStr) : null;

    return GameState(
      board: boardFromMap,
      currentTeam: teamFromString(currentTeamStr),
      isGameOver: isGameOver,
      winnerTeam: winnerTeam,
      redRemaining: (map['redRemaining'] as int?) ?? 0,
      blueRemaining: (map['blueRemaining'] as int?) ?? 0,
      players: const [], // כרגע לא טוענים שחקנים מ-Firestore
      currentHintWord: map['currentHintWord'] as String?,
      currentHintNumber: map['currentHintNumber'] as int?,
      remainingGuesses: (map['remainingGuesses'] as int?) ?? 0,
      waitingForHint: (map['waitingForHint'] as bool?) ?? true,
    );
  }
}

const List<String> classicEasyHe = [
  "שולחן",
  "כיסא",
  "דלת",
  "חלון",
  "מיטה",
  "כרית",
  "שמיכה",
  "ארון",
  "מדף",
  "מנורה",
  "נר",
  "שעון",
  "מראה",
  "תמונה",
  "קיר",
  "רצפה",
  "גג",
  "מפתח",
  "מנעול",
  "תיק",
  "ספר",
  "מחברת",
  "עט",
  "עיפרון",
  "מחק",
  "קלמר",
  "תיקייה",
  "מחשב",
  "טלפון",
  "שלט",
  "ספה",
  "שטיח",
  "מקרר",
  "תנור",
  "כיריים",
  "צלחת",
  "כוס",
  "מזלג",
  "כף",
  "סכין",
  "מים",
  "חלב",
  "לחם",
  "גבינה",
  "אורז",
  "ביצה",
  "עגבנייה",
  "מלפפון",
  "תפוח",
  "בננה",
  "תות",
  "ענב",
  "אבטיח",
  "גזר",
  "תפוחי אדמה",
  "שוקולד",
  "עוגה",
  "גלידה",
  "סוכר",
  "מלח",
  "פלפל",
  "חתול",
  "כלב",
  "סוס",
  "פרה",
  "כבשה",
  "אריה",
  "דג",
  "ציפור",
  "ברווז",
  "תרנגול",
  "עץ",
  "פרח",
  "דשא",
  "שמש",
  "ירח",
  "כוכב",
  "ענן",
  "גשם",
  "שלג",
  "רוח",
  "ים",
  "נהר",
  "הר",
  "חוף",
  "אוטו",
  "אופניים",
  "רכבת",
  "אוטובוס",
  "מטוס",
  "כביש",
  "גשר",
  "תחנה",
  "בית",
  "חדר",
  "בית ספר",
  "גן",
  "פארק",
  "חנות",
  "קניון",
  "שוק",
  "חוף ים",
  "כדור",
  "משחק",
  "חבר",
  "משפחה",
  "ילד",
  "ילדה",
  "אמא",
  "אבא",
  "אח",
  "אחות",
  "חיוך",
  "צחוק",
  "שיר",
  "ריקוד",
  "סרט"
];

const List<String> classicMediumHe = [
  "צל",
  "להבה",
  "אדמה",
  "קרח",
  "עשן",
  "אבק",
  "סוד",
  "תקווה",
  "זיכרון",
  "רעש",
  "שקט",
  "כאב",
  "פחד",
  "אומץ",
  "רעיון",
  "תוכנית",
  "שיטה",
  "חוק",
  "משפט",
  "מקרה",
  "גורל",
  "מזל",
  "סיבה",
  "תוצאה",
  "מרכז",
  "קצה",
  "גבול",
  "כיוון",
  "מרחק",
  "מהירות",
  "משקל",
  "אור",
  "חושך",
  "כוח",
  "חומר",
  "צורה",
  "דמות",
  "תפקיד",
  "מקום",
  "זמן",
  "עבר",
  "עתיד",
  "הווה",
  "דרך",
  "מסע",
  "תחום",
  "רמה",
  "ערך",
  "מידה",
  "מטרה",
  "אתגר",
  "ניסיון",
  "בחירה",
  "החלטה",
  "התחלה",
  "סיום",
  "רגע",
  "אירוע",
  "תנועה",
  "שינוי",
  "שלב",
  "מצב",
  "יחס",
  "קשר",
  "מערכת",
  "תהליך",
  "רשת",
  "עומק",
  "גובה",
  "רוחב",
  "קול",
  "צליל",
  "שפה",
  "מילה",
  "סיפור",
  "דף",
  "כתב",
  "מספר",
  "סמל",
  "סימן",
  "צבע",
  "טעם",
  "ריח",
  "חום",
  "קור",
  "שאלה",
  "תשובה",
  "עובדה",
  "דעה",
  "רעב",
  "עייפות",
  "בריאות",
  "מחלה",
  "תרופה",
  "זהב",
  "כסף",
  "אבן",
  "ברזל",
  "עור",
  "דם",
  "לב",
  "ראש",
  "יד",
  "רגל",
  "עין",
  "אוזן",
  "פה",
  "גב",
  "בטן",
  "שן",
  "יער",
  "מדבר",
  "אי",
  "עיר",
  "כפר"
];

const List<String> classicHardHe = [
  "פרדוקס",
  "תודעה",
  "תפיסה",
  "זהות",
  "אשליה",
  "דמיון",
  "היגיון",
  "אבסורד",
  "אינטואיציה",
  "מורכבות",
  "ספק",
  "השערה",
  "עקרון",
  "מנגנון",
  "אסטרטגיה",
  "טקטיקה",
  "קונספט",
  "סימולציה",
  "אלגוריתם",
  "סטטיסטיקה",
  "אנרגיה",
  "מולקולה",
  "אטום",
  "חלקיק",
  "תאוריה",
  "מהפכה",
  "אימפריה",
  "מונרכיה",
  "דמוקרטיה",
  "קונפליקט",
  "משבר",
  "אידיאולוגיה",
  "תרבות",
  "מיתוס",
  "פולחן",
  "סמליות",
  "סאטירה",
  "מטאפורה",
  "אלגוריה",
  "אינטגרציה",
  "דינמיקה",
  "פרספקטיבה",
  "אבולוציה",
  "רגרסיה",
  "קואורדינציה",
  "פרופורציה",
  "איזון",
  "אופוזיציה",
  "טרנספורמציה",
  "פרגמטיות",
  "אוטונומיה",
  "ביורוקרטיה",
  "סמכות",
  "לגיטימציה",
  "קונספירציה",
  "אנלוגיה",
  "דיסוננס",
  "הרמוניה",
  "מוטיבציה",
  "אובססיה",
  "אמביציה",
  "פרשנות",
  "קונטקסט",
  "רציונל",
  "פוטנציאל",
  "קונסולידציה",
  "אינפלציה",
  "רפורמה",
  "פרוטוקול",
  "ארכיון",
  "ספקטרום",
  "פרגמנט",
  "אנומליה",
  "אינטראקציה",
  "קונסיסטנטיות",
  "סינכרון",
  "קונבנציה",
  "אקסיומה",
  "היפותזה",
  "דוקטרינה",
  "מניפסט",
  "סמנטיקה",
  "פרגמנטציה",
  "קונפלואנס",
  "טריטוריה",
  "פדרציה",
  "קונסוליה",
  "אינדיקציה",
  "רזולוציה",
  "קונצנזוס",
  "אידיליה",
  "פרולטריון",
  "בורגנות",
  "תזה",
  "אנטיתזה",
  "סינתזה",
  "נומינלי",
  "אקספוננציאלי",
  "אינטלקט",
  "אימפולס",
  "דטרמיניזם",
  "אינטגריטי",
  "אמפיריות",
  "רלטיביזם",
  "פנורמה",
  "קונפיגורציה",
  "סטרוקטורה",
  "אבסטרקציה",
  "קואורדינטה",
  "אורביט",
  "טרמינולוגיה",
  "דיאלקטיקה"
];

const List<String> classicEasyEn = [
  "table",
  "chair",
  "door",
  "window",
  "bed",
  "pillow",
  "blanket",
  "lamp",
  "clock",
  "mirror",
  "key",
  "bag",
  "book",
  "pen",
  "paper",
  "phone",
  "computer",
  "sofa",
  "carpet",
  "fridge",
  "oven",
  "plate",
  "cup",
  "fork",
  "knife",
  "water",
  "milk",
  "bread",
  "cheese",
  "rice",
  "egg",
  "tomato",
  "apple",
  "banana",
  "grape",
  "cake",
  "sugar",
  "salt",
  "cat",
  "dog",
  "horse",
  "cow",
  "lion",
  "fish",
  "bird",
  "tree",
  "flower",
  "grass",
  "sun",
  "moon",
  "star",
  "cloud",
  "rain",
  "snow",
  "wind",
  "sea",
  "river",
  "mountain",
  "beach",
  "car",
  "bike",
  "train",
  "bus",
  "plane",
  "road",
  "bridge",
  "house",
  "room",
  "school",
  "park",
  "store",
  "market",
  "ball",
  "game",
  "friend",
  "family",
  "child",
  "mother",
  "father",
  "brother",
  "sister",
  "smile",
  "laugh",
  "song",
  "dance",
  "movie",
  "city",
  "village",
  "forest",
  "desert",
  "island",
  "boat",
  "ship",
  "shirt",
  "pants",
  "shoe",
  "hat",
  "jacket",
  "ring",
  "box",
  "gift",
  "photo",
  "picture",
  "wall",
  "floor",
  "roof",
  "garden",
  "ticket",
  "coin",
  "money",
  "letter",
  "sound",
  "color",
  "light",
  "shadow"
];

const List<String> classicMediumEn = [
  "shadow",
  "flame",
  "dust",
  "secret",
  "hope",
  "memory",
  "noise",
  "silence",
  "pain",
  "fear",
  "courage",
  "idea",
  "plan",
  "method",
  "law",
  "case",
  "luck",
  "reason",
  "result",
  "center",
  "edge",
  "limit",
  "direction",
  "distance",
  "speed",
  "weight",
  "force",
  "shape",
  "figure",
  "role",
  "place",
  "time",
  "past",
  "future",
  "journey",
  "field",
  "level",
  "value",
  "goal",
  "challenge",
  "choice",
  "decision",
  "beginning",
  "ending",
  "moment",
  "event",
  "movement",
  "change",
  "stage",
  "state",
  "relation",
  "system",
  "process",
  "network",
  "depth",
  "height",
  "width",
  "voice",
  "language",
  "story",
  "page",
  "number",
  "symbol",
  "sign",
  "taste",
  "smell",
  "question",
  "answer",
  "fact",
  "opinion",
  "health",
  "disease",
  "medicine",
  "gold",
  "silver",
  "stone",
  "iron",
  "blood",
  "heart",
  "mind",
  "body",
  "energy",
  "power",
  "battle",
  "peace",
  "leader",
  "crowd",
  "corner",
  "path",
  "tool",
  "machine",
  "engine",
  "signal",
  "screen",
  "market",
  "office",
  "court",
  "capital",
  "border",
  "victory",
  "loss",
  "risk",
  "reward",
  "target",
  "mission",
  "pressure",
  "impact",
  "pattern",
  "surface",
  "layer",
  "balance",
  "trend",
  "cycle"
];

const List<String> classicHardEn = [
  "paradox",
  "consciousness",
  "perception",
  "identity",
  "illusion",
  "intuition",
  "complexity",
  "hypothesis",
  "principle",
  "mechanism",
  "strategy",
  "tactic",
  "concept",
  "simulation",
  "algorithm",
  "statistics",
  "molecule",
  "atom",
  "theory",
  "revolution",
  "empire",
  "democracy",
  "conflict",
  "crisis",
  "ideology",
  "myth",
  "symbolism",
  "satire",
  "metaphor",
  "integration",
  "dynamic",
  "perspective",
  "evolution",
  "regression",
  "coordination",
  "proportion",
  "opposition",
  "transformation",
  "autonomy",
  "bureaucracy",
  "authority",
  "legitimacy",
  "analogy",
  "dissonance",
  "harmony",
  "motivation",
  "obsession",
  "ambition",
  "interpretation",
  "context",
  "rationale",
  "potential",
  "consolidation",
  "inflation",
  "reform",
  "protocol",
  "spectrum",
  "fragment",
  "anomaly",
  "interaction",
  "consistency",
  "convention",
  "axiom",
  "doctrine",
  "manifesto",
  "semantics",
  "territory",
  "federation",
  "indication",
  "resolution",
  "consensus",
  "proletariat",
  "thesis",
  "antithesis",
  "synthesis",
  "exponential",
  "determinism",
  "relativism",
  "panorama",
  "configuration",
  "structure",
  "abstraction",
  "coordinate",
  "orbit",
  "terminology",
  "dialectic",
  "entropy",
  "paradigm",
  "synergy",
  "infrastructure",
  "legislation",
  "hierarchy",
  "dimension",
  "variable",
  "parameter",
  "framework",
  "matrix",
  "derivative",
  "equilibrium",
  "hypothetical",
  "empirical",
  "metaphysics",
  "epistemology",
  "ontology",
  "heuristic",
  "algorithmic",
  "optimization",
  "simulation",
  "quantum",
  "paradigmatic"
];

const List<String> sportsHe = [
  "כדור",
  "שחקן",
  "מאמן",
  "שופט",
  "אצטדיון",
  "מגרש",
  "קהל",
  "ניצחון",
  "הפסד",
  "תיקו",
  "גול",
  "נקודה",
  "מדליה",
  "גביע",
  "אליפות",
  "ליגה",
  "טורניר",
  "משחק",
  "קבוצה",
  "יריב",
  "קפטן",
  "חילוף",
  "עבירה",
  "פנדל",
  "נבדל",
  "שער",
  "בעיטה",
  "מסירה",
  "הגנה",
  "התקפה",
  "בלם",
  "חלוץ",
  "שוער",
  "כדורגל",
  "כדורסל",
  "טניס",
  "כדורעף",
  "שחייה",
  "ריצה",
  "קפיצה",
  "מרתון",
  "ספרינט",
  "מסלול",
  "בריכה",
  "טבעת",
  "מחבט",
  "רשת",
  "כפפות",
  "קסדה",
  "מדים",
  "נעליים",
  "אימון",
  "חימום",
  "מתיחה",
  "שריר",
  "כושר",
  "סיבולת",
  "מהירות",
  "כוח",
  "דיוק",
  "שיא",
  "שיאן",
  "פרס",
  "דירוג",
  "טבלה",
  "מחזור",
  "קאמבק",
  "שובר שוויון",
  "דרבי",
  "אוהד",
  "יציע",
  "קפיצה לגובה",
  "קפיצה לרוחק",
  "הרמת משקולות",
  "איגרוף",
  "ג'ודו",
  "התעמלות",
  "היאבקות",
  "קרב"
];

const List<String> sportsEn = [
  "ball",
  "player",
  "coach",
  "referee",
  "stadium",
  "field",
  "crowd",
  "victory",
  "loss",
  "draw",
  "goal",
  "point",
  "medal",
  "cup",
  "championship",
  "league",
  "tournament",
  "match",
  "team",
  "opponent",
  "captain",
  "substitution",
  "foul",
  "penalty",
  "offside",
  "net",
  "kick",
  "pass",
  "defense",
  "attack",
  "defender",
  "forward",
  "goalkeeper",
  "football",
  "basketball",
  "tennis",
  "volleyball",
  "swimming",
  "running",
  "jump",
  "marathon",
  "sprint",
  "track",
  "pool",
  "ring",
  "racket",
  "goalpost",
  "gloves",
  "helmet",
  "uniform",
  "shoes",
  "training",
  "warmup",
  "stretch",
  "muscle",
  "fitness",
  "endurance",
  "speed",
  "strength",
  "accuracy",
  "record",
  "record holder",
  "award",
  "ranking",
  "table",
  "round",
  "comeback",
  "tiebreak",
  "derby",
  "fan",
  "stand",
  "high jump",
  "long jump",
  "weightlifting",
  "boxing",
  "judo",
  "gymnastics",
  "wrestling",
  "fight"
];

const List<String> countriesHe = [
  "ישראל",
  "ארצות הברית",
  "קנדה",
  "מקסיקו",
  "ברזיל",
  "ארגנטינה",
  "צ'ילה",
  "קולומביה",
  "פרו",
  "ונצואלה",
  "בריטניה",
  "אירלנד",
  "צרפת",
  "גרמניה",
  "איטליה",
  "ספרד",
  "פורטוגל",
  "הולנד",
  "בלגיה",
  "שווייץ",
  "אוסטריה",
  "פולין",
  "צ'כיה",
  "הונגריה",
  "רומניה",
  "יוון",
  "טורקיה",
  "רוסיה",
  "אוקראינה",
  "שוודיה",
  "נורווגיה",
  "דנמרק",
  "פינלנד",
  "איסלנד",
  "סין",
  "יפן",
  "קוריאה הדרומית",
  "הודו",
  "פקיסטן",
  "אינדונזיה",
  "תאילנד",
  "וייטנאם",
  "פיליפינים",
  "מלזיה",
  "סינגפור",
  "אוסטרליה",
  "ניו זילנד",
  "מצרים",
  "מרוקו",
  "אלג'יריה",
  "טוניסיה",
  "ניגריה",
  "קניה",
  "אתיופיה",
  "דרום אפריקה",
  "סעודיה",
  "איחוד האמירויות",
  "קטאר",
  "ירדן",
  "לבנון",
  "סוריה",
  "עיראק",
  "איראן",
  "אפגניסטן",
  "נפאל",
  "בנגלדש",
  "סרי לנקה",
  "קובה",
  "פנמה",
  "קוסטה ריקה",
  "שוויץ",
  "סלובקיה",
  "קרואטיה",
  "סרביה",
  "בולגריה",
  "ליטא",
  "לטביה",
  "אסטוניה",
  "גאורגיה",
  "ארמניה"
];

const List<String> countriesEn = [
  "Israel",
  "United States",
  "Canada",
  "Mexico",
  "Brazil",
  "Argentina",
  "Chile",
  "Colombia",
  "Peru",
  "Venezuela",
  "United Kingdom",
  "Ireland",
  "France",
  "Germany",
  "Italy",
  "Spain",
  "Portugal",
  "Netherlands",
  "Belgium",
  "Switzerland",
  "Austria",
  "Poland",
  "Czech Republic",
  "Hungary",
  "Romania",
  "Greece",
  "Turkey",
  "Russia",
  "Ukraine",
  "Sweden",
  "Norway",
  "Denmark",
  "Finland",
  "Iceland",
  "China",
  "Japan",
  "South Korea",
  "India",
  "Pakistan",
  "Indonesia",
  "Thailand",
  "Vietnam",
  "Philippines",
  "Malaysia",
  "Singapore",
  "Australia",
  "New Zealand",
  "Egypt",
  "Morocco",
  "Algeria",
  "Tunisia",
  "Nigeria",
  "Kenya",
  "Ethiopia",
  "South Africa",
  "Saudi Arabia",
  "United Arab Emirates",
  "Qatar",
  "Jordan",
  "Lebanon",
  "Syria",
  "Iraq",
  "Iran",
  "Afghanistan",
  "Nepal",
  "Bangladesh",
  "Sri Lanka",
  "Cuba",
  "Panama",
  "Costa Rica",
  "Switzerland",
  "Slovakia",
  "Croatia",
  "Serbia",
  "Bulgaria",
  "Lithuania",
  "Latvia",
  "Estonia",
  "Georgia",
  "Armenia"
];

const List<String> foodHe = [
  "פיצה",
  "המבורגר",
  "שווארמה",
  "פלאפל",
  "סושי",
  "פסטה",
  "לזניה",
  "קוסקוס",
  "חומוס",
  "טחינה",
  "שניצל",
  "סטייק",
  "עוף",
  "דג",
  "סלט",
  "מרק",
  "אורז",
  "פירה",
  "תפוחי אדמה",
  "פנקייק",
  "וופל",
  "עוגה",
  "עוגייה",
  "גלידה",
  "שוקולד",
  "קרואסון",
  "לחם",
  "באגט",
  "פיתה",
  "טוסט",
  "גבינה",
  "יוגורט",
  "חלב",
  "ביצה",
  "נקניק",
  "נקניקיה",
  "סלט יווני",
  "סלט קיסר",
  "פסטה בולונז",
  "ריזוטו",
  "ספגטי",
  "טורטייה",
  "טאקו",
  "נאצ'וס",
  "קבב",
  "שיפוד",
  "סביח",
  "מלבי",
  "כנאפה",
  "בורקס",
  "קובה",
  "גולש",
  "צ'יפס",
  "פופקורן",
  "דונאט",
  "מאפין",
  "קרקר",
  "קורנפלקס",
  "דייסה",
  "חביתה",
  "פיצה מרגריטה",
  "רביולי",
  "סלט טונה",
  "כריך",
  "טוסט נקניק",
  "שוקו",
  "קפה",
  "תה",
  "מיץ",
  "מים מינרליים",
  "לימונדה",
  "פירות",
  "ירקות",
  "תותים",
  "אבטיח",
  "בננה",
  "תפוח",
  "אננס",
  "מנגו"
];

const List<String> foodEn = [
  "pizza",
  "hamburger",
  "shawarma",
  "falafel",
  "sushi",
  "pasta",
  "lasagna",
  "couscous",
  "hummus",
  "tahini",
  "schnitzel",
  "steak",
  "chicken",
  "fish",
  "salad",
  "soup",
  "rice",
  "mashed potatoes",
  "potatoes",
  "pancake",
  "waffle",
  "cake",
  "cookie",
  "ice cream",
  "chocolate",
  "croissant",
  "bread",
  "baguette",
  "pita",
  "toast",
  "cheese",
  "yogurt",
  "milk",
  "egg",
  "sausage",
  "hot dog",
  "greek salad",
  "caesar salad",
  "bolognese pasta",
  "risotto",
  "spaghetti",
  "tortilla",
  "taco",
  "nachos",
  "kebab",
  "skewer",
  "sabich",
  "malabi",
  "kanafeh",
  "bourekas",
  "kubbeh",
  "goulash",
  "fries",
  "popcorn",
  "donut",
  "muffin",
  "cracker",
  "cornflakes",
  "porridge",
  "omelette",
  "margherita pizza",
  "ravioli",
  "tuna salad",
  "sandwich",
  "sausage toast",
  "chocolate milk",
  "coffee",
  "tea",
  "juice",
  "mineral water",
  "lemonade",
  "fruits",
  "vegetables",
  "strawberries",
  "watermelon",
  "banana",
  "apple",
  "pineapple",
  "mango"
];

const List<String> israelHe = [
  "תל אביב",
  "ירושלים",
  "חיפה",
  "באר שבע",
  "אילת",
  "נצרת",
  "טבריה",
  "אשדוד",
  "אשקלון",
  "נתניה",
  "רמת גן",
  "הרצליה",
  "קיסריה",
  "עכו",
  "צפת",
  "ים המלח",
  "כנרת",
  "הנגב",
  "הגליל",
  "הכרמל",
  "ירדן",
  "מדבר יהודה",
  "כותל",
  "הר הבית",
  "שוק מחנה יהודה",
  "דיזנגוף",
  "שרונה",
  "יפו",
  "מוזיאון ישראל",
  "יד ושם",
  "כנסת",
  "צה״ל",
  "מגן דוד",
  "דגל ישראל",
  "התקווה",
  "שקל",
  "פלאפל",
  "שווארמה",
  "סביח",
  "חומוס",
  "קיבוץ",
  "מושב",
  "התנחלות",
  "אולפן",
  "בגרות",
  "טכניון",
  "אוניברסיטת תל אביב",
  "האוניברסיטה העברית",
  "שב״כ",
  "המוסד",
  "גולן",
  "חרמון",
  "מצדה",
  "קיסריה",
  "עיר דוד",
  "רכבת ישראל",
  "כביש החוף",
  "מנהרה",
  "שוק הכרמל",
  "הבורסה",
  "כיפת ברזל",
  "חיל האוויר",
  "גולדה",
  "בן גוריון",
  "הרצל",
  "רבין",
  "שוק",
  "מילואים",
  "יום העצמאות",
  "יום הזיכרון",
  "חנוכה",
  "פסח",
  "ראש השנה",
  "כיפור",
  "פורים",
  "שבת",
  "עברית",
  "מדינה",
  "עלייה"
];

const List<String> israelEn = [
  "Tel Aviv",
  "Jerusalem",
  "Haifa",
  "Be'er Sheva",
  "Eilat",
  "Nazareth",
  "Tiberias",
  "Ashdod",
  "Ashkelon",
  "Netanya",
  "Ramat Gan",
  "Herzliya",
  "Caesarea",
  "Acre",
  "Safed",
  "Dead Sea",
  "Sea of Galilee",
  "Negev",
  "Galilee",
  "Carmel",
  "Jordan",
  "Judean Desert",
  "Western Wall",
  "Temple Mount",
  "Mahane Yehuda Market",
  "Dizengoff",
  "Sarona",
  "Jaffa",
  "Israel Museum",
  "Yad Vashem",
  "Knesset",
  "IDF",
  "Star of David",
  "Israeli flag",
  "Hatikvah",
  "Shekel",
  "Falafel",
  "Shawarma",
  "Sabich",
  "Hummus",
  "Kibbutz",
  "Moshav",
  "Settlement",
  "Ulpan",
  "Matriculation",
  "Technion",
  "Tel Aviv University",
  "Hebrew University",
  "Shin Bet",
  "Mossad",
  "Golan",
  "Hermon",
  "Masada",
  "Caesarea",
  "City of David",
  "Israel Railways",
  "Coastal Highway",
  "Tunnel",
  "Carmel Market",
  "Stock Exchange",
  "Iron Dome",
  "Air Force",
  "Golda",
  "Ben Gurion",
  "Herzl",
  "Rabin",
  "Market",
  "Reserves",
  "Independence Day",
  "Memorial Day",
  "Hanukkah",
  "Passover",
  "Rosh Hashanah",
  "Yom Kippur",
  "Purim",
  "Shabbat",
  "Hebrew",
  "State",
  "Aliyah"
];

