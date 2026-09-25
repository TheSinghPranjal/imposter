# Find the Imposter

A playful pass-the-phone social deduction party game for Flutter.

## How it works

1. Add 3–20 player names  
2. Configure difficulty, imposters, and optional hints  
3. Pass the phone — each player long-presses to privately reveal their card  
4. Discuss and give clues **outside the app**  
5. Tap **Again!** for a fresh word and new imposters  

## Product rules baked in

- Imposters are never Player 1 or Player 2  
- Starting player is chosen independently of imposter selection  
- Imposters never see the secret word  
- Secrets hide when the app is backgrounded  

## Stack

- Flutter + Riverpod  
- Offline 600-word pack (`assets/data/imposter_words.json`)  
- SharedPreferences for settings  

## Run

```bash
flutter pub get
flutter run
flutter test
```
