import 'api/api_client.dart';
import 'settings.dart';

/// Каждая строка: [ўзбекча лотин, ўзбекча кирилл, русский].
const Map<String, List<String>> _strings = {
  'appName': ['OXO', 'OXO', 'OXO'],
  'appSub': ['Ishlar hisoboti', 'Ишлар ҳисоботи', 'Отчёт о работах'],
  'cancel': ['Bekor qilish', 'Бекор қилиш', 'Отмена'],
  'retry': ['Qayta urinish', 'Қайта уриниш', 'Повторить'],
  'yes': ['Ha', 'Ҳа', 'Да'],
  'no': ['Yo\'q', 'Йўқ', 'Нет'],
  'networkError': [
    'Serverga ulanib bo\'lmadi. Internetni tekshiring.',
    'Серверга уланиб бўлмади. Интернетни текширинг.',
    'Нет связи с сервером. Проверьте интернет.',
  ],
  'notConfigured': [
    'Ilova server manzilisiz yig\'ilgan',
    'Илова сервер манзилисиз йиғилган',
    'Приложение собрано без адреса сервера',
  ],

  // вход
  'login': ['Login', 'Логин', 'Логин'],
  'password': ['Parol', 'Парол', 'Пароль'],
  'loginHint': ['Loginni kiriting', 'Логинни киритинг', 'Введите логин'],
  'passwordHint': ['Parolni kiriting', 'Паролни киритинг', 'Введите пароль'],
  'enter': ['KIRISH', 'КИРИШ', 'ВОЙТИ'],
  'loginEmpty': ['Login va parolni kiriting', 'Логин ва паролни киритинг', 'Введите логин и пароль'],
  'loginSameAccount': [
    'OXO tizimidagi login va parolingiz bilan kiring',
    'OXO тизимидаги логин ва паролингиз билан киринг',
    'Войдите с логином и паролем системы OXO',
  ],

  // навигация
  'navHome': ['Bosh sahifa', 'Бош саҳифа', 'Главная'],
  'navJobs': ['Ishlarim', 'Ишларим', 'Мои работы'],
  'navProfile': ['Profil', 'Профил', 'Профиль'],

  // главная
  'hello': ['Assalomu alaykum', 'Ассалому алайкум', 'Здравствуйте'],
  'dayOff': ['Bugun dam olish kuni', 'Бугун дам олиш куни', 'Сегодня выходной'],
  'workDay': ['Ish kuni · 09:00–18:00', 'Иш куни · 09:00–18:00', 'Рабочий день · 09:00–18:00'],
  'norm': ['Kunlik me\'yor', 'Кунлик меъёр', 'Дневная норма'],
  'today': ['Bugun', 'Бугун', 'Сегодня'],
  'week': ['Hafta', 'Ҳафта', 'Неделя'],
  'month': ['Oy', 'Ой', 'Месяц'],
  'done': ['Bajarildi', 'Бажарилди', 'Выполнено'],
  'unitsHint': [
    'Joyiga borib = 1, masofadan = 0,5',
    'Жойига бориб = 1, масофадан = 0,5',
    'На выезде = 1, удалённо = 0,5',
  ],
  'addJob': ['ISH QO\'SHISH', 'ИШ ҚЎШИШ', 'ДОБАВИТЬ РАБОТУ'],
  'todayJobs': ['Bugungi ishlar', 'Бугунги ишлар', 'Работы за сегодня'],
  'noJobs': ['Ishlar qayd etilmagan', 'Ишлар қайд этилмаган', 'Работ нет'],
  'trackOn': ['Joylashuv yozilmoqda', 'Жойлашув ёзилмоқда', 'Местоположение записывается'],
  'trackIdle': [
    'Ish vaqtidan tashqari — joylashuv yozilmaydi',
    'Иш вақтидан ташқари — жойлашув ёзилмайди',
    'Вне рабочего времени — местоположение не пишется',
  ],
  'trackOff': ['Joylashuv o\'chiq', 'Жойлашув ўчиқ', 'Геолокация выключена'],
  'trackPending': ['yuborilmagan', 'юборилмаган', 'не отправлено'],
  'lastSent': ['oxirgi yuborish', 'охирги юбориш', 'последняя отправка'],

  // работа
  'newJob': ['Yangi ish', 'Янги иш', 'Новая работа'],
  'kindOffline': ['Joyiga borib', 'Жойига бориб', 'На выезде'],
  'kindOnline': ['Masofadan', 'Масофадан', 'Удалённо'],
  'kindOnlineHint': ['telefon yoki AnyDesk', 'телефон ёки AnyDesk', 'телефон или AnyDesk'],
  'workType': ['Ish turi', 'Иш тури', 'Вид работы'],
  'chooseWorkType': ['Ish turini tanlang', 'Иш турини танланг', 'Выберите вид работы'],
  'orgName': ['Tashkilot', 'Ташкилот', 'Организация'],
  'description': ['Nima qilindi', 'Нима қилинди', 'Что сделано'],
  'murojaatNo': ['Murojaat raqami', 'Мурожаат рақами', 'Номер обращения'],
  'optional': ['ixtiyoriy', 'ихтиёрий', 'необязательно'],
  'applicantName': ['Murojaatchi', 'Мурожаатчи', 'Заявитель'],
  'applicantPhone': ['Murojaatchi telefoni', 'Мурожаатчи телефони', 'Телефон заявителя'],
  'started': ['Boshlandi', 'Бошланди', 'Начало'],
  'finished': ['Tugadi', 'Тугади', 'Окончание'],
  'place': ['Joylashuv', 'Жойлашув', 'Местоположение'],
  'placeDetecting': ['Aniqlanmoqda…', 'Аниқланмоқда…', 'Определяется…'],
  'placeRefresh': ['Yangilash', 'Янгилаш', 'Обновить'],
  'photos': ['Bajarilgan ish rasmlari', 'Бажарилган иш расмлари', 'Фото выполненной работы'],
  'camera': ['Kamera', 'Камера', 'Камера'],
  'gallery': ['Galereya', 'Галерея', 'Галерея'],
  'send': ['YUBORISH', 'ЮБОРИШ', 'ОТПРАВИТЬ'],
  'sent': ['Ish yuborildi', 'Иш юборилди', 'Работа отправлена'],
  'required': ['To\'ldirilishi shart', 'Тўлдирилиши шарт', 'Обязательное поле'],
  'needPhoto': ['Kamida 1 ta rasm kerak', 'Камида 1 та расм керак', 'Нужно хотя бы 1 фото'],
  'needPlace': [
    'Joyiga borib bajarilgan ish uchun joylashuv kerak',
    'Жойига бориб бажарилган иш учун жойлашув керак',
    'Для работы на выезде нужно местоположение',
  ],
  'timeOrder': [
    'Tugash vaqti boshlanishdan oldin bo\'lmasin',
    'Тугаш вақти бошланишдан олдин бўлмасин',
    'Окончание не может быть раньше начала',
  ],
  'timeFuture': ['Vaqt hali kelmagan', 'Вақт ҳали келмаган', 'Время ещё не наступило'],
  'directAppeal': ['To\'g\'ridan-to\'g\'ri murojaat', 'Тўғридан-тўғри мурожаат', 'Прямое обращение'],

  // мои работы
  'deleteJob': ['Ishni o\'chirish', 'Ишни ўчириш', 'Удалить работу'],
  'deleteAsk': [
    'Bu ish o\'chirilsinmi?',
    'Бу иш ўчирилсинми?',
    'Удалить эту работу?',
  ],
  'deleted': ['O\'chirildi', 'Ўчирилди', 'Удалено'],
  'minutes': ['daq', 'дақ', 'мин'],

  // геолокация
  'gpsOff': [
    'Telefonda joylashuv (GPS) o\'chiq. Sozlamalardan yoqing.',
    'Телефонда жойлашув (GPS) ўчиқ. Созламалардан ёқинг.',
    'На телефоне выключена геолокация (GPS). Включите в настройках.',
  ],
  'gpsDenied': [
    'Joylashuvga ruxsat berilmadi',
    'Жойлашувга рухсат берилмади',
    'Нет разрешения на геолокацию',
  ],
  'gpsDeniedForever': [
    'Joylashuv ruxsati yopilgan. Telefon sozlamalaridan OXO ilovasiga ruxsat bering.',
    'Жойлашув рухсати ёпилган. Телефон созламаларидан OXO иловасига рухсат беринг.',
    'Доступ к геолокации запрещён. Разрешите его приложению OXO в настройках телефона.',
  ],
  'gpsUnavailable': [
    'Joylashuvni aniqlab bo\'lmadi. Ochiq joyga chiqing.',
    'Жойлашувни аниқлаб бўлмади. Очиқ жойга чиқинг.',
    'Не удалось определить место. Выйдите на открытое место.',
  ],

  // профиль
  'office': ['Bo\'lim', 'Бўлим', 'Подразделение'],
  'language': ['Til', 'Тил', 'Язык'],
  'darkTheme': ['Qorong\'i mavzu', 'Қоронғи мавзу', 'Тёмная тема'],
  'logout': ['Chiqish', 'Чиқиш', 'Выйти'],
  'logoutAsk': [
    'Hisobdan chiqilsinmi?',
    'Ҳисобдан чиқилсинми?',
    'Выйти из учётной записи?',
  ],

  // давомат
  'navAttendance': ['Davomat', 'Давомат', 'Посещаемость'],
  'attendance': ['Davomat', 'Давомат', 'Посещаемость'],
  'checkIn': ['Keldim', 'Келдим', 'Пришёл'],
  'checkInBtn': ['KELDIM', 'КЕЛДИМ', 'ПРИШЁЛ'],
  'checkOut': ['Ketdim', 'Кетдим', 'Ушёл'],
  'locatingPlace': ['Joylashuv aniqlanmoqda…', 'Жойлашув аниқланмоқда…', 'Определение местоположения…'],
  'sending': ['Yuborilmoqda…', 'Юборилмоқда…', 'Отправка…'],
  'holidayToday': ['Bugun dam olish kuni', 'Бугун дам олиш куни', 'Сегодня выходной'],
  'excusedStatus': ['Sababli', 'Сабабли', 'Уважительная причина'],
  'workStartTolerance': [
    'Ish {start} da boshlanadi · kechikish {tolerance} daqiqadan keyin',
    'Иш {start} да бошланади · кечикиш {tolerance} дақиқадан кейин',
    'Работа начинается в {start} · опоздание после {tolerance} минут',
  ],
  'checkInChecks': [
    'Yuz va joylashuv tekshiriladi',
    'Юз ва жойлашув текширилади',
    'Проверяются лицо и местоположение',
  ],
  'checkedInOnTime': ['Keldim {time}', 'Келдим {time}', 'Пришёл {time}'],
  'checkedInLate': [
    'Keldim {time} · {minutes} daqiqa kechikdingiz',
    'Келдим {time} · {minutes} дақиқа кечикдингиз',
    'Пришёл {time} · опоздание на {minutes} мин',
  ],
  'insideOffice': ['Ish joyida', 'Иш жойида', 'На рабочем месте'],
  'outsideOffice': ['Ish joyidan tashqarida', 'Иш жойидан ташқарида', 'Вне рабочего места'],
  'inBuilding': ['Binoda', 'Бинода', 'В здании'],
  'hoursShort': ['soat', 'соат', 'ч'],
  'minutesShort': ['daqiqa', 'дақиқа', 'мин'],
  'earlyDeparture': ['erta ketdi', 'эрта кетди', 'ранний уход'],
  'distanceLabel': ['Masofa', 'Масофа', 'Расстояние'],
  'metersUnit': ['m', 'м', 'м'],
  'checkInSuccess': ['Kelish qayd etildi', 'Келиш қайд этилди', 'Приход зафиксирован'],
  // камера «Келдим»: лицо в овале
  'selfieTitle': ['Selfi', 'Селфи', 'Селфи'],
  'selfieSub': [
    'Yuzingiz ramka ichida va yaxshi yoritilgan bo\'lsin.',
    'Юзингиз рамка ичида ва яхши ёритилган бўлсин.',
    'Лицо в рамке и хорошо освещено.',
  ],
  'takeSelfie': ['Suratga olish', 'Суратга олиш', 'Сделать снимок'],
  'cameraUnavailable': [
    'Kamera ochilmadi. Ilovaga kamera ruxsatini bering.',
    'Камера очилмади. Иловага камера рухсатини беринг.',
    'Камера не открылась. Разрешите приложению доступ к камере.',
  ],
  'faceStarting': ['Kamera ochilmoqda…', 'Камера очилмоқда…', 'Открываем камеру…'],
  'faceNotFound': ['Yuzingizni ramkaga oling', 'Юзингизни рамкага олинг', 'Поместите лицо в рамку'],
  'faceOnlyOne': ['Kadrda faqat siz bo\'ling', 'Кадрда фақат сиз бўлинг', 'В кадре должны быть только вы'],
  'faceCloser': ['Yaqinroq keling', 'Яқинроқ келинг', 'Поднесите телефон ближе'],
  'faceFarther': ['Biroz uzoqroq tuting', 'Бироз узоқроқ тутинг', 'Отодвиньте телефон'],
  'faceCenter': ['Yuzni ramka markaziga oling', 'Юзни рамка марказига олинг', 'Держите лицо по центру'],
  'faceStraight': ['To\'g\'ri qarang', 'Тўғри қаранг', 'Смотрите прямо'],
  'faceEyes': ['Ko\'zlaringizni oching', 'Кўзларингизни очинг', 'Откройте глаза'],
  'faceHold': ['Qimirlamang…', 'Қимирламанг…', 'Не двигайтесь…'],
  'nearOffice': ['Obyekt yonidasiz', 'Объект ёнидасиз', 'Вы у объекта'],
  'farFromOffice': ['Obyektdan {m} m uzoqda', 'Объектдан {m} м узоқда', 'До объекта {m} м'],

  // причины отказа «Келдим» по коду сервера
  'err_outside': ['Siz ish joyingizdan uzoqdasiz', 'Сиз иш жойингиздан узоқдасиз', 'Вы далеко от рабочего места'],
  'err_no_office': [
    'Ish joyingiz belgilanmagan, kadrga murojaat qiling',
    'Иш жойингиз белгиланмаган, кадрга мурожаат қилинг',
    'Место работы не указано, обратитесь в отдел кадров',
  ],
  'err_no_face_photo': [
    'Fotongiz kiritilmagan, kadrga murojaat qiling',
    'Фотонгиз киритилмаган, кадрга мурожаат қилинг',
    'Ваше фото не загружено, обратитесь в отдел кадров',
  ],
  'err_face_photo_bad': [
    'Anketadagi fotoda yuz aniqlanmadi, kadrga murojaat qiling',
    'Анкетадаги фотода юз аниқланмади, кадрга мурожаат қилинг',
    'На фото в анкете не найдено лицо, обратитесь в отдел кадров',
  ],
  'err_no_face': [
    'Yuzingiz aniqlanmadi. Yuzni ramka ichiga olib, qayta urinib ko\'ring',
    'Юзингиз аниқланмади. Юзни рамка ичига олиб, қайта уриниб кўринг',
    'Лицо не найдено. Поместите лицо в рамку и попробуйте снова',
  ],
  'err_many_faces': [
    'Kadrda bir nechta yuz bor. Yolg\'iz turib, qayta urinib ko\'ring',
    'Кадрда бир нечта юз бор. Ёлғиз туриб, қайта уриниб кўринг',
    'В кадре несколько лиц. Встаньте один и попробуйте снова',
  ],
  'err_face_mismatch': ['Yuz mos kelmadi: bu siz emassiz', 'Юз мос келмади: бу сиз эмассиз', 'Лицо не совпало: это не вы'],
  'err_face_unavailable': [
    'Yuzni tekshirish vaqtincha ishlamayapti, birozdan so\'ng urinib ko\'ring',
    'Юзни текшириш вақтинча ишламаяпти, бироздан сўнг уриниб кўринг',
    'Проверка лица временно недоступна, попробуйте позже',
  ],
  'err_update_required': [
    'Ilovani yangilang: eski versiya bilan keldim belgilanmaydi',
    'Иловани янгиланг: эски версия билан келдим белгиланмайди',
    'Обновите приложение: старая версия не отмечает приход',
  ],

  'notCheckedInToday': ['Bugun kelmagan', 'Бугун келмаган', 'Сегодня не пришёл'],
  'monthSummary': ['Oylik xulosa', 'Ойлик хулоса', 'Сводка за месяц'],
  'summaryPresent': ['Kelgan kunlar', 'Келган кунлар', 'Пришёл'],
  'summaryLate': ['Kechikkan', 'Кечиккан', 'Опоздал'],
  'summaryAbsent': ['Kelmagan (sababsiz)', 'Келмаган (сабабсиз)', 'Не пришёл (без уваж.)'],
  'statusOff': ['Dam olish', 'Дам олиш', 'Выходной'],
  'statusPresent': ['Keldi', 'Келди', 'Пришёл'],
  'statusLate': ['Kechikdi', 'Кечикди', 'Опоздал'],
  'statusAbsent': ['Kelmadi', 'Келмади', 'Не пришёл'],
  'noAttendanceHistory': ['Davomat tarixi yo\'q', 'Давомат тарихи йўқ', 'Истории посещаемости нет'],
  'historyCheckIn': ['Keldi', 'Келди', 'Приход'],
  'historyCheckOut': ['Ketdi', 'Кетди', 'Уход'],

  // причины отсутствия
  'reason_leave_annual': ['Mehnat ta\'tili', 'Меҳнат таътили', 'Трудовой отпуск'],
  'reason_leave_unpaid': ['O\'z hisobidan ta\'til', 'Ўз ҳисобидан таътил', 'Отпуск без сохранения з/п'],
  'reason_leave_study': ['O\'quv ta\'tili', 'Ўқув таътили', 'Учебный отпуск'],
  'reason_leave_maternity': ['Tug\'ruq ta\'tili', 'Туғруқ таътили', 'Декретный отпуск'],
  'reason_leave_childcare': ['Bola parvarishi ta\'tili', 'Бола парвариши таътили', 'Отпуск по уходу за ребёнком'],
  'reason_sick': ['Mehnatga layoqatsizlik varaqasi', 'Меҳнатга лаёқатсизлик варақаси', 'Больничный лист'],
  'reason_military': ['Harbiy xizmat (yig\'in)', 'Ҳарбий хизмат (йиғин)', 'Военная служба (сборы)'],
  'reason_business_trip': ['Xizmat safari', 'Хизмат сафари', 'Командировка'],
  'reason_duty': ['Xizmat topshirig\'i', 'Хизмат топшириғи', 'Служебное задание'],
  'reason_doctor': ['Shifokor qabulida', 'Шифокор қабулида', 'У врача'],
  'reason_event': ['Tadbirda qatnashgan', 'Тадбирда қатнашган', 'Участие в мероприятии'],
  'reason_family': ['Oilaviy sabab', 'Оилавий сабаб', 'Семейные обстоятельства'],
  'reason_other': ['Boshqa', 'Бошқа', 'Другое'],
};

