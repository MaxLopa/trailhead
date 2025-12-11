# TrailHead Mechs

TrailHead is a passion project for booking mountain bike service with both
bike shops and independent mechanics.

Riders can search for trusted mechanics and shops, filtering by price, rating,
location, availability, and parts stock. Aspiring mechanics can use the
platform to find work, gain experience, and build a reputation in the industry.

---

## Currently Implemented
- Search and sort mechanics based on service type, availability and rating.
- SignIn and Login via email through FirebaseAuth.

## For Mechs
- SignUp as a mech (mechanic) and activate underlying user account to be a mechanic one
- Setup a mech Service menu using a precreated collection of Generic Genres (PartCategories w/ specific servicetypes w/ specific brands)
- Setup a mechweekly availability system for future booking logic
- View mech dashboard

## Tech Stack

- Flutter (Dart, Swift & Kotlin additionally good to know)
- Firebase (Auth, Firestore,)
- Platform targets:
  - Android
  - iOS
  - Web

## TODO
- Reimplement the Generic Genres collection
- Implement additional query indicies collections for location base and availability based query
- Add Service Booking (Go through all booking states, tie booking to schedule, tie query to locations and add restrictions/rules to booking)
- Tweak Mech Preview and Add Mech History


---

## Getting Started

### Prerequisites

- Flutter installed (`flutter doctor` should be all green)
- Firebase project set up with config files:
  - new version of `google-services.json` for Android to setup appropriate api's
  - new version  of `GoogleService-Info.plist` for iOS/macOS to setup appropriate api's
  - `firebase_options.dart` generated via `flutterfire configure`, program will crash as

### Setup

```bash
# Clone the repo
git clone https://github.com/<your-username>/trailhead.git
cd trailhead

# Install dependencies
flutter pub get

# Run the app
flutter run
