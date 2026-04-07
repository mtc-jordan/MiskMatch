"""
MiskMatch — Game Engine Models
Defines all 17 game types, question banks, game states, and turns.

Game categories:
  GET_TO_KNOW    — Qalb Quiz, Would You Rather, Finish My Sentence, Values Map
  ISLAMIC        — Islamic Trivia, Quran Ayah, Geography Race, Hadith Match
  CREATIVE       — Build Our Story, Dream Home, Time Capsule
  TRUST          — Honesty Box, Priority Ranking, Love Languages, 36 Questions
  WALI_INCLUSIVE — Family Trivia, Deal or No Deal

All 1,700+ questions are scholar-reviewed.
Games unlock progressively over 35 days.
"""

from datetime import datetime, timezone, timedelta
from enum import Enum
from typing import Any, Optional
from uuid import uuid4

# ─────────────────────────────────────────────
# GAME TYPE REGISTRY
# ─────────────────────────────────────────────

class GameCategory(str, Enum):
    GET_TO_KNOW    = "get_to_know"
    ISLAMIC        = "islamic"
    CREATIVE       = "creative"
    TRUST          = "trust"
    WALI_INCLUSIVE = "wali_inclusive"


class GameType(str, Enum):
    # Get to Know
    QALB_QUIZ        = "qalb_quiz"
    WOULD_YOU_RATHER = "would_you_rather"
    FINISH_SENTENCE  = "finish_sentence"
    VALUES_MAP       = "values_map"
    # Islamic
    ISLAMIC_TRIVIA   = "islamic_trivia"
    QURAN_AYAH       = "quran_ayah"
    GEOGRAPHY_RACE   = "geography_race"
    HADITH_MATCH     = "hadith_match"
    # Creative
    BUILD_OUR_STORY  = "build_our_story"
    DREAM_HOME       = "dream_home"
    TIME_CAPSULE     = "time_capsule"
    # Trust
    HONESTY_BOX      = "honesty_box"
    PRIORITY_RANKING = "priority_ranking"
    LOVE_LANGUAGES   = "love_languages"
    THIRTY_SIX_Q     = "thirty_six_questions"
    # Wali-Inclusive
    FAMILY_TRIVIA    = "family_trivia"
    DEAL_OR_NO_DEAL  = "deal_or_no_deal"


class GameMode(str, Enum):
    ASYNC_TURN   = "async_turn"    # Alternating turns, no time pressure
    REAL_TIME    = "real_time"     # Simultaneous answers, live reveal
    COLLABORATIVE= "collaborative" # Both build together
    TIMER_SEALED = "timer_sealed"  # Sealed until a date (Time Capsule)


class GameStatus(str, Enum):
    NOT_STARTED  = "not_started"
    IN_PROGRESS  = "in_progress"
    AWAITING_TURN= "awaiting_turn"
    SEALED       = "sealed"        # Time Capsule only
    COMPLETED    = "completed"
    ABANDONED    = "abandoned"


# ─────────────────────────────────────────────
# GAME REGISTRY — metadata per game type
# ─────────────────────────────────────────────

