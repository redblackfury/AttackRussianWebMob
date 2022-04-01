# Атакуємо WEB сайти рашистів зі смартфону

Завантажте APK файл на свій смартфон і встановіть його:

[![Attack Russian Web preview](./app/assets/dlAndroid.svg)](https://github.com/redblackfury/AttackRussianWebMob/releases/download/v5.0/attack_ru_web_v5.0.apk)

Хочете запустити на компьютері? Вам сюди: [AttackRussianWeb for Windows/Linux/Mac](https://github.com/redblackfury/AttackRussianWeb)


# Переконатися що це не вірус

За посиланням ви можете побачити результати перевірки файлу від VirusTotal ([що це таке?](https://uk.wikipedia.org/wiki/Virustotal))
[![Attack Russian Web is not a virus](./app/assets/novir.svg)](https://www.virustotal.com/gui/file/5273024f1fd7169f176943d1856fdd66345e94f41bac550c1272da94c6afa5da)


Також, ви можете перевірити наш .apk файл перед встановленням власноруч використовуючи [форму перевірки VirusTotal](https://www.virustotal.com/gui/home/upload)

# Як виглядає застосунок / Preview

![Attack Russian Web preview](./app/assets/preview.svg)


# Як зібрати застосунок власноруч

Встановіть Flutter SDK https://docs.flutter.dev/get-started/install

Потім склонуйте репозіторій і виконайте в консолі:

```
cd app
flutter build apk --release --no-sound-null-safety
```

Готово, скопіюйте APK файл на ваш телефон і встановіть.

# Чи можна забрати цей застосунок для iOS ?

В теорії так, читайте тут: https://docs.flutter.dev/deployment/ios

Ми не постачаємо версію для iOS тому що доля Android телефонів займає 81.7% ринку в Україні і 70.97% в світі і продовжує зростати.

