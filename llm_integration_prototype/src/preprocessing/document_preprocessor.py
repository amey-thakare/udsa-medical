import re
import unicodedata
from dataclasses import dataclass, field
from typing import List


@dataclass
class PreprocessedDocument:
    """
    Container holding both original raw OCR text and normalized text.
    Preserving raw_text ensures every extracted measurement remains traceable to source.
    """
    raw_text: str
    cleaned_text: str
    line_count: int
    character_count: int
    normalization_notes: List[str] = field(default_factory=list)


class DocumentPreprocessor:
    """
    Performs conservative text normalization on OCR transcription outputs.
    
    Guiding Principle:
    NEVER modify numbers, decimal separators, slash separators, units, dates, or clinical
    keywords. Clean only non-printable control characters, duplicate spacing, and abnormal
    Unicode encoding artifacts.
    """

    def __init__(self):
        # Character mappings for safe normalization
        self.unicode_replacements = {
            "\u00A0": " ",  # Non-breaking space
            "\u200B": "",   # Zero-width space
            "\u200C": "",   # Zero-width non-joiner
            "\u200D": "",   # Zero-width joiner
            "\uFEFF": "",   # Byte order mark
            "\u2018": "'",  # Smart single quote left
            "\u2019": "'",  # Smart single quote right
            "\u201C": '"',  # Smart double quote left
            "\u201D": '"',  # Smart double quote right
            "\u2013": "-",  # En-dash
            "\u2014": "-",  # Em-dash
            "\u2212": "-",  # Minus sign
        }

    def preprocess(self, ocr_text: str) -> PreprocessedDocument:
        """
        Cleans and normalizes OCR text while strictly maintaining clinical integrity.
        """
        if not ocr_text:
            return PreprocessedDocument(
                raw_text="",
                cleaned_text="",
                line_count=0,
                character_count=0,
                normalization_notes=["Empty document received"],
            )

        raw_text = ocr_text
        notes: List[str] = []

        # 1. Unicode normalization (NFKC)
        normalized = unicodedata.normalize("NFKC", raw_text)
        if normalized != raw_text:
            notes.append("Applied NFKC Unicode normalization")

        # 2. Character replacements (non-breaking spaces, smart quotes, dashes)
        cleaned = normalized
        for old_char, new_char in self.unicode_replacements.items():
            if old_char in cleaned:
                cleaned = cleaned.replace(old_char, new_char)
                notes.append(f"Replaced Unicode artifact U+{ord(old_char):04X}")

        # 3. Standardize line endings (\r\n -> \n)
        if "\r" in cleaned:
            cleaned = cleaned.replace("\r\n", "\n").replace("\r", "\n")
            notes.append("Standardized CRLF to LF")

        # 4. Remove unprintable ASCII control characters (keeping \n and \t)
        cleaned = re.sub(r"[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]", "", cleaned)

        # 5. Normalize trailing whitespace on each line, collapse multiple spaces (not newlines)
        lines = []
        for line in cleaned.split("\n"):
            # Collapse multiple inline spaces/tabs to a single space
            collapsed_line = re.sub(r"[ \t]+", " ", line).strip()
            lines.append(collapsed_line)

        # 6. Reconstruct text, collapsing 3+ consecutive newlines to 2 (paragraph break)
        cleaned_text = "\n".join(lines)
        cleaned_text = re.sub(r"\n{3,}", "\n\n", cleaned_text).strip()

        line_count = len([ln for ln in lines if ln])
        character_count = len(cleaned_text)

        return PreprocessedDocument(
            raw_text=raw_text,
            cleaned_text=cleaned_text,
            line_count=line_count,
            character_count=character_count,
            normalization_notes=notes,
        )