GAME_REGISTRY: dict[str, dict] = {
    GameType.QALB_QUIZ: {
        "name":        "Qalb Quiz",
        "name_ar":     "اختبار القلب",
        "description": "Discover each other's hearts through personal questions about values and character.",
        "category":    GameCategory.GET_TO_KNOW,
        "mode":        GameMode.ASYNC_TURN,
        "unlock_day":  1,
        "turns":       20,
        "icon":        "🫀",
    },
    GameType.WOULD_YOU_RATHER: {
        "name":        "Would You Rather",
        "name_ar":     "أيهما تفضل",
        "description": "Islamic-themed dilemmas that reveal priorities and values.",
        "category":    GameCategory.GET_TO_KNOW,
        "mode":        GameMode.REAL_TIME,
        "unlock_day":  1,
        "turns":       15,
        "icon":        "⚖️",
    },
    GameType.FINISH_SENTENCE: {
        "name":        "Finish My Sentence",
        "name_ar":     "أكمل الجملة",
        "description": "Complete open-ended sentences to reveal your inner world.",
        "category":    GameCategory.GET_TO_KNOW,
        "mode":        GameMode.ASYNC_TURN,
        "unlock_day":  3,
        "turns":       20,
        "icon":        "✍️",
    },
    GameType.VALUES_MAP: {
        "name":        "Values Map",
        "name_ar":     "خريطة القيم",
        "description": "Map out and compare your core life values side by side.",
        "category":    GameCategory.GET_TO_KNOW,
        "mode":        GameMode.COLLABORATIVE,
        "unlock_day":  5,
        "turns":       10,
        "icon":        "🗺️",
    },
    GameType.ISLAMIC_TRIVIA: {
        "name":        "Islamic Trivia Duel",
        "name_ar":     "مسابقة إسلامية",
        "description": "Test each other's Islamic knowledge in a friendly duel.",
        "category":    GameCategory.ISLAMIC,
        "mode":        GameMode.REAL_TIME,
        "unlock_day":  1,
        "turns":       20,
        "icon":        "🌙",
    },
    GameType.QURAN_AYAH: {
        "name":        "Quran Ayah Completion",
        "name_ar":     "إكمال الآية",
        "description": "Complete ayahs from the Quran — share which surahs move you.",
        "category":    GameCategory.ISLAMIC,
        "mode":        GameMode.ASYNC_TURN,
        "unlock_day":  3,
        "turns":       15,
        "icon":        "📖",
    },
    GameType.GEOGRAPHY_RACE: {
        "name":        "Islamic Geography Race",
        "name_ar":     "سباق الجغرافيا الإسلامية",
        "description": "Race to name Islamic landmarks, scholars, and holy cities.",
        "category":    GameCategory.ISLAMIC,
        "mode":        GameMode.REAL_TIME,
        "unlock_day":  7,
        "turns":       15,
        "icon":        "🕌",
    },
    GameType.HADITH_MATCH: {
        "name":        "Hadith Match",
        "name_ar":     "مطابقة الحديث",
        "description": "Match hadiths to their themes — share your favourite narrations.",
        "category":    GameCategory.ISLAMIC,
        "mode":        GameMode.ASYNC_TURN,
        "unlock_day":  7,
        "turns":       10,
        "icon":        "📜",
    },
    GameType.BUILD_OUR_STORY: {
        "name":        "Build Our Story",
        "name_ar":     "ابنِ قصتنا",
        "description": "Take turns writing chapters of your imagined shared future.",
        "category":    GameCategory.CREATIVE,
        "mode":        GameMode.ASYNC_TURN,
        "unlock_day":  10,
        "turns":       10,
        "icon":        "📚",
    },
    GameType.DREAM_HOME: {
        "name":        "Dream Home Designer",
        "name_ar":     "مصمم بيت الأحلام",
        "description": "Collaboratively design your dream Islamic home, room by room.",
        "category":    GameCategory.CREATIVE,
        "mode":        GameMode.COLLABORATIVE,
        "unlock_day":  14,
        "turns":       8,
        "icon":        "🏡",
    },
    GameType.TIME_CAPSULE: {
        "name":        "Time Capsule",
        "name_ar":     "كبسولة الزمن",
        "description": "Write heartfelt notes sealed for 30 days — opened together at the end.",
        "category":    GameCategory.CREATIVE,
        "mode":        GameMode.TIMER_SEALED,
        "unlock_day":  21,
        "turns":       5,
        "icon":        "⏳",
        "seal_days":   30,
    },
    GameType.HONESTY_BOX: {
        "name":        "Honesty Box",
        "name_ar":     "صندوق الصدق",
        "description": "Anonymous-feeling questions answered honestly — revealed together.",
        "category":    GameCategory.TRUST,
        "mode":        GameMode.ASYNC_TURN,
        "unlock_day":  14,
        "turns":       20,
        "icon":        "🔓",
    },
    GameType.PRIORITY_RANKING: {
        "name":        "Priority Ranking",
        "name_ar":     "ترتيب الأولويات",
        "description": "Rank life priorities and see how they align with your match.",
        "category":    GameCategory.TRUST,
        "mode":        GameMode.REAL_TIME,
        "unlock_day":  7,
        "turns":       5,
        "icon":        "📊",
    },
    GameType.LOVE_LANGUAGES: {
        "name":        "Love Languages (Islamic)",
        "name_ar":     "لغات المحبة الإسلامية",
        "description": "Discover each other's love languages through an Islamic lens.",
        "category":    GameCategory.TRUST,
        "mode":        GameMode.ASYNC_TURN,
        "unlock_day":  10,
        "turns":       15,
        "icon":        "💝",
    },
    GameType.THIRTY_SIX_Q: {
        "name":        "36 Questions",
        "name_ar":     "٣٦ سؤالاً",
        "description": "The scientifically-designed closeness questions, adapted for Islamic courtship.",
        "category":    GameCategory.TRUST,
        "mode":        GameMode.ASYNC_TURN,
        "unlock_day":  21,
        "turns":       36,
        "icon":        "💬",
    },
    GameType.FAMILY_TRIVIA: {
        "name":        "Family Trivia",
        "name_ar":     "معلومات عائلية",
        "description": "Fun trivia about your families — wali included! Everyone plays together.",
        "category":    GameCategory.WALI_INCLUSIVE,
        "mode":        GameMode.REAL_TIME,
        "unlock_day":  5,
        "turns":       15,
        "icon":        "👨‍👩‍👧",
    },
    GameType.DEAL_OR_NO_DEAL: {
        "name":        "Deal or No Deal (Islamic)",
        "name_ar":     "صفقة أم لا",
        "description": "Negotiate marriage expectations openly with family guidance.",
        "category":    GameCategory.WALI_INCLUSIVE,
        "mode":        GameMode.COLLABORATIVE,
        "unlock_day":  14,
        "turns":       12,
        "icon":        "🤝",
    },
}


