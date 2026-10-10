// GENERATED from docs/design/tokens.json — do not edit by hand; regenerate or edit tokens.json.
// Starting point for ms_app/lib/design_system/. Run `dart format` + `flutter analyze` after copying.
import 'package:flutter/material.dart';

/// Every colour token of the МС design system. Two instances: [MsPalette.evening] (default) and [MsPalette.day].
@immutable
class MsPalette {
  /// Фон экрана и нижнего листа на «Доме». День = paper из ms_theme.dart.
  final Color ground;
  /// Карточки, строки списков, таб-бар. День = paperWarm из ms_theme.dart.
  final Color surface;
  /// Всё, что лежит на карточке: поля ввода, чипы, сегмент-контрол, превью файла.
  final Color surfaceRaised;
  /// Волосяные линии 1px: разделители, обводка полей и неактивных чипов. Декоративная — не несёт смысла одна.
  final Color line;
  /// Основной текст и иконки на ground, surface, surface-raised. День = ink из ms_theme.dart.
  final Color ink;
  /// Вторичный текст: подписи, моно-мета, неактивные табы. На ground, surface, surface-raised ≥ 4.5:1 в обеих темах.
  final Color inkMuted;
  /// Только не-текст и выключенное: прошедшие дни месяца, плейсхолдер, точки-разделители. Не для читаемого текста.
  final Color inkFaint;
  /// Цвет Михаила: точка автора, полоса события, его доля в копилке, аватар. Знак, не текст. День = PartnerColors.michael из кода.
  final Color michael;
  /// Подложка под знаком Михаила: фон аватара, выбранный фильтр «Михаил».
  final Color michaelSoft;
  /// Цвет Софии: точка автора, полоса события, её доля в копилке, аватар. Знак, не текст. День = PartnerColors.sofia из кода.
  final Color sofia;
  /// Подложка под знаком Софии: фон аватара, выбранный фильтр «София».
  final Color sofiaSoft;
  /// Текст и иконки на заливке michael или sofia (карточка письма-капсулы, аватар с буквой).
  final Color onPartner;
  /// Главный акцент интерфейса: заливка основной кнопки, активная вкладка, сегодняшний день. Текст на нём — on-flame. Днём это охра (3.1:1 к surface), а не цвет пламени в сцене — для сцены есть candle-flame.
  final Color flame;
  /// Сцена: пламя свечи и бренд-огонёк в иконках статуса свечи. Яркое в обеих темах; не для текста и не для заливки кнопок.
  final Color candleFlame;
  /// Текст и иконки на заливке flame.
  final Color onFlame;
  /// Тёплая подложка: строка «свеча горит», выбранный чип, подсветка нового.
  final Color flameSoft;
  /// Ореол горящей свечи в сцене комнаты. Только свечение, не заливка интерфейса.
  final Color flameGlow;
  /// Текстовые действия: «Добавить», «Смотреть ›», «Все». На ground и surface ≥ 4.5:1.
  final Color link;
  /// Терракотовая точка монограммы — ровно как на иконке (accent из ms_theme.dart). Только в монограмме, не в интерфейсе.
  final Color brandDot;
  /// «Синхронизировано», «цель собрана». Всегда со словом или иконкой. День = success из кода.
  final Color success;
  /// «Ждёт синка», «документ скоро истекает». Днём только заливка бейджа с текстом ink или иконка 24px+ (на paper 2.4:1 — значение из кода сохранено).
  final Color warn;
  /// Текст на заливке warn (бейдж «истекает через 54 дня»).
  final Color onWarn;
  /// Удаление, ошибка синка. Всегда со словом и иконкой — рядом с цветом Софии его не отличить по одному оттенку.
  final Color danger;
  /// Текст на заливке danger (кнопка «Стереть всё»).
  final Color onDanger;
  /// Кольцо фокуса 2px с зазором 2px цвета ground. ≥ 3:1 на ground, surface, surface-raised в обеих темах.
  final Color focusRing;
  /// Затемнение под bottom sheet и диалогом.
  final Color scrim;
  /// Фон экрана карты лояльности на кассе — белый в любой теме, чтобы сканер кассы читал код.
  final Color cardPaper;
  /// Штрихи штрихкода и QR, текст на card-paper.
  final Color cardInk;
  /// Вторичный текст на card-paper: «добавил Михаил · EAN-13», «экран не гаснет».
  final Color cardInkMuted;
  /// Кнопки и чипы на card-paper: «Показать QR», «Яркость 100%».
  final Color cardChip;
  /// Сцена «Комната»: стена.
  final Color sceneWall;
  /// Сцена: нижняя панель стены под молдингом.
  final Color sceneWallLow;
  /// Сцена: пол.
  final Color sceneFloor;
  /// Сцена: ковёр под креслом.
  final Color sceneRug;
  /// Сцена: рама окна, подоконник, рамка фото, ножки кресла.
  final Color sceneWood;
  /// Сцена: тень под подоконником, торцы дерева.
  final Color sceneWoodDark;
  /// Сцена: льняные шторы по бокам окна.
  final Color sceneCurtain;
  /// Сцена: складки штор.
  final Color sceneCurtainShade;
  /// Сцена: обивка кресла (спинка).
  final Color sceneFabric;
  /// Сцена: подлокотники и основание кресла.
  final Color sceneFabricShade;
  /// Сцена: подушка сиденья — на ней лежит собака.
  final Color sceneFabricLight;
  /// Сцена: листья растения на подоконнике.
  final Color scenePlant;
  /// Сцена: глиняный горшок.
  final Color scenePot;
  /// Сцена: бумажная записка на стене. Текст на ней — scene-note-ink.
  final Color sceneNote;
  /// Сцена: почерк на записке.
  final Color sceneNoteInk;
  /// Сцена: мягкие тени под креслом и предметами.
  final Color sceneShadow;
  /// Сцена: воск свечи.
  final Color candleWax;
  /// Сцена: светлая сердцевина пламени.
  final Color flameCore;
  /// Басенджи: чёрная шерсть.
  final Color dogCoat;
  /// Басенджи: объём — бедро, морщинки на лбу, дальнее ухо.
  final Color dogCoatShade;
  /// Басенджи: белые грудь, лапы, проточина, кончик хвоста.
  final Color dogWhite;
  /// Басенджи: внутренняя сторона уха.
  final Color dogEar;
  /// Басенджи: глаз (миндалевидный) — светлее шерсти, чтобы читался на чёрном.
  final Color dogEye;
  /// Окно ночью (верх). Небо следует за реальным временем, не за темой.
  final Color skyNight;
  /// Окно ночью (у горизонта).
  final Color skyNightLow;
  /// Окно днём (верх).
  final Color skyDay;
  /// Окно днём (у горизонта).
  final Color skyDayLow;
  /// Окно в пасмурный день и в дождь.
  final Color skyOvercast;
  /// Надпись погоды на ночном небе.
  final Color skyInkNight;
  /// Надпись погоды на дневном и пасмурном небе.
  final Color skyInkDay;
  /// Капли, снежинки, облака и луна за окном.
  final Color weatherMark;

