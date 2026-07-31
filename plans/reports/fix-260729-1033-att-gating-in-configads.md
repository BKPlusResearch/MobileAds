# Fix: `configAds` waits for ATT to actually resolve

Repo: `MobileAds` · Branch: `new-MobileAds` · Date: 2026-07-29
Scope: Option 2 only. Option 3 (presentation safety) deliberately **not** done —
see [Still open](#still-open).

## Defect

`configAds` treated "the `requestTrackingAuthorization` callback fired" as "ATT
resolved". They are not the same. The callback returns immediately — reporting
`.notDetermined` and presenting nothing — in two situations that occur in normal
use:

1. The app is not `.active`. During launch, or while another system alert owns
   the screen, iOS silently declines to present the prompt.
2. A prompt queued by an earlier session has not been answered. iOS re-presents
   it asynchronously; the callback does not wait for it.

Consequence: the SDK initialized and ad requests started while the ATT alert was
still on screen. An App Open ad rendered underneath a system alert — invisible
and non-interactable — while recording an impression.

## Change

`MobileAds/AdMobHelper/AdMobHelper.swift`, +70/−9.

- `resolveTrackingAuthorization()` — new. Returns immediately when the status is
  already decided (which is also the path taken when the UMP IDFA explainer
  presented the alert itself). Otherwise waits for `.active`, requests
  authorization, then polls **the status** until it is decided.
- `waitWhile(before:_:)` — small suspend-don't-block poll helper.
- `configAds` now awaits that before `finishConfigAds`.
- Dropped the dead `#available(iOS 14, *)` branch — the podspec is
  `spec.platform = :ios, "15.0"`, so it was unreachable.
- 30s cap (`trackingAuthorizationTimeout`) so a launch cannot stall forever.

Order is unchanged and stays **UMP → ATT**, per Google: the IDFA explainer only
loads while the status is `.notDetermined`, so requesting ATT first would disable
that message permanently.

## Evidence

Measured on iPhone 17 simulator via `ios013` (`:path` consumer), counting log
signals. `TCC Access Request` = the prompt was actually presented by this launch.

| Scenario | Ad requests before | Ad requests after |
|---|---|---|
| Relaunch, ATT prompt pending | **10** | **0** |
| Relaunch, ATT prompt pending — RC fetches | — | **0** |
| Clean install, prompt presented | 0 | 0 |
| ATT already answered | 12 | **12** (unchanged — proceeds normally) |

Screenshots: before, a Google Ads creative with a "Test mode" badge rendered
behind the ATT alert. After, the splash is clean behind it.

Both branches are therefore proven: decided status proceeds and serves ads;
undecided status holds and serves nothing.

## Not verified

- **The exact tap.** The simulator here has no assistive access, so the
  transition "user taps Allow → launch continues" was never driven directly.
  Its code path is the same early-return that the "already answered" run
  exercised, but it was not observed end to end.
- **The 30s escape hatch.** The app suspended while idle at the alert
  (`BackgroundTask ... invalidate assertion`), so `Task.sleep` stopped advancing
  and the deadline never fired within the observation window. The deadline uses
  wall-clock `Date()`, so it self-heals on the next foreground — but that was not
  observed either.

## Blast radius

Every app consuming `MobileAds`. Behaviour change: `configAds`'s completion can
now take meaningfully longer — it waits for a real user decision instead of
returning early. Any consumer that assumed the completion was near-instant, or
that arms a launch timeout *before* calling `configAds`, should be re-checked.

`ios013` is safe: its splash arms its own timeout only *after* the completion.

## Still open

- **Option 3 — presentation safety (not done, user's call).**
  `AdMobHelper.canPresentFullScreenAd` (`:143-145`) returns
  `applicationState != .background`, i.e. it permits `.inactive` — which is
  exactly the state when a system alert owns the screen. This fix stops the
  *launch chain* from reaching a present call in that window, but nothing stops
  a resume App Open ad or an interstitial from presenting under a permission
  dialog elsewhere. The AdMob invalid-impression exposure is reduced, not closed.

## Unresolved questions

1. Podspec still says `1.3.0` and `spec.source` resolves by tag. Consumers on
   `:git` will not receive this until the version is bumped **and** tagged. Who
   owns that release step?
2. `spec.source` points at `github.com/AperoVN/MobileAds.git` (`podspec:91`)
   while the real remote is `BKPlusResearch/MobileAds.git`. Cosmetic for `:path`
   and `:git`-with-override consumers, wrong for anyone else.
3. Commit `0ba1adc` deliberately allowed `.inactive` presentation. Was there a
   consumer depending on that, or was it only for resume App Open? The answer
   decides how tightly Option 3 can be closed.
4. Is 30s the right cap? Longer protects the impression better; shorter protects
   the launch. Currently favours the impression.