# ─────────────────────────────────────────────
# QUESTION BANKS  (sample — prod loads from DB)
# ─────────────────────────────────────────────

QUESTION_BANKS: dict[str, list[dict]] = {

    GameType.QALB_QUIZ: [
        {"id": "qq001", "text": "What quality do you value most in a spouse?", "type": "open"},
        {"id": "qq002", "text": "How do you handle disagreements with family?", "type": "open"},
        {"id": "qq003", "text": "What does a successful marriage look like to you?", "type": "open"},
        {"id": "qq004", "text": "How important is proximity to your parents after marriage?", "type": "open"},
        {"id": "qq005", "text": "What is your biggest source of comfort in difficult times?", "type": "open"},
        {"id": "qq006", "text": "How do you practise gratitude (shukr) in daily life?", "type": "open"},
        {"id": "qq007", "text": "What role does Quran play in your daily routine?", "type": "open"},
        {"id": "qq008", "text": "Describe your ideal Friday (Jumu'ah) as a family.", "type": "open"},
        {"id": "qq009", "text": "What is one Islamic habit you want to build together?", "type": "open"},
        {"id": "qq010", "text": "How do you show love and appreciation to those close to you?", "type": "open"},
    ],

    GameType.WOULD_YOU_RATHER: [
        {"id": "wyr001", "a": "Live near a masjid", "b": "Live near family", "type": "choice"},
        {"id": "wyr002", "a": "Raise 3 children with minimal wealth", "b": "Raise 1 child with abundance", "type": "choice"},
        {"id": "wyr003", "a": "Make Hajj early in marriage", "b": "Buy a home first", "type": "choice"},
        {"id": "wyr004", "a": "Memorise one Juz of Quran together", "b": "Travel to an Islamic country together", "type": "choice"},
        {"id": "wyr005", "a": "Host family every Friday", "b": "Have quiet family evenings at home", "type": "choice"},
        {"id": "wyr006", "a": "Spouse who is deeply knowledgeable in deen", "b": "Spouse who is deeply caring and patient", "type": "choice"},
        {"id": "wyr007", "a": "Live in a Muslim-majority country", "b": "Build an Islamic community where you are", "type": "choice"},
        {"id": "wyr008", "a": "Own a small halal business together", "b": "Both work in stable separate careers", "type": "choice"},
    ],

    GameType.FINISH_SENTENCE: [
        {"id": "fs001", "stem": "My idea of a perfect Sunday morning is…", "type": "completion"},
        {"id": "fs002", "stem": "I feel most at peace when…", "type": "completion"},
        {"id": "fs003", "stem": "In our home, I hope we always…", "type": "completion"},
        {"id": "fs004", "stem": "The thing I'm most working on in myself is…", "type": "completion"},
        {"id": "fs005", "stem": "When I think of raising children, I imagine…", "type": "completion"},
        {"id": "fs006", "stem": "My relationship with my parents is…", "type": "completion"},
        {"id": "fs007", "stem": "I show love by…", "type": "completion"},
        {"id": "fs008", "stem": "A home filled with barakah looks like…", "type": "completion"},
        {"id": "fs009", "stem": "In sha' Allah, in ten years I hope we are…", "type": "completion"},
        {"id": "fs010", "stem": "The hadith or ayah I return to most is…", "type": "completion"},
    ],

    GameType.ISLAMIC_TRIVIA: [
        {"id": "it001", "q": "How many surahs are in the Quran?", "a": "114", "type": "mcq",
         "options": ["99", "114", "120", "108"]},
        {"id": "it002", "q": "Which surah is called 'the heart of the Quran'?", "a": "Ya-Sin",
         "type": "mcq", "options": ["Al-Fatiha", "Ya-Sin", "Al-Baqarah", "Al-Kahf"]},
        {"id": "it003", "q": "How many times is the word 'salah' (prayer) mentioned in the Quran?", "a": "67",
         "type": "mcq", "options": ["5", "50", "67", "100"]},
        {"id": "it004", "q": "Which prophet is mentioned most in the Quran?", "a": "Musa (AS)",
         "type": "mcq", "options": ["Ibrahim (AS)", "Isa (AS)", "Musa (AS)", "Muhammad (SAW)"]},
        {"id": "it005", "q": "What is the meaning of the word 'Islam'?", "a": "Submission/Peace",
         "type": "mcq", "options": ["Faith", "Submission/Peace", "Prayer", "Guidance"]},
        {"id": "it006", "q": "In which month was the Quran first revealed?", "a": "Ramadan",
         "type": "mcq", "options": ["Muharram", "Sha'ban", "Ramadan", "Dhul Hijjah"]},
        {"id": "it007", "q": "How many pillars of Islam are there?", "a": "5",
         "type": "mcq", "options": ["4", "5", "6", "7"]},
        {"id": "it008", "q": "Which city is Al-Masjid al-Aqsa located in?", "a": "Jerusalem",
         "type": "mcq", "options": ["Makkah", "Madinah", "Jerusalem", "Cairo"]},
    ],

    GameType.QURAN_AYAH: [
        {"id": "qa001", "stem": "Complete: 'Indeed, with hardship...'", "completion": "will be ease. (94:6)", "surah": "Ash-Sharh"},
        {"id": "qa002", "stem": "Complete: 'And He is with you...'", "completion": "wherever you are. (57:4)", "surah": "Al-Hadid"},
        {"id": "qa003", "stem": "Complete: 'So remember Me...'", "completion": "and I will remember you. (2:152)", "surah": "Al-Baqarah"},
        {"id": "qa004", "stem": "Complete: 'Verily, Allah does not change...'", "completion": "the condition of a people until they change what is in themselves. (13:11)", "surah": "Ar-Ra'd"},
        {"id": "qa005", "stem": "Complete: 'And among His signs is that...'", "completion": "He created for you mates from among yourselves. (30:21)", "surah": "Ar-Rum"},
    ],

    GameType.THIRTY_SIX_Q: [
        # Set I — Closeness building
        {"id": "36q001", "set": 1, "text": "Given the choice of anyone in the world, who would you want as a dinner guest?", "type": "open"},
        {"id": "36q002", "set": 1, "text": "Would you like to be famous? In what way?", "type": "open"},
        {"id": "36q003", "set": 1, "text": "Before making a telephone call, do you ever rehearse what you are going to say? Why?", "type": "open"},
        {"id": "36q004", "set": 1, "text": "What would constitute a 'perfect' day for you?", "type": "open"},
        {"id": "36q005", "set": 1, "text": "When did you last sing to yourself? To someone else?", "type": "open"},
        {"id": "36q006", "set": 1, "text": "If you could live to the age of 90, what would you prefer to retain — the mind or body of a 30-year-old?", "type": "open"},
        {"id": "36q007", "set": 1, "text": "Do you have a secret hunch about how you will die?", "type": "open"},
        {"id": "36q008", "set": 1, "text": "Name three things you and your match appear to have in common.", "type": "open"},
        {"id": "36q009", "set": 1, "text": "For what in your life do you feel most grateful?", "type": "open"},
        {"id": "36q010", "set": 1, "text": "If you could change anything about the way you were raised, what would it be?", "type": "open"},
        {"id": "36q011", "set": 1, "text": "Take four minutes and tell your match your life story in as much detail as possible.", "type": "open"},
        {"id": "36q012", "set": 1, "text": "If you could wake up tomorrow having gained any quality or ability, what would it be?", "type": "open"},
        # Set II — Deeper connection
        {"id": "36q013", "set": 2, "text": "If a crystal ball could tell you the truth about yourself, your life, or your future, what would you want to know?", "type": "open"},
        {"id": "36q014", "set": 2, "text": "Is there something that you've dreamed of doing for a long time? Why haven't you done it?", "type": "open"},
        {"id": "36q015", "set": 2, "text": "What is the greatest accomplishment of your life?", "type": "open"},
        {"id": "36q016", "set": 2, "text": "What do you value most in a friendship?", "type": "open"},
        {"id": "36q017", "set": 2, "text": "What is your most treasured memory?", "type": "open"},
        {"id": "36q018", "set": 2, "text": "What is your most terrible memory?", "type": "open"},
        {"id": "36q019", "set": 2, "text": "If you knew that in one year you would die suddenly, would you change anything about the way you are living now?", "type": "open"},
        {"id": "36q020", "set": 2, "text": "What does friendship mean to you?", "type": "open"},
        {"id": "36q021", "set": 2, "text": "What roles do love and affection play in your life?", "type": "open"},
        {"id": "36q022", "set": 2, "text": "Share something you consider a positive characteristic of your match. Share five items total.", "type": "open"},
        {"id": "36q023", "set": 2, "text": "How close and warm is your family? Do you feel your childhood was happier than most?", "type": "open"},
        {"id": "36q024", "set": 2, "text": "How do you feel about your relationship with your mother?", "type": "open"},
        # Set III — Vulnerability
        {"id": "36q025", "set": 3, "text": "Make three true 'we' statements each. For example, 'We are both in this room feeling...'", "type": "open"},
        {"id": "36q026", "set": 3, "text": "Complete this sentence: 'I wish I had someone with whom I could share...'", "type": "open"},
        {"id": "36q027", "set": 3, "text": "If you were going to become close friends with your match, what would be important for them to know?", "type": "open"},
        {"id": "36q028", "set": 3, "text": "Tell your match what you like about them — be very honest, saying things you might not say to someone you've just met.", "type": "open"},
        {"id": "36q029", "set": 3, "text": "Share with your match an embarrassing moment in your life.", "type": "open"},
        {"id": "36q030", "set": 3, "text": "When did you last cry in front of another person? By yourself?", "type": "open"},
        {"id": "36q031", "set": 3, "text": "Tell your match something that you like about them already.", "type": "open"},
        {"id": "36q032", "set": 3, "text": "What, if anything, is too serious to be joked about?", "type": "open"},
        {"id": "36q033", "set": 3, "text": "If you were to die this evening with no opportunity to communicate with anyone, what would you most regret not having told someone?", "type": "open"},
        {"id": "36q034", "set": 3, "text": "Your house, containing everything you own, catches fire. After saving your loved ones, you have time to safely make a final dash to save any one item. What would it be?", "type": "open"},
        {"id": "36q035", "set": 3, "text": "Of all the people in your family, whose death would you find most disturbing?", "type": "open"},
        {"id": "36q036", "set": 3, "text": "Share a personal problem and ask your partner's advice on how they might handle it.", "type": "open"},
    ],

    GameType.PRIORITY_RANKING: [
        {"id": "pr001", "items": ["Deen", "Career", "Family", "Health", "Wealth", "Community"], "type": "ranking"},
        {"id": "pr002", "items": ["Prayer", "Quran recitation", "Fasting", "Charity", "Seeking knowledge", "Dhikr"], "type": "ranking"},
        {"id": "pr003", "items": ["Own home", "Hajj", "Children's education", "Travel", "Investment", "Parents' care"], "type": "ranking"},
        {"id": "pr004", "items": ["Kindness", "Loyalty", "Ambition", "Humility", "Wisdom", "Generosity"], "type": "ranking"},
        {"id": "pr005", "items": ["Living near family", "Living in Islamic country", "Financial security", "Community involvement", "Career growth", "Adventure"], "type": "ranking"},
    ],

    GameType.DEAL_OR_NO_DEAL: [
        {"id": "dnd001", "topic": "Wife continuing to work after marriage", "type": "negotiation"},
        {"id": "dnd002", "topic": "Living arrangement (nuclear vs extended family)", "type": "negotiation"},
        {"id": "dnd003", "topic": "Mahr amount and payment timeline", "type": "negotiation"},
        {"id": "dnd004", "topic": "Financial management — joint or separate accounts", "type": "negotiation"},
        {"id": "dnd005", "topic": "Number of children and spacing", "type": "negotiation"},
        {"id": "dnd006", "topic": "International relocation for work", "type": "negotiation"},
        {"id": "dnd007", "topic": "Homeschooling vs Islamic school vs state school", "type": "negotiation"},
        {"id": "dnd008", "topic": "Wife's hijab style — family expectations", "type": "negotiation"},
        {"id": "dnd009", "topic": "Frequency of visits to each family", "type": "negotiation"},
        {"id": "dnd010", "topic": "Pet ownership in the home", "type": "negotiation"},
        {"id": "dnd011", "topic": "Social media presence as a couple", "type": "negotiation"},
        {"id": "dnd012", "topic": "How decisions are made — consultation process", "type": "negotiation"},
    ],

    GameType.TIME_CAPSULE: [
        {"id": "tc001", "prompt": "Write a du'a for your future family.", "type": "letter"},
        {"id": "tc002", "prompt": "Describe the home you hope to build together in five years.", "type": "letter"},
        {"id": "tc003", "prompt": "What are three promises you want to make to your future spouse?", "type": "letter"},
        {"id": "tc004", "prompt": "Write about the moment you felt this could be the right person.", "type": "letter"},
        {"id": "tc005", "prompt": "What do you want your children to know about how you met?", "type": "letter"},
    ],

    GameType.HONESTY_BOX: [
        {"id": "hb001", "text": "What is one thing you've never told your family about yourself?", "type": "open"},
        {"id": "hb002", "text": "What is your biggest fear about marriage?", "type": "open"},
        {"id": "hb003", "text": "Is there anything in your past you feel a potential spouse should know?", "type": "open"},
        {"id": "hb004", "text": "What do you find hardest to forgive?", "type": "open"},
        {"id": "hb005", "text": "What habit of yours would most annoy a spouse?", "type": "open"},
        {"id": "hb006", "text": "What does your best friend say is your biggest flaw?", "type": "open"},
        {"id": "hb007", "text": "What is something you feel guilty about?", "type": "open"},
        {"id": "hb008", "text": "What expectation do you have of marriage that may be unrealistic?", "type": "open"},
    ],

    GameType.LOVE_LANGUAGES: [
        {"id": "ll001", "text": "How do you feel most loved — through words, acts, gifts, time, or touch?", "type": "open"},
        {"id": "ll002", "text": "What did your parents do that made you feel valued?", "type": "open"},
        {"id": "ll003", "text": "What small gesture from a spouse would mean the world to you?", "type": "open"},
        {"id": "ll004", "text": "How do you naturally show love to those you care about?", "type": "open"},
        {"id": "ll005", "text": "What does quality time mean to you in a marriage?", "type": "open"},
    ],

    GameType.BUILD_OUR_STORY: [
        {"id": "bos001", "prompt": "Chapter 1: The morning after our nikah begins with…", "type": "story_turn"},
        {"id": "bos002", "prompt": "Chapter 2: Our first home together looks and feels like…", "type": "story_turn"},
        {"id": "bos003", "prompt": "Chapter 3: One year in, we celebrate by…", "type": "story_turn"},
        {"id": "bos004", "prompt": "Chapter 4: When we disagree, we handle it by…", "type": "story_turn"},
        {"id": "bos005", "prompt": "Chapter 5: Our children see parents who…", "type": "story_turn"},
    ],

    GameType.FAMILY_TRIVIA: [
        {"id": "ft001", "q": "Name one thing your family is known for.", "type": "open"},
        {"id": "ft002", "q": "What is a tradition your family practises on Eid?", "type": "open"},
        {"id": "ft003", "q": "What is your family's favourite meal?", "type": "open"},
        {"id": "ft004", "q": "What do your parents say about marriage?", "type": "open"},
        {"id": "ft005", "q": "What is something your family taught you that you'll pass on?", "type": "open"},
    ],

    GameType.VALUES_MAP: [
        {"id": "vm001", "value": "Family", "question": "What does family mean to you in one sentence?", "type": "value_statement"},
        {"id": "vm002", "value": "Deen", "question": "How central is deen to your daily decisions?", "type": "value_statement"},
        {"id": "vm003", "value": "Career", "question": "What role should career play after marriage?", "type": "value_statement"},
        {"id": "vm004", "value": "Community", "question": "How involved do you want to be in the Muslim community?", "type": "value_statement"},
        {"id": "vm005", "value": "Growth", "question": "How do you see yourself growing in the next decade?", "type": "value_statement"},
    ],

    GameType.HADITH_MATCH: [
        {"id": "hm001", "hadith": "The best of you are those who are best to their wives.", "theme": "Marriage", "narrator": "At-Tirmidhi"},
        {"id": "hm002", "hadith": "None of you truly believes until he loves for his brother what he loves for himself.", "theme": "Brotherhood", "narrator": "Bukhari"},
        {"id": "hm003", "hadith": "The strong person is not the one who can wrestle, but the one who controls themselves when angry.", "theme": "Character", "narrator": "Bukhari"},
        {"id": "hm004", "hadith": "Whoever believes in Allah and the Last Day, let him speak good or remain silent.", "theme": "Speech", "narrator": "Bukhari & Muslim"},
        {"id": "hm005", "hadith": "The world is but a provision, and the best provision of this world is a righteous woman.", "theme": "Spouse", "narrator": "Muslim"},
    ],

    GameType.GEOGRAPHY_RACE: [
        {"id": "gr001", "q": "In which city is the Masjid al-Nabawi located?", "a": "Madinah", "type": "mcq", "options": ["Makkah", "Madinah", "Riyadh", "Jeddah"]},
        {"id": "gr002", "q": "Which country has the world's largest Muslim population?", "a": "Indonesia", "type": "mcq", "options": ["Pakistan", "Bangladesh", "Egypt", "Indonesia"]},
        {"id": "gr003", "q": "In which modern country is the ancient Islamic city of Cordoba?", "a": "Spain", "type": "mcq", "options": ["Morocco", "Turkey", "Spain", "Portugal"]},
        {"id": "gr004", "q": "Which sea did Prophet Musa (AS) part?", "a": "Red Sea", "type": "mcq", "options": ["Mediterranean", "Dead Sea", "Red Sea", "Arabian Sea"]},
        {"id": "gr005", "q": "Where is the first university in history, Al-Qarawiyyin, located?", "a": "Fez, Morocco", "type": "mcq", "options": ["Cairo", "Baghdad", "Fez, Morocco", "Cordoba"]},
    ],

    GameType.DREAM_HOME: [
        {"id": "dh001", "room": "Entrance", "prompt": "Describe what greets guests as they enter our home.", "type": "collaborative"},
        {"id": "dh002", "room": "Living Room", "prompt": "What does our family living space feel like?", "type": "collaborative"},
        {"id": "dh003", "room": "Kitchen", "prompt": "What kind of meals and gatherings happen in our kitchen?", "type": "collaborative"},
        {"id": "dh004", "room": "Prayer Room", "prompt": "Describe our dedicated space for salah and Quran.", "type": "collaborative"},
        {"id": "dh005", "room": "Garden", "prompt": "Describe the outdoor space where our children play.", "type": "collaborative"},
    ],
}


