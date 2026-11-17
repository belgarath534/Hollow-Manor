# TestFlight builds with Codemagic

`codemagic.yaml` works the same way as Truck Sim's. It reuses the **Accessible Backrooms** App Store Connect key
and the **Accessible Backrooms Distribution** certificate already saved in Codemagic. On its own, it registers the
bundle ID `com.hollowmanor.HollowManor` with Apple and creates a "Hollow Manor App Store" profile. It does this
the first time only and reuses them after that.

## One-time setup

1. **Add the repo to Codemagic.** In Codemagic, choose Add application, then GitHub, then `Hollow-Manor`.
   It picks up `codemagic.yaml` from the repo.
2. **Start a build** with the workflow **Hollow Manor TestFlight** on `main`. This registers the bundle ID with
   Apple. The upload at the end fails the first time because the app doesn't exist in App Store Connect yet.
   That's expected.
3. **Create the app in App Store Connect.** On appstoreconnect.apple.com, go to Apps, press the plus button, then
   New App. Platform iOS. Name `Hollow Manor` (or something close if that's taken). Bundle ID:
   `com.hollowmanor.HollowManor`. SKU: `hollowmanor`.
4. **Build again.** This time it uploads. Apple processes it in about 5 to 30 minutes, then it shows up in
   TestFlight. Add yourself to an Internal Testing group under the app's TestFlight tab the first time.
