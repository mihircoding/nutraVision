# Manual tests: the error-prone parts

Automated tests cover the logic. These cover what only a real phone, camera, pair of glasses or second person
can check. Each test says **why** it might break, so you know what to look for.

**Setup:** the app installed on your iPhone ([INSTALL-ON-IPHONE.md](INSTALL-ON-IPHONE.md)). The backend is your
live Supabase project, already set up. Add the API keys ([BACKEND-SETUP.md](BACKEND-SETUP.md)) before the photo
scan and search tests. Demo accounts use the password `demo1234`.

> **Heads up:** these run against your **live** project. Test accounts you create stay there. Delete them in the
> app (More > Delete account), which test I1 covers anyway.

Tick each box when it passes. If one fails, note the test ID, what you saw, and a screenshot. That's enough for
Claude to fix it.

Priority: **P1** = likely to break or would lose data · **P2** = annoying · **P3** = edge case.

---

## A. Sign-up, sign-in, onboarding

- [ ] **A1 (P1) New patient end to end.** Create account > Patient > a new email > password `test1234` >
  Create account. Finish all 3 onboarding steps (pick Type 2 diabetes + Hypertension, goal −0.5 kg/week).
  **Expect:** the Dashboard shows calorie and macro targets, not zeros. *Why:* the profile row is created by a
  database trigger. If email confirmation wasn't turned off (BACKEND-SETUP step 2), this stalls.
- [ ] **A2 (P1) Wrong password.** Sign in as `maria@nutravision.demo` with `wrong`. **Expect:** a readable error,
  and the app stays usable.
- [ ] **A3 (P2) Duplicate email.** Sign up again with Maria's email. **Expect:** an error such as "User already
  registered", not a frozen spinner.
- [ ] **A4 (P2) Escape from onboarding.** Create another account, and on step 1 tap **Sign out** (top left).
  **Expect:** back to Welcome. *(Was missing. Fixed.)*
- [ ] **A5 (P1) Doctor sign-up keeps credentials.** Sign up as Doctor with a specialty and license number.
  Then check that the doctor's profile shows them. *Why:* the credentials are saved in a second step after the
  account exists.
- [ ] **A6 (P2) Sign out, then sign in as someone else.** Maria → sign out → James. **Expect:** no trace of
  Maria's diary, and no leftover red error banner. *(Banner fix.)*
- [ ] **A7 (P2) Airplane mode at launch.** Turn on Airplane mode, force-quit, open the app. **Expect:** an
  error with Retry and Sign out, not an endless spinner. Turn Airplane mode off and tap Retry.

## B. Logging food

- [ ] **B1 (P1) Search.** + > Search food > "greek yogurt". **Expect:** USDA results (generic and branded)
  within ~3 s. Add one with 2 servings. It appears in the right meal, and the Dashboard total goes up.
- [ ] **B2 (P1) Barcode, first time ever.** On a fresh install, + > Barcode. **Expect:** iOS asks for camera
  permission right away. Allow it, then scan any packaged food. *(Before the fix it never asked, and barcode
  scanning was stuck.)*
- [ ] **B3 (P2) Barcode with camera denied.** Settings > NutraVision > Camera off, then + > Barcode.
  **Expect:** a message and an **Open Settings** button that goes to the right place.
- [ ] **B4 (P1) Photo scan.** + > Photo, photograph a real plate. **Expect:** separate items (for example
  rice, chicken, salad) with grams and calories in about 5–10 s. Change one item's grams and the calories update.
  Tap Add.
- [ ] **B5 (P2) Photo of something that isn't food** (a keyboard). **Expect:** "No food found" (or
  similar), and nothing gets logged.
- [ ] **B6 (P1) Decimal comma.** iPhone Settings > General > Language & Region > Region = Germany. In Create
  Food enter fat `2,5` and protein `12,5`, save it, then log it. **Expect:** 2.5 g and 12.5 g, not 0.
  Repeat with grams `12,5` in Food Detail. Set the region back afterwards. *(Fixed: both used to become 0.)*