# ─────────────────────────────────────────────
# UNLOCK SCHEDULE — which games unlock on which day
# ─────────────────────────────────────────────

def get_unlocked_games(match_day: int) -> list[str]:
    """Return list of game types unlocked by match_day."""
    return [
        gtype
        for gtype, meta in GAME_REGISTRY.items()
        if meta["unlock_day"] <= match_day
    ]


def get_day_1_games() -> list[str]:
    return get_unlocked_games(1)


# ─────────────────────────────────────────────
# GAME STATE HELPERS
# ─────────────────────────────────────────────

def build_initial_state(
    game_type: str,
    sender_id: str,
    receiver_id: str,
) -> dict:
    """
    Build the initial game state dict stored in Match.game_states[game_type].
    """
    meta = GAME_REGISTRY.get(game_type, {})
    questions = QUESTION_BANKS.get(game_type, [])

    state: dict[str, Any] = {
        "status":       GameStatus.IN_PROGRESS,
        "started_at":   datetime.now(timezone.utc).isoformat(),
        "current_turn": sender_id,     # sender goes first
        "turn_number":  0,
        "turns":        [],
        "questions":    questions,
        "current_q_idx": 0,
        "scores":       {sender_id: 0, receiver_id: 0},
        "completed_at": None,
    }

    # Time Capsule special state
    if game_type == GameType.TIME_CAPSULE:
        seal_days = meta.get("seal_days", 30)
        state["sealed"]    = False
        state["sealed_at"] = None
        state["opens_at"]  = None
        state["seal_days"] = seal_days
        state["status"]    = GameStatus.IN_PROGRESS

    return state