/// Текст отказа «Келдим» на языке приложения по коду сервера; null — код незнакомый.
/// Для «outside» расстояние дописывает вызывающий.
String? checkInErrorText(String code) {
  final key = 'err_$code';

  return _strings.containsKey(key) && code != 'outside' ? t(key) : null;
}

String attendanceReasonText(String code) {
  final key = 'reason_$code';
  if (_strings.containsKey(key)) {
    return t(key);
  }
  return code;
}

String formatDurationMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) {
    return '$h ${t('hoursShort')} $m ${t('minutesShort')}';
  }
  if (h > 0) {
    return '$h ${t('hoursShort')}';
  }
  return '$m ${t('minutesShort')}';
}

const Map<int, List<String>> _monthNames = {
  1: ['Yanvar', 'Январь', 'Январь'],
  2: ['Fevral', 'Февраль', 'Февраль'],
  3: ['Mart', 'Март', 'Март'],
  4: ['Aprel', 'Апрель', 'Апрель'],
  5: ['May', 'Май', 'Май'],
  6: ['Iyun', 'Июнь', 'Июнь'],
  7: ['Iyul', 'Июль', 'Июль'],
  8: ['Avgust', 'Август', 'Август'],
  9: ['Sentabr', 'Сентябрь', 'Сентябрь'],
  10: ['Oktabr', 'Октябрь', 'Октябрь'],
  11: ['Noyabr', 'Ноябрь', 'Ноябрь'],
  12: ['Dekabr', 'Декабрь', 'Декабрь'],
};