- [ ] **B7 (P3) Silly numbers.** In Create Food, type kcal `99999999999999999999`. **Expect:** Save stays
  disabled with a "Check the numbers" hint, and the app doesn't crash. *(Used to crash the app every time that
  food was shown.)*
- [ ] **B8 (P1) Log to a past day.** Diary > Previous day > Add Food on Dinner > add something. **Expect:** it
  appears on that day, not today. The "Fits / Not recommended" verdict should reflect *that* day's total.
  *(Verdict fix.)*
- [ ] **B9 (P2) Double-tap Add.** Tap Add twice quickly. **Expect:** one entry, not two.
- [ ] **B10 (P2) Edit and delete.** Tap a diary entry, change servings 1 → 3, and Save. The totals triple.
  Swipe left and Delete. It's gone, and the totals drop.

## C. Exercise, weight, progress

- [ ] **C1 (P1) Exercise adds to the goal.** Log a 30-minute run. **Expect:** the Dashboard's remaining calories
  go up by the run's kcal (if "add exercise calories" is on in Profile).
- [ ] **C2 (P1) Delete exercise.** In the Diary, swipe left on the run > Delete. **Expect:** it's gone and
  remaining calories drop back. *(This was impossible before.)*
- [ ] **C3 (P2) Back-dated weight.** Log today's weight, then log a lower weight dated last week. **Expect:**
  Profile still shows *today's* weight. *(Fixed.)*
- [ ] **C4 (P2) Progress updates live.** Open the Progress tab, tap +, log food, close the sheet. **Expect:**
  today's calendar color updates without switching tabs. *(Fixed.)*
- [ ] **C5 (P3) Month and year edges.** On Progress, go back across a month boundary and to the Year view.
  Tap a day and the Diary for that day opens.

## D. Apple Health (real phone only)

- [ ] **D1 (P1) Connect.** More > Apple Health > Connect > **Turn On All** > Allow.
- [ ] **D2 (P1) Food goes to Health.** Log a food. **Expect:** in the Health app > Browse > Nutrition >
  Energy Consumed, the entry appears with NutraVision as the source.
- [ ] **D3 (P1) Edit and delete reach Health.** Edit that entry to 3 servings: Health shows the new amount, not
  both. Delete it: it leaves Health. *(Editing used to leave Health unchanged.)*
- [ ] **D4 (P2) Partial permission.** In Health > your profile > Apps > NutraVision, turn off **Sugar** only,
  then log a food. **Expect:** the other nutrients still reach Health. *(Before the fix, one denied type
  silently blocked the whole entry.)*
- [ ] **D5 (P1) Workout import.** Record a short workout on an Apple Watch, or add one in Health > Browse >
  Activity > Workouts > Add Data. Reopen NutraVision. **Expect:** it appears in today's Exercise with a heart,
  once (not twice after reopening).
- [ ] **D6 (P2) Workout deleted in Health.** Delete that workout in Health, then reopen NutraVision.
  **Expect:** it disappears from the Diary. *(Was never removed before.)*

## E. Doctor and patient (two accounts, ideally two phones)

- [ ] **E1 (P1) Link request.** As a **new** doctor account: send a request to a new patient's email. As the
  patient: More > Care Team > Accept. **Expect:** the doctor now sees the patient in Patients.
- [ ] **E2 (P1) Doctor reads the diary.** The doctor opens the patient's diary and progress. It's read-only:
  no Add, no swipe-delete.
- [ ] **E3 (P1) Recommendation changes targets.** Sign in as `james@nutravision.demo` > More > Care Team > open
  the pending recommendation > Accept. **Expect:** the sodium target becomes 1,400 mg, and salty foods' verdicts
  get stricter.
- [ ] **E4 (P2) Decline and revoke.** Decline a recommendation, then revoke the care link from either side.
  **Expect:** the doctor loses access to the diary immediately (pull to refresh).
- [ ] **E4b (P2) Revoke with a recommendation still pending.** Doctor sends a recommendation, patient revokes
  the doctor *without* answering it. **Expect:** it shows as Declined and can't be accepted any more.