def next_turn(state: dict, current_user_id: str, other_user_id: str) -> dict:
    """Advance turn to the other player."""
    state["current_turn"] = (
        other_user_id
        if state["current_turn"] == current_user_id
        else current_user_id
    )
    state["turn_number"] += 1
    state["current_q_idx"] = min(
        state["current_q_idx"] + 1,
        len(state["questions"]) - 1,
    )
    return state


def is_game_complete(state: dict, game_type: str) -> bool:
    """Check if a game has reached completion."""
    meta = GAME_REGISTRY.get(game_type, {})
    max_turns = meta.get("turns", 10)
    return state["turn_number"] >= max_turns


def seal_time_capsule(state: dict) -> dict:
    """Seal the Time Capsule — opens in 30 days."""
    now = datetime.now(timezone.utc)
    seal_days = state.get("seal_days", 30)
    state["sealed"]    = True
    state["sealed_at"] = now.isoformat()
    state["opens_at"]  = (now + timedelta(days=seal_days)).isoformat()
    state["status"]    = GameStatus.SEALED
    return state


def is_capsule_open(state: dict) -> bool:
    """Check if a sealed Time Capsule can be opened now."""
    opens_at_str = state.get("opens_at")
    if not opens_at_str:
        return False
    opens_at = datetime.fromisoformat(opens_at_str)
    return datetime.now(timezone.utc) >= opens_at
