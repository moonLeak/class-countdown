import Foundation
import Combine

/// 运行时本地化。
///
/// 不用 .lproj + NSLocalizedString：那套要等重启才换，
/// 而语言是设置里的一个选项，改完当场就该变。
/// 这里把文案放进内存表，语言一改就发通知，所有观察它的视图立刻重画。
@MainActor
final class L10n: ObservableObject {

    static let shared = L10n()

    @Published private(set) var code: String

    private init() { code = Self.systemCode() }

    func apply(_ language: AppLanguage) {
        code = language.localeCode ?? Self.systemCode()
    }

    /// 系统语言落到我们支持的那几档上，落不到就用英文
    private static func systemCode() -> String {
        let pref = Locale.preferredLanguages.first ?? "en"
        if pref.hasPrefix("zh") {
            let lower = pref.lowercased()
            if lower.contains("hant") || lower.contains("tw")
                || lower.contains("hk") || lower.contains("mo") { return "zh-Hant" }
            return "zh-Hans"
        }
        for c in ["en", "ja", "ko", "de", "fr", "es", "pt", "ru"] where pref.hasPrefix(c) {
            return c
        }
        return "en"
    }

    /// 取不到就退回英文，再取不到退回简体中文，最后退回 key 本身
    func string(_ key: String) -> String {
        guard let row = l10nTable[key] else { return key }
        return row[code] ?? row["en"] ?? row["zh-Hans"] ?? key
    }
}

/// 短名，正文里调用起来不打断阅读
@MainActor
func L(_ key: String) -> String { L10n.shared.string(key) }

@MainActor
func L(_ key: String, _ n: Int) -> String {
    String(format: L10n.shared.string(key), n)
}

// MARK: - 文案表
// 每一行是一个词条，键名按“位置.含义”。日程名称永远不进这张表，那是日历的原文。