- [ ] **E4c (P3) Double-tap Accept** on a care request. **Expect:** no red "Request not found".
- [ ] **E4d (P3) Doctor's sent list.** On a patient's "Plan & history" tab, send a recommendation. **Expect:**
  it appears in "Recommendations sent" right after the sheet closes.
- [ ] **E5 (P2) Request to an unknown email.** **Expect:** "No patient with that email".
- [ ] **E6 (P3) No live updates.** There are no push notifications. The other side's change shows after pull
  to refresh or reopening the app. That's expected, not a bug.

## F. Diet plans and conditions

- [ ] **F1 (P2)** More > Diet Plans > start the Bodybuilding sample > swap a food > keep it as active.
  **Expect:** only one plan is marked active.
- [ ] **F1b (P1) First condition becomes primary.** As a new patient, More > Conditions > Chronic kidney
  disease > Add to my conditions. **Expect:** Profile shows it as **Primary**, "No condition" is no longer
  ticked, and protein drops to about 12% of calories. *(It used to stay behind "No condition", which gave a
  kidney patient a normal-diet protein target.)*
- [ ] **F1c (P2) Start a plan twice.** Conditions > any condition > tap **Start this plan**. The button
  disables. Diet Plans shows it **once**.
- [ ] **F1d (P1) A doctor's plan sets targets.** Doctor sends a diet plan with lower calories; patient accepts.
  **Expect:** Dashboard targets change to the plan's. *(Accepting used to only file the plan away.)*
- [ ] **F2 (P2)** More > Conditions: the active rules match your conditions, and the verdict on a high-sodium
  food mentions blood pressure for a hypertension profile.

## G. Glasses Mode (Meta Ray-Ban, real hardware)

- [ ] **G1 (P1) Guided setup.** + > Glasses Mode > Meta glasses on a phone where NutraVision isn't approved yet.
  **Expect:** the 4-step Glasses setup screen, not a "not connected" error. Follow it: Developer Mode in Meta AI
  (Settings › App Info, tap App version 5 times) > **Open Meta AI to approve** > approve > you're back with step 3
  ticked > **Allow camera in Meta AI** > Allow always > step 4 ticked > **Start Glasses Mode**.
- [ ] **G1a (P1) First camera start.** After G1, the first Glasses Mode start. **Expect:** iOS asks to find devices
  on your Local Network (tap **Allow**) and to join the glasses' Wi-Fi network (tap **Join**); then the live view
  appears. Deny Local Network instead. **Expect:** "…couldn't join the glasses' Wi-Fi. Turn on Local Network…", not
  "the glasses ended the session". *(Before this fix the app lacked the Bluetooth LE and Wi-Fi settings the glasses
  need, and every start ended with "the glasses ended the session".)*
- [ ] **G1b (P1) Clear errors.** With the glasses folded or in the case, start Glasses Mode. **Expect:** "Meta AI
  can't reach your glasses…", with **Glasses setup** and **Try again** buttons. It should never say "not connected"
  when the real problem is approval.
- [ ] **G2 (P1) "Scan this".** Start Glasses Mode, look at a plate, and say "scan this". **Expect:** within about
  8 s you hear the food's name, calories and a verdict.
- [ ] **G3 (P1) "Add it".** Say "add it". **Expect:** it's logged to the meal for the current time, and you
  hear the new daily total.
- [ ] **G4 (P1) It doesn't hear itself.** While it's speaking, stay silent. **Expect:** it doesn't react to
  its own voice (for example by re-triggering "scan").
- [ ] **G5 (P2) Barcode with no command.** Look at a packaged item's barcode. **Expect:** the result is spoken
  without saying anything.
- [ ] **G6 (P1) Take the glasses off / fold them.** **Expect:** Glasses Mode ends with "Glasses disconnected"
  and doesn't hang.
- [ ] **G7 (P2) Interruptions.** During Glasses Mode, trigger Siri, or have someone call you. **Expect:**
  Glasses Mode pauses or ends cleanly, then works again when you restart it.
