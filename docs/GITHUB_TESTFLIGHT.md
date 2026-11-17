# TestFlight builds from GitHub

The **TestFlight** workflow (`.github/workflows/testflight.yml`) builds, signs and uploads Hollow Manor on
GitHub's Mac runners. It only runs when you start it by hand. The **Tests** workflow runs the game's tests on
every push, on Linux, so it never waits for a Mac.

It works the same way as Truck Sim: **fastlane match** keeps the shared App Store certificate and each app's
profile, encrypted in the private **ios-certificates** repository. The App Store Connect key comes from there too:
every `AuthKey_<KEY ID>.p8` in it is tried until Apple accepts one. The first run also registers the bundle ID
`com.hollowmanor.HollowManor` with Apple.

## One-time setup

### 1. Repository secrets

Secrets belong to one repository, so Hollow Manor needs its own copies of the ones Truck Sim uses.
On github.com, open **Hollow-Manor**, then **Settings**, **Secrets and variables**, **Actions**,
**New repository secret**:

| Name | Value |
|---|---|
| `MATCH_PASSWORD` | The same match password Truck Sim uses (it unlocks the certificates) |
| `CERTS_REPO_TOKEN` | A token with **Contents: Read and write** on ios-certificates. The one Truck Sim uses works. |
| `ASC_ISSUER_ID` | The Issuer ID: App Store Connect, Users and Access, Integrations, App Store Connect API |

Optional, only if the key isn't in ios-certificates: `ASC_KEY_ID` and `ASC_KEY_P8` (the whole `.p8` file).

Never paste a key, password or token into a chat. They only go into GitHub secrets.

### 2. The app in App Store Connect

TestFlight needs the app to exist in App Store Connect, and Apple only lets you create it on the website:

1. Run the job once (see below). It registers the bundle ID and makes the signing profile. The upload at the
   end fails because the app doesn't exist yet. That's expected.
2. On appstoreconnect.apple.com, go to **Apps**, press **+**, then **New App**. Platform iOS, name
   `Hollow Manor` (or something close if it's taken), bundle ID `com.hollowmanor.HollowManor`, SKU `hollowmanor`.
3. Run the job again. This time it uploads.

## Sending a build

On GitHub, open **Actions**, then **TestFlight**, then **Run workflow**, then **Run workflow** again.
If it sits on "Waiting for a runner" for more than 10 minutes, cancel it and run it again with another Mac picked.
It runs the tests, then builds, signs and uploads, in about 10 to 15 minutes. Apple then processes the build,
and it appears in TestFlight. The first time, add yourself to an Internal Testing group in the app's
TestFlight tab. The "What to Test" notes come from `store/en-US/testflight/what_to_test.txt`.