String monthName(int month) {
  final row = _monthNames[month];
  if (row == null) return '$month';
  const index = {'uz': 0, 'uzc': 1, 'ru': 2};
  return row[index[AppSettings.instance.lang] ?? 1];
}

const Map<int, List<String>> _weekdayNames = {
  1: ['Dushanba', 'Душанба', 'Понедельник'],
  2: ['Seshanba', 'Сешанба', 'Вторник'],
  3: ['Chorshanba', 'Чоршанба', 'Среда'],
  4: ['Payshanba', 'Пайшанба', 'Четверг'],
  5: ['Juma', 'Жума', 'Пятница'],
  6: ['Shanba', 'Шанба', 'Суббота'],
  7: ['Yakshanba', 'Якшанба', 'Воскресенье'],
};

String weekdayName(int weekday) {
  final row = _weekdayNames[weekday];
  if (row == null) return '$weekday';
  const index = {'uz': 0, 'uzc': 1, 'ru': 2};
  return row[index[AppSettings.instance.lang] ?? 1];
}

String t(String key) {
  final row = _strings[key];
  if (row == null) return key;
  const index = {'uz': 0, 'uzc': 1, 'ru': 2};
  return row[index[AppSettings.instance.lang] ?? 1];
}

/// Текст ошибки для пользователя: сеть — переводится, сервер — как прислал.
String errorText(Object e) {
  if (e is ApiException) {
    if (e.message == 'network') return t('networkError');
    return e.message;
  }
  return e.toString();
}

const kLanguages = {
  'uz': 'O\'zbekcha (lotin)',
  'uzc': 'Ўзбекча (кирилл)',
  'ru': 'Русский',
};
