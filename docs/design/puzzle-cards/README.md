# The Ninth Tide: the paper game

GDD milestone 1. These cards are the integration contract between design and the room teams. A facilitator must be able to run the complete solution path from them without inventing evidence. When a card and the GDD disagree, the card is the newer decision and `reconciliation.md` says why.

| File | Purpose |
| --- | --- |
| `flags.md` | Canonical ids: every cross-room flag, item and evidence id, with writer and readers. Code uses these spellings exactly. |
| `rooms.md` | Per room: base views, close-ups, hotspots, exits and gates, and the tide-state escalation matrix. |
| `reconciliation.md` | What happened to every Intake Office slice beat, and every deliberate departure from GDD v1.1. |
| `T1X-closure.md` | The Tide I to Tide II transition in R02 (log rewrite, chair, closure report, threshold). A mandatory sequence, not a numbered puzzle. |
| `P01.md` ... `P27.md` | One card per mandatory puzzle. |

## Card fields

Every card has the same headings, in this order: **Room**, **Tide**, **Requires**, **Evidence**, **Solution**, **Wrong answers**, **Outputs**, **Consumed**, **Hints**, **Notebook**, **Reveal and dread**, **Room states after**, **Tests**. "Requires" lists only ids from `flags.md`. "Outputs" lists every flag, item and evidence id the solve writes, and nothing else writes them.

## Conventions every room follows

- **State is the sim's.** Every flag, item and evidence id is written by a deterministic, node-free sim on a player action. Views only play the events it returns. Nothing is granted from an animation callback (GDD 13).
- **Completion flags are `pNN_complete`.** Gates read these directly. A tide is derived (`tide()` in `flags.md`), never stored on its own.
- **Commit, then consequence.** Each puzzle has one explicit commit (pull, press, stamp, play, file). The sim validates on commit only, never on arrangement. A mechanical confirmation sound comes first; the unsettling consequence is a separate, later event, so the player can always tell "I solved it" from "something else happened" (GDD 12).
- **Wrong answers are free.** No wrong commit consumes, destroys or locks anything. Feedback names the inconsistent relationship, not the answer. A puzzle may keep a small per-puzzle miss counter for line rotation only; it never changes the answer.
- **Evidence before change.** Any clue that a later state replaces is copied to the notebook at the moment it is first seen (GDD 5). Every card's Evidence list says where the notebook copy comes from.
- **Hints.** Three levels: location nudge, relationship, explicit solution. Asking never costs anything and never touches ending access. A hint asked during a story chain plays after it (slice round 3 rule).
- **Symbols.** Hollow circle = observer. Square bracket = boundary. Two linked strokes = relation. Always printed with the word beside them. Shape and text duplicate every colour.
- **Settings.** Every sudden sound is marked `sudden` and respects "Soften sudden sounds". Every flicker, loop and drift is marked `motion` and respects "Motion & flicker" (a still pose replaces it).
- **Dread is legible.** Every dread beat is something the player clearly sees or hears. Never darken a scene to make it scary. Hotspots never move between states.
- **IP.** Everything here is original. No Mythos names, places, books, entities or symbols; nothing from Rusty Lake (no animal-headed people, no crows or owls as characters, no black cubes or memory cubes, no Laura or Mr. Crow).

## Who is who (canon for every card)

| Person | Role | Initials | Details cards rely on |
| --- | --- | --- | --- |
| Ada Mercer, 34 | Temporary cataloguer (player) | A.M. | Right-handed. Dissented from the 1929 Morrow Harbour Board inquiry. |
| Elias Venn, 58 | Senior observer, missing 3 days | E.V. | Left-handed. Three-cut personal seal. His oilskin hangs on hook 7. The ninth person at the 1927 session, never indexed. |
| Dr. Silas Rook | Director | S.R. | Measures everything twice. Calipers with a filed jaw. |
| Nora Bell | Cook and caretaker | N.B. | Tea without sugar. Repaired cup: brass staple through the handle. Mends bowls with square patches. |
| Thomas Ives | Technician | T.I. | Restitches his right glove in red thread. Letters home about the soup. |
| Margaret Lusk | Draughtswoman | M.L. | |
| Owen Pryce | Boatman | O.P. | |
| Clara Doane | Recordist | C.D. | Wrote lying down; Venn built her a pencil shelf on her bunk. |
| Samuel Hart | Engine-man | S.H. | |
| Agnes Tull | Laboratory assistant | A.T. | |

The office has nine coat hooks (approved art). Hook 7 holds Venn's oilskin. Hook 9 is wet with nothing on it from the start, and later carries a brass tag stamped A.M. Hooks are not assigned to staff.

The eight indexed staff are Rook, Bell, Ives, Lusk, Pryce, Doane, Hart and Tull. The Index session was **18 October 1927**. Game day is **17 to 18 October 1931**: Ada lands on the evening launch of the 17th, and the contract's collection launch (two-stripe pennant) is due on the morning high water, **18 Oct 07:13**.

## Golden path (for the facilitator)

P01 → (drawer, part of P03) → {P02, P03} → T1X closure report and threshold → P04 → P05 → P06 → {P07, P08} → P09 → {P10, P11} → P12 → P13 → P14 → P15 → P16 → {P17, P18} → {P19, P20} → P21 → {P22, P23} → P24 → P25 → P26 → P27 (SEVER or CONTINUE).
