import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "slurs.db")

def setup_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS slurs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT UNIQUE NOT NULL,
            language TEXT,
            severity TEXT
        )
    ''')
    initial_slurs = [
        ("chutiya",     "hindi/punjabi", "severe"),
        ("bhosdike",    "hindi",         "severe"),
        ("madarchod",   "hindi",         "severe"),
        ("behenchod",   "hindi",         "severe"),
        ("bc",          "hinglish",      "moderate"),
        ("mc",          "hinglish",      "moderate"),
        ("gandu",       "hindi",         "moderate"),
        ("harami",      "hindi",         "mild"),
        ("dalla",       "punjabi",       "severe"),
        ("phuddu",      "punjabi",       "severe"),
        ("teri maa",    "hindi",         "severe"),
        ("fuck",        "english",       "severe"),
        ("shit",        "english",       "moderate"),
        ("bitch",       "english",       "severe"),
        ("asshole",     "english",       "severe"),
        ("dick",        "english",       "severe"),
        ("pussy",       "english",       "severe"),
        ("cunt",        "english",       "severe"),
        ("bastard",     "english",       "severe"),
        ("slut",        "english",       "severe"),
        ("whore",       "english",       "severe"),
        ("motherfucker","english",       "severe"),
        ("nigga",       "english",       "severe"),
        ("nigger",      "english",       "severe"),
        ("faggot",      "english",       "severe"),
        ("retard",      "english",       "severe"),
    ]
    cursor.executemany(
        "INSERT OR IGNORE INTO slurs (word, language, severity) VALUES (?, ?, ?)",
        initial_slurs
    )
    conn.commit()
    conn.close()


def load_slurs():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT word, severity FROM slurs")
    slurs = {row[0]: row[1] for row in cursor.fetchall()}
    conn.close()
    return slurs


def add_slur(word, language="unknown", severity="moderate"):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO slurs (word, language, severity) VALUES (?, ?, ?)",
            (word.lower(), language, severity)
        )
        conn.commit()
    except sqlite3.IntegrityError:
        pass
    finally:
        conn.close()

# Run once on module load
setup_db()
