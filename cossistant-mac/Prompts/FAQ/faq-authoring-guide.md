# Cossistant FAQ Authoring Guide

## Core Retrieval Rule

Cossistant currently embeds FAQ knowledge primarily from:

Q: `<question>`

A: `<answer>`

`Related Questions` and `Categories` are valuable operator metadata, but they do not carry the main retrieval load. Important retrieval wording must appear in the main `Question` and `Answer`, not only in metadata.

## Perfect FAQ Goal

Write FAQs that:

- map many different user phrasings to one verified support issue
- keep the fix or workaround grounded in real product behavior
- stay compact enough to remain single-chunk when possible
- are readable to both the AI system and a human support operator
- are always written in English, even when the source conversation is in another language

## FAQ Scope

- One FAQ should cover one issue or one tightly connected workflow.
- If a conversation includes multiple unrelated issues, split them into separate FAQs.
- If several surface phrasings describe the same mechanic, keep them in one FAQ.

Example of one FAQ:

- "I can't replay"
- "Video not loading"
- "Ad fails"
- "Rewarded ad won't start"
- "I watched the ad but replay did not unlock"

If all of these refer to the same rewarded-ad replay mechanic, they belong in one FAQ.

## Field Rules

### Question

- Use natural user phrasing.
- Make it the canonical issue statement, not an internal title.
- Ideally keep it concise and specific.
- Include the main mechanic and the main failure mode.

### Categories

- Use 2 to 4 short labels.
- Prefer lower-case or simple title-case nouns.
- Keep them organizational, not sentence-like.
- Example: `replay`, `rewarded ads`, `video loading`

### Related Questions

- Use distinct alternate phrasings.
- One wording per line.
- Prefer 4 to 8 strong variants.
- Do not just repeat the main question with tiny edits.
- Include the most common alternate wording families.

### Answer

- Start with the confirmed fix or workaround.
- Mention the key wording variants early if they matter for retrieval.
- Name exact screens, buttons, or settings when known.
- Put escalation conditions at the end.
- Do not invent product details that are not supported by the evidence.

## Training Length Budget

The backend chunks FAQ embedding input at roughly:

- target chunk size: 1000 characters
- overlap: 200 characters

The embedded character count is approximately:

`3 + question.count + 4 + answer.count`

because the stored training text is:

Q: `<question>`

A: `<answer>`

Recommended target:

- Ideal: keep embedded `Question + Answer` at or under 900 characters.
- Acceptable: up to 1000 characters still stays single-chunk.
- Above 1000 characters: the FAQ may split into multiple chunks.

## Writing for Different Wordings

Different users may report the same issue with very different language. The FAQ should bridge those variants without becoming a keyword dump.

Use this pattern:

- Put the canonical intent in the `Question`.
- Mention the major wording families in the first lines of the `Answer`.
- Use `Related Questions` for additional wording coverage.
- Keep the text readable and natural.

## Language Guidance

Embeddings can connect meaning across wording changes and sometimes across languages, but retrieval is stronger when important multilingual terms appear naturally in the actual embedded text.

The final FAQ output in this app must always be English:

- write `Question`, `Categories`, `Related Questions`, `Answer`, and `notes` in English
- if the source conversation is in another language, translate the verified meaning into natural English
- keep product terms, screen names, and quoted error strings in their original form only when translation would reduce accuracy

If the same issue is reported in multiple languages:

- keep one canonical FAQ in the main support language
- include the most important alternate-language wording only when it is common and compact
- avoid stuffing long translation lists

## Evidence Guidance for Conversation-Derived FAQs

When drafting from support conversations:

- trust visitor and human-admin messages most
- treat AI or system messages as hints, not as authority
- prefer the final verified human resolution if the AI was wrong earlier
- if the resolution is uncertain, keep the FAQ conservative and note the uncertainty