- [ ] **G8 (P2) Phone camera instead.** In Glasses Mode switch the source to the Phone camera and scan.
  It never gets stuck on "scanning".
- [ ] **G9 (P2) Leave mid-scan.** Say "scan this" and immediately leave the Glasses Mode screen. **Expect:**
  no crash, and the mic indicator (orange dot) turns off.
- [ ] **G10 (P3) Locked phone.** Lock the phone during Glasses Mode. Known limitation: the stream pauses. It
  should resume or report clearly when unlocked.

## H. Time and resilience

- [ ] **H1 (P2) Past midnight.** Leave the app open on the Dashboard across midnight (or set the clock to
  23:58 via Settings > General > Date & Time and wait). Log a food after 00:00. **Expect:** the Dashboard
  shows a fresh day with only that food. *(It used to keep adding to yesterday's view.)*
- [ ] **H2 (P2) Time zone.** As Maria, check that the seeded meals show sensible times. The demo data is
  stored in UTC, so outside the Americas and Europe some meals land on the neighboring day. That's a known
  demo-data quirk, not an app bug.
- [ ] **H3 (P2) Kill and relaunch.** Force-quit mid-way through adding food. Relaunch. **Expect:** still signed
  in. Anything that was saved is shown once, and nothing appears twice.
- [ ] **H4 (P3) Dark mode and large text.** Settings > Display > Dark, and Text Size at the largest. Walk
  through Dashboard, Diary and Add. Nothing is unreadable or cut off so badly you can't use it.

---

## I. Newer features on this branch

- [ ] **I1 (P1) Delete account.** Create a throwaway patient, log a food, then More > Delete account > confirm.
  **Expect:** back at Welcome, and signing in with it fails. Nothing of it remains for a linked doctor.
- [ ] **I2 (P1) New doctor waits for verification.** Sign up as a Doctor and try to request a patient.
  **Expect:** "Your account is waiting for license verification". After
  `supabase/admin/verify_doctor.sql`, requests work.
- [ ] **I3 (P2) Forgot password.** Sign in > Forgot password? with **your own** email. Do the 2-minute dashboard
  fix in BACKEND-SETUP first. **Expect:** the email arrives, the link opens NutraVision, and it asks for a
  new password. *(Without the fix the link opens a dead localhost page.)*
- [ ] **I4 (P1) Vitals.** More > Vitals > Log a reading > Blood pressure **185/112**. **Expect:** crisis advice
  appears, and the value saves after you confirm. Glucose in mmol/L with a comma (`5,6`) is accepted.
- [ ] **I5 (P2) Fluids.** On the Dashboard fluid card tap +250 ml a few times. If a fluid limit applies (kidney
  disease), it warns when you go over.
- [ ] **I6 (P1) Symptom diary.** As `alex@nutravision.demo`: More > Symptoms shows past entries and the "foods
  often followed by symptoms" insight (yogurt). Log one with **Food stuck in throat or chest**: emergency
  advice shows.
- [ ] **I7 (P2) Quick add.** + > Quick add, 350 kcal, no name. It logs to the chosen meal. A 20-digit number is
  rejected. *(Bounded here today too.)*
- [ ] **I8 (P2) Doctor tools.** As the doctor, open Maria: **Export last 30 days (CSV)** shares a file that
  opens in Numbers. **Notes** saves a clinical note that the patient can't see.
- [ ] **I9 (P2) AI scan quota.** Photo-scan many times in one day. **Expect:** after the daily limit, a clear
  "limit reached" message, not a generic failure.
- [ ] **I10 (P3) Recipes and new conditions.** Conditions > IBD or EoE: recipe ideas and medical sources show.

## Automated checks (run on the Mac)

```bash
cd ~/Desktop/NutraVision/ios/NutraCore && swift test
```

```bash
cd ~/Desktop/NutraVision && PATH=~/.local/node-v24.22.3-darwin-arm64/bin:$PATH npm test
```