private let l10nTable: [String: [String: String]] = [

        "menu.settings": [
            "zh-Hans": "设置…", "zh-Hant": "設定…", "en": "Settings…", "ja": "設定…",
            "ko": "설정…", "de": "Einstellungen…", "fr": "Réglages…",
            "es": "Ajustes…", "pt": "Ajustes…", "ru": "Настройки…"],

        "menu.about": [
            "zh-Hans": "关于 ClassCountdown", "zh-Hant": "關於 ClassCountdown",
            "en": "About ClassCountdown", "ja": "ClassCountdown について",
            "ko": "ClassCountdown 정보", "de": "Über ClassCountdown",
            "fr": "À propos de ClassCountdown", "es": "Acerca de ClassCountdown",
            "pt": "Sobre o ClassCountdown", "ru": "О ClassCountdown"],

        "menu.openCalendar": [
            "zh-Hans": "打开日历", "zh-Hant": "打開日曆", "en": "Open Calendar",
            "ja": "カレンダーを開く", "ko": "캘린더 열기", "de": "Kalender öffnen",
            "fr": "Ouvrir Calendrier", "es": "Abrir Calendario",
            "pt": "Abrir Calendário", "ru": "Открыть Календарь"],

        "menu.quit": [
            "zh-Hans": "退出", "zh-Hant": "結束", "en": "Quit", "ja": "終了",
            "ko": "종료", "de": "Beenden", "fr": "Quitter",
            "es": "Salir", "pt": "Sair", "ru": "Выйти"],

        "panel.emptyHead": [
            "zh-Hans": "接下来没有日程", "zh-Hant": "接下來沒有行程",
            "en": "No upcoming events", "ja": "予定はありません",
            "ko": "다가오는 일정 없음", "de": "Keine anstehenden Termine",
            "fr": "Aucun événement à venir", "es": "No hay eventos próximos",
            "pt": "Nenhum evento a seguir", "ru": "Нет ближайших событий"],

        "panel.emptyBody": [
            "zh-Hans": "未来 48 小时内，勾选的日历里没有事件。",
            "zh-Hant": "未來 48 小時內，勾選的日曆裡沒有事件。",
            "en": "No events in the selected calendars over the next 48 hours.",
            "ja": "選択したカレンダーに今後 48 時間の予定はありません。",
            "ko": "선택한 캘린더에 앞으로 48시간 동안 일정이 없습니다.",
            "de": "In den ausgewählten Kalendern gibt es in den nächsten 48 Stunden keine Termine.",
            "fr": "Aucun événement dans les calendriers sélectionnés au cours des 48 prochaines heures.",
            "es": "No hay eventos en los calendarios seleccionados en las próximas 48 horas.",
            "pt": "Não há eventos nos calendários selecionados nas próximas 48 horas.",
            "ru": "В выбранных календарях нет событий в ближайшие 48 часов."],

        "panel.accessHead": [
            "zh-Hans": "需要日历访问权限", "zh-Hant": "需要日曆存取權限",
            "en": "Calendar access required", "ja": "カレンダーへのアクセスが必要です",
            "ko": "캘린더 접근 권한 필요", "de": "Kalenderzugriff erforderlich",
            "fr": "Accès au calendrier requis", "es": "Se requiere acceso al calendario",
            "pt": "É necessário acesso ao calendário", "ru": "Требуется доступ к календарю"],

        "panel.accessBody": [
            "zh-Hans": "只读取日程的标题和起止时间，不会修改任何日程，也不联网。",
            "zh-Hant": "只讀取行程的標題和起訖時間，不會修改任何行程，也不連網。",
            "en": "Only event titles and times are read. Nothing is modified and nothing leaves your Mac.",
            "ja": "予定のタイトルと時刻のみを読み取ります。変更も送信も行いません。",
            "ko": "일정의 제목과 시간만 읽습니다. 변경하거나 외부로 전송하지 않습니다.",
            "de": "Es werden nur Titel und Zeiten gelesen. Nichts wird geändert oder gesendet.",
            "fr": "Seuls les titres et horaires sont lus. Rien n'est modifié ni envoyé.",
            "es": "Solo se leen los títulos y horarios. No se modifica ni se envía nada.",
            "pt": "Apenas títulos e horários são lidos. Nada é alterado ou enviado.",
            "ru": "Читаются только названия и время событий. Ничего не изменяется и не отправляется."],

        "panel.requestAccess": [
            "zh-Hans": "请求权限", "zh-Hant": "請求權限", "en": "Grant Access",
            "ja": "アクセスを許可", "ko": "권한 요청", "de": "Zugriff erlauben",
            "fr": "Autoriser l'accès", "es": "Conceder acceso",
            "pt": "Conceder acesso", "ru": "Разрешить доступ"],

        "panel.systemSettings": [
            "zh-Hans": "系统设置", "zh-Hant": "系統設定", "en": "System Settings",
            "ja": "システム設定", "ko": "시스템 설정", "de": "Systemeinstellungen",
            "fr": "Réglages Système", "es": "Ajustes del Sistema",
            "pt": "Ajustes do Sistema", "ru": "Системные настройки"],

        "panel.toStart": [
            "zh-Hans": "距开始", "zh-Hant": "距開始", "en": "Starts in",
            "ja": "開始まで", "ko": "시작까지", "de": "Beginnt in",
            "fr": "Commence dans", "es": "Comienza en",
            "pt": "Começa em", "ru": "До начала"],

        "settings.title": [
            "zh-Hans": "ClassCountdown 设置", "zh-Hant": "ClassCountdown 設定",
            "en": "ClassCountdown Settings", "ja": "ClassCountdown 設定",
            "ko": "ClassCountdown 설정", "de": "ClassCountdown-Einstellungen",
            "fr": "Réglages ClassCountdown", "es": "Ajustes de ClassCountdown",
            "pt": "Ajustes do ClassCountdown", "ru": "Настройки ClassCountdown"],

        "tab.general": [
            "zh-Hans": "通用", "zh-Hant": "一般", "en": "General", "ja": "一般",
            "ko": "일반", "de": "Allgemein", "fr": "Général",
            "es": "General", "pt": "Geral", "ru": "Основные"],

        "tab.calendars": [
            "zh-Hans": "日历", "zh-Hant": "日曆", "en": "Calendars", "ja": "カレンダー",
            "ko": "캘린더", "de": "Kalender", "fr": "Calendriers",
            "es": "Calendarios", "pt": "Calendários", "ru": "Календари"],

        "sec.menubar": [
            "zh-Hans": "菜单栏", "zh-Hant": "選單列", "en": "Menu Bar", "ja": "メニューバー",
            "ko": "메뉴 막대", "de": "Menüleiste", "fr": "Barre des menus",
            "es": "Barra de menús", "pt": "Barra de menus", "ru": "Строка меню"],

        "sec.countdown": [
            "zh-Hans": "倒计时", "zh-Hant": "倒數計時", "en": "Countdown",
            "ja": "カウントダウン", "ko": "카운트다운", "de": "Countdown",
            "fr": "Compte à rebours", "es": "Cuenta atrás",
            "pt": "Contagem regressiva", "ru": "Обратный отсчёт"],

        "row.language": [
            "zh-Hans": "界面语言", "zh-Hant": "介面語言", "en": "Language", "ja": "言語",
            "ko": "언어", "de": "Sprache", "fr": "Langue",
            "es": "Idioma", "pt": "Idioma", "ru": "Язык"],

        "row.launchAtLogin": [
            "zh-Hans": "登录时打开", "zh-Hant": "登入時開啟", "en": "Open at Login",
            "ja": "ログイン時に開く", "ko": "로그인 시 열기", "de": "Beim Anmelden öffnen",
            "fr": "Ouvrir à la connexion", "es": "Abrir al iniciar sesión",
            "pt": "Abrir ao iniciar sessão", "ru": "Открывать при входе"],

        "row.menubarContent": [
            "zh-Hans": "显示内容", "zh-Hant": "顯示內容", "en": "Show", "ja": "表示内容",
            "ko": "표시 내용", "de": "Anzeige", "fr": "Afficher",
            "es": "Mostrar", "pt": "Mostrar", "ru": "Показывать"],

        "row.separator": [
            "zh-Hans": "分隔符", "zh-Hant": "分隔符號", "en": "Separator",
            "ja": "区切り文字", "ko": "구분 기호", "de": "Trennzeichen",
            "fr": "Séparateur", "es": "Separador",
            "pt": "Separador", "ru": "Разделитель"],

        "sep.space": [
            "zh-Hans": "空格", "zh-Hant": "空格", "en": "Space", "ja": "スペース",
            "ko": "공백", "de": "Leerzeichen", "fr": "Espace",
            "es": "Espacio", "pt": "Espaço", "ru": "Пробел"],

        "sep.custom": [
            "zh-Hans": "自定义…", "zh-Hant": "自訂…", "en": "Custom…",
            "ja": "カスタム…", "ko": "사용자 지정…", "de": "Eigenes…",
            "fr": "Personnalisé…", "es": "Personalizado…",
            "pt": "Personalizado…", "ru": "Свой…"],

        "sep.customField": [
            "zh-Hans": "自定义分隔符", "zh-Hant": "自訂分隔符號", "en": "Custom separator",
            "ja": "カスタム区切り文字", "ko": "사용자 지정 구분 기호",
            "de": "Eigenes Trennzeichen", "fr": "Séparateur personnalisé",
            "es": "Separador personalizado", "pt": "Separador personalizado",
            "ru": "Свой разделитель"],

        "sep.preview": [
            "zh-Hans": "预览", "zh-Hant": "預覽", "en": "Preview", "ja": "プレビュー",
            "ko": "미리 보기", "de": "Vorschau", "fr": "Aperçu",
            "es": "Vista previa", "pt": "Pré-visualização", "ru": "Предпросмотр"],

        "row.includeAllDay": [
            "zh-Hans": "包含全天事件", "zh-Hant": "包含全天事件",
            "en": "Include all-day events", "ja": "終日の予定を含める",
            "ko": "종일 일정 포함", "de": "Ganztägige Termine einbeziehen",
            "fr": "Inclure les événements sur la journée",
            "es": "Incluir eventos de todo el día",
            "pt": "Incluir eventos de dia inteiro",
            "ru": "Учитывать события на весь день"],

        "row.warn": [
            "zh-Hans": "临近结束警示", "zh-Hant": "臨近結束警示", "en": "Ending soon alert",
            "ja": "終了間近の警告", "ko": "종료 임박 알림", "de": "Warnung vor Ende",
            "fr": "Alerte de fin proche", "es": "Aviso de final próximo",
            "pt": "Aviso de término próximo", "ru": "Предупреждение об окончании"],

        "warn.off": [
            "zh-Hans": "关闭", "zh-Hant": "關閉", "en": "Off", "ja": "オフ",
            "ko": "끔", "de": "Aus", "fr": "Désactivé",
            "es": "Desactivado", "pt": "Desativado", "ru": "Выкл."],

        "warn.minutes": [
            "zh-Hans": "剩余 %d 分钟", "zh-Hant": "剩餘 %d 分鐘", "en": "%d minutes left",
            "ja": "残り %d 分", "ko": "%d분 남음", "de": "%d Minuten übrig",
            "fr": "%d minutes restantes", "es": "%d minutos restantes",
            "pt": "%d minutos restantes", "ru": "Осталось %d мин."],

        "row.quitApp": [
            "zh-Hans": "退出 ClassCountdown", "zh-Hant": "結束 ClassCountdown",
            "en": "Quit ClassCountdown", "ja": "ClassCountdown を終了",
            "ko": "ClassCountdown 종료", "de": "ClassCountdown beenden",
            "fr": "Quitter ClassCountdown", "es": "Salir de ClassCountdown",
            "pt": "Sair do ClassCountdown", "ru": "Выйти из ClassCountdown"],

        "calendars.hint": [
            "zh-Hans": "只有勾选的日历参与倒计时。进度条会用日历自己的颜色。",
            "zh-Hant": "只有勾選的日曆參與倒數。進度條會用日曆自己的顏色。",
            "en": "Only checked calendars are counted. The progress bar uses each calendar's own color.",
            "ja": "チェックしたカレンダーのみが対象です。進捗バーはカレンダーの色を使います。",
            "ko": "선택한 캘린더만 사용됩니다. 진행 막대는 캘린더 색상을 따릅니다.",
            "de": "Nur ausgewählte Kalender werden berücksichtigt. Der Fortschrittsbalken nutzt die Farbe des Kalenders.",
            "fr": "Seuls les calendriers cochés sont pris en compte. La barre de progression utilise la couleur du calendrier.",
            "es": "Solo se usan los calendarios marcados. La barra de progreso usa el color del calendario.",
            "pt": "Apenas os calendários marcados são usados. A barra de progresso usa a cor do calendário.",
            "ru": "Учитываются только отмеченные календари. Индикатор использует цвет календаря."],

        "menubar.nameAndTime": [
            "zh-Hans": "名称与剩余时间", "zh-Hant": "名稱與剩餘時間",
            "en": "Name and time left", "ja": "名称と残り時間",
            "ko": "이름과 남은 시간", "de": "Name und Restzeit",
            "fr": "Nom et temps restant", "es": "Nombre y tiempo restante",
            "pt": "Nome e tempo restante", "ru": "Название и остаток"],

        "menubar.timeOnly": [
            "zh-Hans": "仅剩余时间", "zh-Hant": "僅剩餘時間", "en": "Time left only",
            "ja": "残り時間のみ", "ko": "남은 시간만", "de": "Nur Restzeit",
            "fr": "Temps restant seulement", "es": "Solo tiempo restante",
            "pt": "Apenas tempo restante", "ru": "Только остаток"],

        "lang.system": [
            "zh-Hans": "跟随系统", "zh-Hant": "跟隨系統", "en": "System",
            "ja": "システムに従う", "ko": "시스템 설정 사용", "de": "Systemsprache",
            "fr": "Langue du système", "es": "Idioma del sistema",
            "pt": "Idioma do sistema", "ru": "Как в системе"],

        "a11y.needsAccess": [
            "zh-Hans": "需要日历权限", "zh-Hant": "需要日曆權限",
            "en": "Calendar permission needed", "ja": "カレンダーの権限が必要",
            "ko": "캘린더 권한 필요", "de": "Kalenderberechtigung erforderlich",
            "fr": "Autorisation calendrier requise", "es": "Se necesita permiso de calendario",
            "pt": "Permissão de calendário necessária", "ru": "Нужен доступ к календарю"],

        "a11y.noEvents": [
            "zh-Hans": "没有日程", "zh-Hant": "沒有行程", "en": "No events",
            "ja": "予定なし", "ko": "일정 없음", "de": "Keine Termine",
            "fr": "Aucun événement", "es": "Sin eventos",
            "pt": "Sem eventos", "ru": "Нет событий"]
]
