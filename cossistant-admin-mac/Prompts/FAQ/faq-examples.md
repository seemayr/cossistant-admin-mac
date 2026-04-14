# Few-Shot Examples

Use these examples as retrieval and structure patterns only. Do not copy product facts from them into unrelated FAQs.

## Example 1: Rewarded Ad Replay Flow

### Incoming user wording families

- "I can't replay"
- "Video not loading"
- "Ad fails"
- "Rewarded ad won't start"
- "I watched the ad but replay did not unlock"
- "No puedo ver el anuncio para repetir"

### Good output

Question:
I can't replay a game because the rewarded ad does not load or finish correctly

Categories:
- replay
- rewarded ads
- video loading

Related Questions:
- I can't replay
- Video not loading
- Ad fails when I try to replay
- Rewarded ad won't start
- I watched the ad but the replay did not unlock
- Replay button does nothing after ad

Answer:
If replay is blocked because the rewarded ad does not load, does not start, or finishes without unlocking the replay, close and reopen the game and try again on a stable internet connection. If the ad opens but replay still does not unlock, ask the player for their device model and whether they saw an error or the ad closed early. Escalate to a human if the issue keeps happening after reopening the game.

Why this is good:

- The Question names both the mechanic (`replay`) and the underlying wording family (`rewarded ad`, `load`, `finish`).
- The Answer repeats the key wording family early.
- Related Questions add more variants without carrying the whole retrieval burden.

## Example 2: Invite Link and Manual Group Join

### Incoming user wording families

- "Invite link creation does not work"
- "I can't create an invite link"
- "My invite link does not work"
- "I can't invite anyone to my group"
- "Friend can't join from link"

### Good output

Question:
I can't create or share a group invite link

Categories:
- groups
- invites
- sharing

Related Questions:
- My invite link does not work
- I can't create an invite link
- I can't invite anyone to my group
- Friend can't join from invite link
- Share link does nothing

Answer:
If you cannot create or share a group invite link, use the manual join flow instead. Open the group, tap the avatars at the top, open Group Settings, then copy the Group ID and send it to your friend. Your friend can paste that Group ID into the Join Group screen. If the invite-link action shows an error or the manual Group ID join also fails, ask for the exact error message and escalate to a human.

Why this is good:

- The Question is broader and more natural than a narrow internal label.
- The Answer includes both the main issue and the verified fallback path.
- The escalation rule is explicit and concise.
