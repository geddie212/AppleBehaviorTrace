# Apple BehaviorTrace

Apple BehaviorTrace is an iPhone and Apple Watch app for running small self-tracking studies that pair how someone says they feel with what their body is actually doing. An admin sets up a study, defines a handful of behavioral or emotional states to track (tired, stressed, focused, calm, whatever the study cares about), and participants join with a study code. From there, participants log when a state starts and ends, get periodic check-in prompts asking if it's still true, and the app quietly syncs their Apple Watch health data — heart rate, HRV, step count, energy, and more — alongside those labels to Supabase in the background.

The idea is to build up a labeled dataset connecting subjective state to biosignals, which is the same premise the original BehaviorTrace research project was built on. Right now the app's job is reliable data collection: getting clean, timestamped labels and matching HealthKit exports into a database without dropping data when the phone is asleep, the watch is unreachable, or the network is flaky. Training a model on top of that data and running predictions on-device is the direction this is headed, not something it does yet.

## How it works

**Admins** create a study, write the behavioral labels participants will track, and set how often participants get pinged to confirm a state is still active (e.g., "Are you still feeling tired?" every 10 minutes). Studies can be public or joined with a private study code.

**Participants** register, join a study, and see the list of labels available. Tapping a label starts a state session; the app records the start time, schedules local notifications to check in, and stores everything locally first so nothing is lost if the network drops. Ending a state, or ignoring/declining a prompt, is also recorded. All of this is written to a local store and synced to Supabase opportunistically, including through iOS background refresh.

**HealthKit data** is read continuously in the background (subject to entitlements and the user's permission) and uploaded in raw form so it can later be aligned against the label timeline by timestamp.

**Apple Watch** runs a companion app connected over WatchConnectivity. It mirrors the participant's active study and labels so states can be started and confirmed right from the wrist, which matters a lot for a study design built around momentary check-ins — nobody wants to pull out their phone every ten minutes.

**Supabase** is the backend: Postgres for everything (profiles, studies, labels, state events, raw health samples), Supabase Auth for login and role separation between admins and participants, and row-level security so participants can only see their own data.

## What's in this repo

```
AppleBehaviorTraceApp/
  AppleBehaviorTraceApp/     iOS app (SwiftUI) — auth, admin study builder,
                              participant flow, EMA logic, HealthKit sync
  WatchCompanionApp/          watchOS companion app
supabase/
  migrations/                  SQL migrations for the Postgres schema and RLS policies
scripts/
  plot_health_samples.py       Pulls health_samples from Supabase and plots them,
                                useful for sanity-checking that sync is actually working
ios/                          Early scaffolding from before the real Xcode project
                              existed — not part of the current build, kept for history
```

## Tech stack

- SwiftUI for both the iPhone and Watch apps
- HealthKit for reading biosignals, WatchConnectivity for phone/watch messaging
- UserNotifications for the EMA (Ecological Momentary Assessment) prompts
- Supabase (Postgres, Auth, Row Level Security) as the backend
- Python (pandas/matplotlib) for pulling and visualizing collected data

## Getting started

You'll need Xcode, an Apple Developer account with HealthKit and WatchConnectivity entitlements, and a Supabase project.

1. Create a Supabase project and run the migrations in `supabase/migrations/` in order (via the Supabase CLI or the SQL editor).
2. Point the app at your Supabase project. The service looks for a `SUPABASE_URL` environment variable, falling back to a bundled default — set this up however fits your workflow (an `.xcconfig` or scheme environment variable both work, and neither should be committed).
3. Open `AppleBehaviorTraceApp/AppleBehaviorTraceApp.xcodeproj` in Xcode and run the `AppleBehaviorTraceApp` scheme on a device (HealthKit doesn't work in the simulator). Run `WatchCompanionApp` on a paired Apple Watch or its simulator to test the companion side.
4. To check what's actually landing in the database, `scripts/plot_health_samples.py` will pull a participant's health samples and chart them — see the script's docstring for the required environment variables.

## A note on data and privacy

This is a research prototype, not a shipped product. HealthKit access requires explicit permission and only the data types the study needs should be requested. Real HealthKit exports, participant data, and Supabase credentials should never be committed — see `.gitignore`. Nothing in this app should be presented as medical advice or diagnosis; it's for experimental, self-directed behavioral tracking.

## License

MIT — see `LICENSE`.
