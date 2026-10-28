# Handoff

```
/make-plan Design the Medicine Archive Android app (Flutter) from scratch.

Primary user: a person keeping track of the medicines each family member has.
Primary task: photograph a medicine box and save its name and quantity under
the right person.
Constraints: Flutter + Material 3, Android only, on-device OCR, encrypted
local storage, photo deleted after reading, light and dark themes, 48dp touch
targets, WCAG AA contrast.

Non-goals (do not design these now):
- Cloud sync, accounts or sharing
- Dosage schedules and reminders
- Barcode / drug database lookup

Reference principles to optimize for, in order:
1. Useful (#2): one primary action per screen; scan, check, save.
2. Understandable (#4): OCR result is always shown in an editable form before
   saving; plain labels ("Name", "Quantity").
3. As little design as possible (#10): two lists and one form, one seed
   colour, Material defaults.

Deliverables for the plan:
- Screen map: Profiles -> Profile (medicines) -> Confirm medicine
- Primary flow: tap Scan -> camera -> reading... -> confirm form -> list
- Tokens: Material 3 from one seed colour (teal), system type scale,
  8dp spacing grid (8/16/24)
- States: empty lists, reading spinner, unreadable photo, saved snackbar,
  delete confirmation, disabled Save while name is empty
- Honesty audit on every user-facing string before ship
```