  const MsPalette({
    required this.ground,
    required this.surface,
    required this.surfaceRaised,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.michael,
    required this.michaelSoft,
    required this.sofia,
    required this.sofiaSoft,
    required this.onPartner,
    required this.flame,
    required this.candleFlame,
    required this.onFlame,
    required this.flameSoft,
    required this.flameGlow,
    required this.link,
    required this.brandDot,
    required this.success,
    required this.warn,
    required this.onWarn,
    required this.danger,
    required this.onDanger,
    required this.focusRing,
    required this.scrim,
    required this.cardPaper,
    required this.cardInk,
    required this.cardInkMuted,
    required this.cardChip,
    required this.sceneWall,
    required this.sceneWallLow,
    required this.sceneFloor,
    required this.sceneRug,
    required this.sceneWood,
    required this.sceneWoodDark,
    required this.sceneCurtain,
    required this.sceneCurtainShade,
    required this.sceneFabric,
    required this.sceneFabricShade,
    required this.sceneFabricLight,
    required this.scenePlant,
    required this.scenePot,
    required this.sceneNote,
    required this.sceneNoteInk,
    required this.sceneShadow,
    required this.candleWax,
    required this.flameCore,
    required this.dogCoat,
    required this.dogCoatShade,
    required this.dogWhite,
    required this.dogEar,
    required this.dogEye,
    required this.skyNight,
    required this.skyNightLow,
    required this.skyDay,
    required this.skyDayLow,
    required this.skyOvercast,
    required this.skyInkNight,
    required this.skyInkDay,
    required this.weatherMark,
  });

