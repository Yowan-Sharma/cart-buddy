import re
from difflib import SequenceMatcher

slurs = ["chutiya", "madarchod", "gandu", "bhosdike", "fuck", "shit"]

def clean_word(word):
    # Remove repeated chars: chuuutiya -> chutiya
    return re.sub(r'(.)\1+', r'\1', word)

def is_similar(input_word, threshold=0.8):
    cleaned = clean_word(input_word.lower())
    for slur in slurs:
        if SequenceMatcher(None, cleaned, slur).ratio() >= threshold:
            return True, slur
        if SequenceMatcher(None, input_word.lower(), slur).ratio() >= threshold:
            return True, slur
    return False, None

print(is_similar("chuuutiyaa"))
print(is_similar("fack"))
print(is_similar("ganduu"))
print(is_similar("bhosdi"))
print(is_similar("bitch"))
