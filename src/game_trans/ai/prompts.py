"""System prompts and JSON response schemas for Gemini structured output."""

from __future__ import annotations

LANGUAGE_NAMES = {
    "ko": "Korean", "en": "English", "ja": "Japanese", "zh": "Chinese", "es": "Spanish",
    "pt": "Portuguese", "fr": "French", "de": "German", "ru": "Russian", "id": "Indonesian",
    "th": "Thai", "vi": "Vietnamese", "tl": "Filipino", "ar": "Arabic", "tr": "Turkish",
}

TONE_HINTS = {
    "casual": "Use natural, casual gamer speech (short, friendly, slang where natural).",
    "neutral": "Use natural, everyday conversational speech.",
    "polite": "Use polite, friendly speech.",
}


def lang_name(code: str) -> str:
    return LANGUAGE_NAMES.get(code, code)


# ---------------------------------------------------------------- listen (audio -> caption)

LISTEN_SCHEMA: dict = {
    "type": "object",
    "properties": {
        "is_speech": {"type": "boolean"},
        "source_lang": {"type": "string", "description": "ISO 639-1 code of the spoken language"},
        "transcript": {"type": "string"},
        "translation": {"type": "string"},
        "confidence": {"type": "number"},
    },
    "required": ["is_speech", "source_lang", "transcript", "translation", "confidence"],
}


def listen_system_prompt(target_lang: str, glossary: list[str], context: list[str]) -> str:
    glossary_txt = ", ".join(glossary) if glossary else "(none)"
    context_txt = "\n".join(f"- {line}" for line in context) if context else "(none)"
    return f"""You are a real-time interpreter for online multiplayer games such as Roblox.
Task for each audio clip:
1. Transcribe the speech verbatim.
2. Detect the spoken language (ISO 639-1).
3. Translate it into {lang_name(target_lang)}.
Rules:
- Keep gamer slang natural (gg, noob, obby, AFK, lag...). Do not over-formalize.
- Never translate usernames or these glossary terms: {glossary_txt}.
- If the clip is music, sound effects, or unintelligible, set is_speech=false and leave text empty.
- If the speech is already in {lang_name(target_lang)}, copy the transcript into translation.
- confidence: 0..1 for how sure you are about the transcript.
Recent conversation (for context only, do not translate):
{context_txt}"""


# ---------------------------------------------------------------- speak (my text -> partner)

SPEAK_SCHEMA: dict = {
    "type": "object",
    "properties": {
        "translation": {"type": "string"},
        "pronunciation": {
            "type": "string",
            "description": "How to read the translation aloud, written in the user's own script",
        },
        "casual": {"type": "string", "description": "A more casual alternative"},
        "polite": {"type": "string", "description": "A more polite alternative"},
    },
    "required": ["translation", "pronunciation", "casual", "polite"],
}


def speak_system_prompt(my_lang: str, target_lang: str, tone: str, glossary: list[str]) -> str:
    glossary_txt = ", ".join(glossary) if glossary else "(none)"
    return f"""You help a {lang_name(my_lang)} speaker talk to other players in an online game.
Translate the user's message into {lang_name(target_lang)} so they can read it aloud or send it.
- {TONE_HINTS.get(tone, TONE_HINTS["neutral"])}
- Keep it short and natural, like real in-game voice chat.
- pronunciation: transliterate the translation into {lang_name(my_lang)} script so the user can read it aloud.
- Also give one more casual and one more polite alternative in {lang_name(target_lang)}.
- Never translate usernames or these glossary terms: {glossary_txt}.
Output JSON only."""