  static const MsPalette evening = MsPalette(
    ground: Color(0xFF14110E),
    surface: Color(0xFF1D1915),
    surfaceRaised: Color(0xFF28231E),
    line: Color(0xFF3A332C),
    ink: Color(0xFFF4EDE4),
    inkMuted: Color(0xFFAEA498),
    inkFaint: Color(0xFF7D746A),
    michael: Color(0xFF80A8EB),
    michaelSoft: Color(0xFF223047),
    sofia: Color(0xFFEF8C79),
    sofiaSoft: Color(0xFF45271F),
    onPartner: Color(0xFF14110E),
    flame: Color(0xFFF2B65E),
    candleFlame: Color(0xFFF6B552),
    onFlame: Color(0xFF1E150B),
    flameSoft: Color(0xFF3A2B17),
    flameGlow: Color(0x52F2B65E),
    link: Color(0xFFF2B65E),
    brandDot: Color(0xFFC4622D),
    success: Color(0xFF88C39B),
    warn: Color(0xFFE8C26A),
    onWarn: Color(0xFF1E150B),
    danger: Color(0xFFF07B70),
    onDanger: Color(0xFF1E0F0D),
    focusRing: Color(0xFFF2B65E),
    scrim: Color(0x9E080604),
    cardPaper: Color(0xFFFFFFFF),
    cardInk: Color(0xFF000000),
    cardInkMuted: Color(0xFF4A4A4A),
    cardChip: Color(0xFFEFEFEF),
    sceneWall: Color(0xFF2B231D),
    sceneWallLow: Color(0xFF231C17),
    sceneFloor: Color(0xFF1A1410),
    sceneRug: Color(0xFF3B2B22),
    sceneWood: Color(0xFF5C4231),
    sceneWoodDark: Color(0xFF3D2C20),
    sceneCurtain: Color(0xFF5B3B2F),
    sceneCurtainShade: Color(0xFF472E25),
    sceneFabric: Color(0xFF34504B),
    sceneFabricShade: Color(0xFF283E3A),
    sceneFabricLight: Color(0xFF41635D),
    scenePlant: Color(0xFF4E6B45),
    scenePot: Color(0xFF8A4F33),
    sceneNote: Color(0xFFE9DCC4),
    sceneNoteInk: Color(0xFF2A221B),
    sceneShadow: Color(0x59000000),
    candleWax: Color(0xFFEFE2CB),
    flameCore: Color(0xFFFFF3D6),
    dogCoat: Color(0xFF16120F),
    dogCoatShade: Color(0xFF2C241E),
    dogWhite: Color(0xFFF2EBE1),
    dogEar: Color(0xFF6A4A43),
    dogEye: Color(0xFF6B4F3A),
    skyNight: Color(0xFF18213B),
    skyNightLow: Color(0xFF33405F),
    skyDay: Color(0xFF8FBBE3),
    skyDayLow: Color(0xFFD8E8F3),
    skyOvercast: Color(0xFF9AA3AD),
    skyInkNight: Color(0xFFF4EDE4),
    skyInkDay: Color(0xFF1A2633),
    weatherMark: Color(0xFFE6EEF6),
  );

  static const MsPalette day = MsPalette(
    ground: Color(0xFFFAF6F0),
    surface: Color(0xFFF3EBDF),
    surfaceRaised: Color(0xFFFFFDF9),
    line: Color(0xFFE2D5C3),
    ink: Color(0xFF1A1614),
    inkMuted: Color(0xFF695E54),
    inkFaint: Color(0xFFA3988C),
    michael: Color(0xFF3D5A6C),
    michaelSoft: Color(0xFFDBE4EA),
    sofia: Color(0xFFB0563B),
    sofiaSoft: Color(0xFFF1DDD3),
    onPartner: Color(0xFFFFFFFF),
    flame: Color(0xFFBB761F),
    candleFlame: Color(0xFFF2A93B),
    onFlame: Color(0xFF1E150B),
    flameSoft: Color(0xFFF6E2C2),
    flameGlow: Color(0x42E9A445),
    link: Color(0xFF8B4C10),
    brandDot: Color(0xFFC4622D),
    success: Color(0xFF4A7C59),
    warn: Color(0xFFC99A2E),
    onWarn: Color(0xFF1A1614),
    danger: Color(0xFFA94442),
    onDanger: Color(0xFFFFFFFF),
    focusRing: Color(0xFF8B4C10),
    scrim: Color(0x661A1614),
    cardPaper: Color(0xFFFFFFFF),
    cardInk: Color(0xFF000000),
    cardInkMuted: Color(0xFF4A4A4A),
    cardChip: Color(0xFFEFEFEF),
    sceneWall: Color(0xFFEADCC8),
    sceneWallLow: Color(0xFFDDCBB2),
    sceneFloor: Color(0xFFB98D66),
    sceneRug: Color(0xFFD9B597),
    sceneWood: Color(0xFFA8774E),
    sceneWoodDark: Color(0xFF86593A),
    sceneCurtain: Color(0xFFCF9A78),
    sceneCurtainShade: Color(0xFFB98463),
    sceneFabric: Color(0xFF6F978E),
    sceneFabricShade: Color(0xFF5A8077),
    sceneFabricLight: Color(0xFF88AEA5),
    scenePlant: Color(0xFF5F8A52),
    scenePot: Color(0xFFB8673F),
    sceneNote: Color(0xFFFFFAF0),
    sceneNoteInk: Color(0xFF2A221B),
    sceneShadow: Color(0x29462D14),
    candleWax: Color(0xFFF6ECDA),
    flameCore: Color(0xFFFFF6E0),
    dogCoat: Color(0xFF1B1612),
    dogCoatShade: Color(0xFF3A312A),
    dogWhite: Color(0xFFFBF7F1),
    dogEar: Color(0xFF8A6159),
    dogEye: Color(0xFF5C4230),
    skyNight: Color(0xFF18213B),
    skyNightLow: Color(0xFF33405F),
    skyDay: Color(0xFF8FBBE3),
    skyDayLow: Color(0xFFD8E8F3),
    skyOvercast: Color(0xFF9AA3AD),
    skyInkNight: Color(0xFFF4EDE4),
    skyInkDay: Color(0xFF1A2633),
    weatherMark: Color(0xFFE6EEF6),
  );
}

/// Spacing, radius and size tokens (logical px).
abstract final class MsSpace {
  /// Иконка ↔ подпись, точка автора ↔ мета.
  static const double space1 = 4.0;
  /// Зазор между чипами и между строками списка. spaceSm из кода.
  static const double space2 = 8.0;
  /// Зазор между карточками в ленте; блок даты ↔ полоса события.
  static const double space3 = 12.0;
  /// Поле экрана слева/справа, внутренний отступ строки. spaceMd из кода.
  static const double space4 = 16.0;
  /// Внутренний отступ крупной карточки (копилка, статистика).
  static const double space5 = 20.0;
  /// Между секциями экрана. spaceLg из кода.
  static const double space6 = 24.0;
  /// Над заголовком экрана, вокруг пустых состояний. spaceXl из кода.
  static const double space8 = 32.0;
  /// Минимальная зона нажатия — включая свечу, окно и собаку в сцене.
  static const double tapMin = 48.0;
  /// Высота таб-бара без системного отступа снизу.
  static const double tabbarH = 64.0;
}

abstract final class MsRadius {
  /// Чипы-бейджи, превью файла, блок даты, сцена-окно. radiusSm из кода.
  static const double radiusSm = 8.0;
  /// Кнопки, поля ввода, строки списка. radiusMd из кода.
  static const double radiusMd = 14.0;
  /// Карточки, нижний лист «Сегодня», bottom sheet. radiusLg из кода.
  static const double radiusLg = 20.0;
  /// Фильтр-чипы, сегмент-контрол, статус синхронизации, аватары.
  static const double radiusPill = 999.0;
}

/// Font families — bundled as assets (see pubspec snippet in docs/design/IMPLEMENTATION.md).
abstract final class MsFonts {
  static const String sans = 'Onest';
  static const String mono = 'IBMPlexMono';
  static const String serif = 'PTSerif';
}

/// Text styles from tokens.json `type.groups`. Colour is applied by the theme / widget, not here.
abstract final class MsText {
  /// Одна строка поверх сцены комнаты. Только здесь и на онбординге.
  static const TextStyle roomGreeting = TextStyle(fontFamily: MsFonts.serif, fontSize: 30.0, height: 1.1333, fontWeight: FontWeight.w700);
  /// Заголовок вкладки, слева, под моно-надбровьем.
  static const TextStyle screenTitle = TextStyle(fontFamily: MsFonts.sans, fontSize: 28.0, height: 1.1429, fontWeight: FontWeight.w700, letterSpacing: -0.280);
  /// Заголовок листа, диалога, крупной карточки.
  static const TextStyle title = TextStyle(fontFamily: MsFonts.sans, fontSize: 20.0, height: 1.3000, fontWeight: FontWeight.w600);
  /// Название в строке списка: событие, файл, копилка.
  static const TextStyle titleSm = TextStyle(fontFamily: MsFonts.sans, fontSize: 17.0, height: 1.2941, fontWeight: FontWeight.w600);
  /// Основной текст, поля ввода, описания.
  static const TextStyle body = TextStyle(fontFamily: MsFonts.sans, fontSize: 15.0, height: 1.4667, fontWeight: FontWeight.w400);
  /// Текст кнопок, выделение внутри body.
  static const TextStyle bodyStrong = TextStyle(fontFamily: MsFonts.sans, fontSize: 15.0, height: 1.4667, fontWeight: FontWeight.w600);
  /// Подсказки под полями, пояснения в карточках.
  static const TextStyle bodySm = TextStyle(fontFamily: MsFonts.sans, fontSize: 13.0, height: 1.3846, fontWeight: FontWeight.w400);
  /// Подпись под иконкой таб-бара.
  static const TextStyle tabLabel = TextStyle(fontFamily: MsFonts.sans, fontSize: 11.0, height: 1.2727, fontWeight: FontWeight.w500);
  /// Надбровье секции. ВСЕГДА прописными (text-transform: uppercase / toUpperCase()).
  static const TextStyle eyebrow = TextStyle(fontFamily: MsFonts.mono, fontSize: 11.0, height: 1.2727, fontWeight: FontWeight.w500, letterSpacing: 0.880, fontFeatures: [FontFeature.tabularFigures()]);
  /// Мета под названием: время, автор, размер файла, «через 11 дней».
  static const TextStyle meta = TextStyle(fontFamily: MsFonts.mono, fontSize: 12.0, height: 1.3333, fontWeight: FontWeight.w400, fontFeatures: [FontFeature.tabularFigures()]);
  /// Большие счётчики: дней вместе, дней до годовщины. Табличные цифры.
  static const TextStyle numberXl = TextStyle(fontFamily: MsFonts.mono, fontSize: 32.0, height: 1.1250, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()]);
  /// Суммы копилок, номер карты. Табличные цифры, тонкий пробел в тысячах.
  static const TextStyle numberMd = TextStyle(fontFamily: MsFonts.mono, fontSize: 17.0, height: 1.2941, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
  /// Число в блоке даты слева от события.
  static const TextStyle dateNum = TextStyle(fontFamily: MsFonts.mono, fontSize: 18.0, height: 1.1111, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
  /// Температура, «написанная» за окном комнаты.
  static const TextStyle weatherTemp = TextStyle(fontFamily: MsFonts.serif, fontSize: 34.0, height: 1.0588, fontWeight: FontWeight.w400);
  /// Текст записки на стене комнаты (PT Serif Italic).
  static const TextStyle noteHand = TextStyle(fontFamily: MsFonts.serif, fontSize: 13.0, height: 1.2308, fontWeight: FontWeight.w400, fontStyle: FontStyle.italic);
  /// Монограмма в тексте онбординга. Знак на экранах — файл из Logos, не набор.
  static const TextStyle monogram = TextStyle(fontFamily: MsFonts.serif, fontSize: 40.0, height: 1.0000, fontWeight: FontWeight.w700);
}

/// Theme extension so widgets read tokens via `context.ms`.
@immutable
class MsThemeExtension extends ThemeExtension<MsThemeExtension> {
  final MsPalette c;
  const MsThemeExtension(this.c);

  @override
  MsThemeExtension copyWith({MsPalette? c}) => MsThemeExtension(c ?? this.c);

  @override
  MsThemeExtension lerp(covariant ThemeExtension<MsThemeExtension>? other, double t) =>
      (other is MsThemeExtension && t >= 0.5) ? other : this;
}

extension MsThemeContext on BuildContext {
  MsPalette get ms => Theme.of(this).extension<MsThemeExtension>()!.c;
}
