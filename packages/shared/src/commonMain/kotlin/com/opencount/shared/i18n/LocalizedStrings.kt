package com.opencount.shared.i18n

expect fun currentLanguageCode(): String

object Strings {
    var language: String = "en"

    // App
    val appName: String get() = get("app.name", "OpenCount")
    val version: String get() = get("app.version", "Version")

    // Counting
    val addMarker: String get() = get("counting.add_marker", "Add Marker")
    val removeMarker: String get() = get("counting.remove_marker", "Remove Marker")
    val totalCount: String get() = get("counting.total", "Total")
    val aiDetect: String get() = get("counting.ai_detect", "AI Detect")
    val voiceCount: String get() = get("counting.voice", "Voice Count")
    val liveCount: String get() = get("counting.live", "Live Count")
    val arCount: String get() = get("counting.ar", "AR Count")
    val tallyMode: String get() = get("counting.tally_mode", "Tally Mode")
    val undo: String get() = get("counting.undo", "Undo")
    val redo: String get() = get("counting.redo", "Redo")
    val clearAll: String get() = get("counting.clear_all", "Clear All")

    // Sessions
    val newSession: String get() = get("session.new", "New Session")
    val sessions: String get() = get("session.list", "Sessions")
    val deleteSession: String get() = get("session.delete", "Delete Session")
    val duplicateSession: String get() = get("session.duplicate", "Duplicate")
    val renameSession: String get() = get("session.rename", "Rename")
    val searchSessions: String get() = get("session.search", "Search sessions...")

    // Export
    val export: String get() = get("export.title", "Export")
    val exportCSV: String get() = get("export.csv", "CSV")
    val exportXLSX: String get() = get("export.xlsx", "XLSX")
    val exportJSON: String get() = get("export.json", "JSON")
    val exportCOCO: String get() = get("export.coco", "COCO JSON")
    val exportPDF: String get() = get("export.pdf", "PDF")
    val exportAnnotated: String get() = get("export.annotated", "Annotated Image")
    val bulkExport: String get() = get("export.bulk", "Bulk Export")

    // Settings
    val settings: String get() = get("settings.title", "Settings")
    val languageLabel: String get() = get("settings.language", "Language")
    val icloudSync: String get() = get("settings.icloud_sync", "iCloud Sync")
    val about: String get() = get("settings.about", "About")
    val feedback: String get() = get("settings.feedback", "Feedback")

    // Object Types
    val addCategory: String get() = get("object_type.add", "Add Category")
    val categoryName: String get() = get("object_type.name", "Category Name")
    val targetCount_hint: String get() = get("object_type.target", "Target Count")

    // Regions
    val addRegion: String get() = get("region.add", "Add Region")
    val regionName: String get() = get("region.name", "Region Name")

    // AI
    val aiProcessing: String get() = get("ai.processing", "AI Processing...")
    val aiConfidence: String get() = get("ai.confidence", "Confidence Threshold")
    val noModelFound: String get() = get("ai.no_model", "No AI Model Found")
    val customModel: String get() = get("ai.custom_model", "Custom Model")

    // Errors
    val errorGeneric: String get() = get("error.generic", "An error occurred")
    val errorSave: String get() = get("error.save", "Failed to save session")
    val errorLoad: String get() = get("error.load", "Failed to load session")
    val errorExport: String get() = get("error.export", "Failed to export")
    val errorNetwork: String get() = get("error.network", "Network error")

    private fun get(key: String, fallback: String): String =
        bundles[language]?.get(key) ?: bundles["en"]?.get(key) ?: fallback
}

// Bundles must be declared before bundles map
private val englishBundle: Map<String, String> = mapOf(
    "app.name" to "OpenCount",
    "app.version" to "Version",
    "counting.add_marker" to "Add Marker",
    "counting.remove_marker" to "Remove Marker",
    "counting.total" to "Total",
    "counting.ai_detect" to "AI Detect",
    "counting.voice" to "Voice Count",
    "counting.live" to "Live Count",
    "counting.ar" to "AR Count",
    "counting.tally_mode" to "Tally Mode",
    "counting.undo" to "Undo",
    "counting.redo" to "Redo",
    "counting.clear_all" to "Clear All",
    "session.new" to "New Session",
    "session.list" to "Sessions",
    "session.delete" to "Delete Session",
    "session.duplicate" to "Duplicate",
    "session.rename" to "Rename",
    "session.search" to "Search sessions...",
    "export.title" to "Export",
    "export.csv" to "CSV",
    "export.xlsx" to "XLSX",
    "export.json" to "JSON",
    "export.coco" to "COCO JSON",
    "export.pdf" to "PDF",
    "export.annotated" to "Annotated Image",
    "export.bulk" to "Bulk Export",
    "settings.title" to "Settings",
    "settings.language" to "Language",
    "settings.icloud_sync" to "iCloud Sync",
    "settings.about" to "About",
    "settings.feedback" to "Feedback",
    "object_type.add" to "Add Category",
    "object_type.name" to "Category Name",
    "object_type.target" to "Target Count",
    "region.add" to "Add Region",
    "region.name" to "Region Name",
    "ai.processing" to "AI Processing...",
    "ai.confidence" to "Confidence Threshold",
    "ai.no_model" to "No AI Model Found",
    "ai.custom_model" to "Custom Model",
    "error.generic" to "An error occurred",
    "error.save" to "Failed to save session",
    "error.load" to "Failed to load session",
    "error.export" to "Failed to export",
    "error.network" to "Network error",
)

private val vietnameseBundle = mapOf(
    "app.name" to "OpenCount",
    "app.version" to "Phiên bản",
    "counting.add_marker" to "Thêm điểm",
    "counting.remove_marker" to "Xóa điểm",
    "counting.total" to "Tổng cộng",
    "counting.ai_detect" to "AI Phát hiện",
    "counting.voice" to "Đếm bằng giọng nói",
    "counting.live" to "Đếm trực tiếp",
    "counting.ar" to "Đếm AR",
    "counting.tally_mode" to "Chế độ đếm nhanh",
    "counting.undo" to "Hoàn tác",
    "counting.redo" to "Làm lại",
    "counting.clear_all" to "Xóa tất cả",
    "session.new" to "Phiên mới",
    "session.list" to "Danh sách phiên",
    "session.delete" to "Xóa phiên",
    "session.duplicate" to "Nhân bản",
    "session.rename" to "Đổi tên",
    "session.search" to "Tìm kiếm phiên...",
    "export.title" to "Xuất dữ liệu",
    "export.csv" to "CSV",
    "export.xlsx" to "XLSX",
    "export.json" to "JSON",
    "export.coco" to "COCO JSON",
    "export.pdf" to "PDF",
    "export.annotated" to "Ảnh có chú thích",
    "export.bulk" to "Xuất hàng loạt",
    "settings.title" to "Cài đặt",
    "settings.language" to "Ngôn ngữ",
    "settings.icloud_sync" to "Đồng bộ iCloud",
    "settings.about" to "Giới thiệu",
    "settings.feedback" to "Phản hồi",
    "object_type.add" to "Thêm danh mục",
    "object_type.name" to "Tên danh mục",
    "object_type.target" to "Số lượng mục tiêu",
    "region.add" to "Thêm vùng",
    "region.name" to "Tên vùng",
    "ai.processing" to "AI đang xử lý...",
    "ai.confidence" to "Ngưỡng tin cậy",
    "ai.no_model" to "Không tìm thấy mô hình AI",
    "ai.custom_model" to "Mô hình tùy chỉnh",
    "error.generic" to "Đã xảy ra lỗi",
    "error.save" to "Không thể lưu phiên",
    "error.load" to "Không thể tải phiên",
    "error.export" to "Không thể xuất dữ liệu",
    "error.network" to "Lỗi mạng",
)

private val japaneseBundle = mapOf(
    "app.name" to "OpenCount",
    "app.version" to "バージョン",
    "counting.add_marker" to "マーカー追加",
    "counting.remove_marker" to "マーカー削除",
    "counting.total" to "合計",
    "counting.ai_detect" to "AI検出",
    "counting.voice" to "音声カウント",
    "counting.live" to "ライブカウント",
    "counting.ar" to "ARカウント",
    "counting.tally_mode" to "タリーモード",
    "counting.undo" to "元に戻す",
    "counting.redo" to "やり直す",
    "counting.clear_all" to "すべてクリア",
    "session.new" to "新規セッション",
    "session.list" to "セッション一覧",
    "session.delete" to "セッション削除",
    "session.duplicate" to "複製",
    "session.rename" to "名前変更",
    "session.search" to "セッションを検索...",
    "export.title" to "エクスポート",
    "export.csv" to "CSV",
    "export.xlsx" to "XLSX",
    "export.json" to "JSON",
    "export.coco" to "COCO JSON",
    "export.pdf" to "PDF",
    "export.annotated" to "注釈付き画像",
    "export.bulk" to "一括エクスポート",
    "settings.title" to "設定",
    "settings.language" to "言語",
    "settings.icloud_sync" to "iCloud同期",
    "settings.about" to "情報",
    "settings.feedback" to "フィードバック",
    "object_type.add" to "カテゴリ追加",
    "object_type.name" to "カテゴリ名",
    "object_type.target" to "目標数",
    "region.add" to "領域追加",
    "region.name" to "領域名",
    "ai.processing" to "AI処理中...",
    "ai.confidence" to "信頼度しきい値",
    "ai.no_model" to "AIモデルが見つかりません",
    "ai.custom_model" to "カスタムモデル",
    "error.generic" to "エラーが発生しました",
    "error.save" to "セッションの保存に失敗しました",
    "error.load" to "セッションの読み込みに失敗しました",
    "error.export" to "エクスポートに失敗しました",
    "error.network" to "ネットワークエラー",
)

private val koreanBundle = mapOf(
    "app.name" to "OpenCount",
    "app.version" to "버전",
    "counting.add_marker" to "마커 추가",
    "counting.remove_marker" to "마커 제거",
    "counting.total" to "합계",
    "counting.ai_detect" to "AI 감지",
    "counting.voice" to "음성 카운트",
    "counting.live" to "실시간 카운트",
    "counting.ar" to "AR 카운트",
    "counting.tally_mode" to "빠른 카운트 모드",
    "counting.undo" to "실행 취소",
    "counting.redo" to "다시 실행",
    "counting.clear_all" to "모두 지우기",
    "session.new" to "새 세션",
    "session.list" to "세션 목록",
    "session.delete" to "세션 삭제",
    "session.duplicate" to "복제",
    "session.rename" to "이름 변경",
    "session.search" to "세션 검색...",
    "export.title" to "내보내기",
    "export.csv" to "CSV",
    "export.xlsx" to "XLSX",
    "export.json" to "JSON",
    "export.coco" to "COCO JSON",
    "export.pdf" to "PDF",
    "export.annotated" to "주석 이미지",
    "export.bulk" to "대량 내보내기",
    "settings.title" to "설정",
    "settings.language" to "언어",
    "settings.icloud_sync" to "iCloud 동기화",
    "settings.about" to "정보",
    "settings.feedback" to "피드백",
    "object_type.add" to "카테고리 추가",
    "object_type.name" to "카테고리 이름",
    "object_type.target" to "목표 개수",
    "region.add" to "영역 추가",
    "region.name" to "영역 이름",
    "ai.processing" to "AI 처리 중...",
    "ai.confidence" to "신뢰도 임계값",
    "ai.no_model" to "AI 모델을 찾을 수 없음",
    "ai.custom_model" to "사용자 정의 모델",
    "error.generic" to "오류가 발생했습니다",
    "error.save" to "세션 저장 실패",
    "error.load" to "세션 로드 실패",
    "error.export" to "내보내기 실패",
    "error.network" to "네트워크 오류",
)

private val chineseBundle = mapOf(
    "app.name" to "OpenCount",
    "app.version" to "版本",
    "counting.add_marker" to "添加标记",
    "counting.remove_marker" to "移除标记",
    "counting.total" to "总计",
    "counting.ai_detect" to "AI检测",
    "counting.voice" to "语音计数",
    "counting.live" to "实时计数",
    "counting.ar" to "AR计数",
    "counting.tally_mode" to "快速计数模式",
    "counting.undo" to "撤销",
    "counting.redo" to "重做",
    "counting.clear_all" to "清除全部",
    "session.new" to "新建会话",
    "session.list" to "会话列表",
    "session.delete" to "删除会话",
    "session.duplicate" to "复制",
    "session.rename" to "重命名",
    "session.search" to "搜索会话...",
    "export.title" to "导出",
    "export.csv" to "CSV",
    "export.xlsx" to "XLSX",
    "export.json" to "JSON",
    "export.coco" to "COCO JSON",
    "export.pdf" to "PDF",
    "export.annotated" to "带标注的图像",
    "export.bulk" to "批量导出",
    "settings.title" to "设置",
    "settings.language" to "语言",
    "settings.icloud_sync" to "iCloud同步",
    "settings.about" to "关于",
    "settings.feedback" to "反馈",
    "object_type.add" to "添加分类",
    "object_type.name" to "分类名称",
    "object_type.target" to "目标数量",
    "region.add" to "添加区域",
    "region.name" to "区域名称",
    "ai.processing" to "AI处理中...",
    "ai.confidence" to "置信度阈值",
    "ai.no_model" to "未找到AI模型",
    "ai.custom_model" to "自定义模型",
    "error.generic" to "发生错误",
    "error.save" to "保存会话失败",
    "error.load" to "加载会话失败",
    "error.export" to "导出失败",
    "error.network" to "网络错误",
)

private val frenchBundle = mapOf(
    "app.name" to "OpenCount",
    "app.version" to "Version",
    "counting.add_marker" to "Ajouter un marqueur",
    "counting.remove_marker" to "Supprimer le marqueur",
    "counting.total" to "Total",
    "counting.ai_detect" to "Détection IA",
    "counting.voice" to "Comptage vocal",
    "counting.live" to "Comptage en direct",
    "counting.ar" to "Comptage RA",
    "counting.tally_mode" to "Mode comptage",
    "counting.undo" to "Annuler",
    "counting.redo" to "Rétablir",
    "counting.clear_all" to "Tout effacer",
    "session.new" to "Nouvelle session",
    "session.list" to "Sessions",
    "session.delete" to "Supprimer la session",
    "session.duplicate" to "Dupliquer",
    "session.rename" to "Renommer",
    "session.search" to "Rechercher des sessions...",
    "export.title" to "Exporter",
    "export.csv" to "CSV",
    "export.xlsx" to "XLSX",
    "export.json" to "JSON",
    "export.coco" to "COCO JSON",
    "export.pdf" to "PDF",
    "export.annotated" to "Image annotée",
    "export.bulk" to "Export groupé",
    "settings.title" to "Paramètres",
    "settings.language" to "Langue",
    "settings.icloud_sync" to "Synchronisation iCloud",
    "settings.about" to "À propos",
    "settings.feedback" to "Commentaires",
    "object_type.add" to "Ajouter une catégorie",
    "object_type.name" to "Nom de la catégorie",
    "object_type.target" to "Nombre cible",
    "region.add" to "Ajouter une région",
    "region.name" to "Nom de la région",
    "ai.processing" to "Traitement IA...",
    "ai.confidence" to "Seuil de confiance",
    "ai.no_model" to "Aucun modèle IA trouvé",
    "ai.custom_model" to "Modèle personnalisé",
    "error.generic" to "Une erreur est survenue",
    "error.save" to "Échec de la sauvegarde",
    "error.load" to "Échec du chargement",
    "error.export" to "Échec de l'export",
    "error.network" to "Erreur réseau",
)

private val germanBundle = mapOf(
    "app.name" to "OpenCount",
    "app.version" to "Version",
    "counting.add_marker" to "Marker hinzufügen",
    "counting.remove_marker" to "Marker entfernen",
    "counting.total" to "Gesamt",
    "counting.ai_detect" to "KI-Erkennung",
    "counting.voice" to "Sprachzählung",
    "counting.live" to "Live-Zählung",
    "counting.ar" to "AR-Zählung",
    "counting.tally_mode" to "Zählmodus",
    "counting.undo" to "Rückgängig",
    "counting.redo" to "Wiederholen",
    "counting.clear_all" to "Alle löschen",
    "session.new" to "Neue Sitzung",
    "session.list" to "Sitzungen",
    "session.delete" to "Sitzung löschen",
    "session.duplicate" to "Duplizieren",
    "session.rename" to "Umbenennen",
    "session.search" to "Sitzungen durchsuchen...",
    "export.title" to "Exportieren",
    "export.csv" to "CSV",
    "export.xlsx" to "XLSX",
    "export.json" to "JSON",
    "export.coco" to "COCO JSON",
    "export.pdf" to "PDF",
    "export.annotated" to "Annotiertes Bild",
    "export.bulk" to "Stapelexport",
    "settings.title" to "Einstellungen",
    "settings.language" to "Sprache",
    "settings.icloud_sync" to "iCloud-Synchronisierung",
    "settings.about" to "Über",
    "settings.feedback" to "Feedback",
    "object_type.add" to "Kategorie hinzufügen",
    "object_type.name" to "Kategoriename",
    "object_type.target" to "Zielanzahl",
    "region.add" to "Bereich hinzufügen",
    "region.name" to "Bereichsname",
    "ai.processing" to "KI-Verarbeitung...",
    "ai.confidence" to "Konfidenzschwelle",
    "ai.no_model" to "Kein KI-Modell gefunden",
    "ai.custom_model" to "Benutzerdefiniertes Modell",
    "error.generic" to "Ein Fehler ist aufgetreten",
    "error.save" to "Speichern fehlgeschlagen",
    "error.load" to "Laden fehlgeschlagen",
    "error.export" to "Export fehlgeschlagen",
    "error.network" to "Netzwerkfehler",
)

private val spanishBundle = mapOf(
    "app.name" to "OpenCount",
    "app.version" to "Versión",
    "counting.add_marker" to "Agregar marcador",
    "counting.remove_marker" to "Eliminar marcador",
    "counting.total" to "Total",
    "counting.ai_detect" to "Detección IA",
    "counting.voice" to "Conteo por voz",
    "counting.live" to "Conteo en vivo",
    "counting.ar" to "Conteo RA",
    "counting.tally_mode" to "Modo de conteo",
    "counting.undo" to "Deshacer",
    "counting.redo" to "Rehacer",
    "counting.clear_all" to "Limpiar todo",
    "session.new" to "Nueva sesión",
    "session.list" to "Sesiones",
    "session.delete" to "Eliminar sesión",
    "session.duplicate" to "Duplicar",
    "session.rename" to "Renombrar",
    "session.search" to "Buscar sesiones...",
    "export.title" to "Exportar",
    "export.csv" to "CSV",
    "export.xlsx" to "XLSX",
    "export.json" to "JSON",
    "export.coco" to "COCO JSON",
    "export.pdf" to "PDF",
    "export.annotated" to "Imagen anotada",
    "export.bulk" to "Exportación masiva",
    "settings.title" to "Configuración",
    "settings.language" to "Idioma",
    "settings.icloud_sync" to "Sincronización iCloud",
    "settings.about" to "Acerca de",
    "settings.feedback" to "Comentarios",
    "object_type.add" to "Agregar categoría",
    "object_type.name" to "Nombre de categoría",
    "object_type.target" to "Cantidad objetivo",
    "region.add" to "Agregar región",
    "region.name" to "Nombre de región",
    "ai.processing" to "Procesando IA...",
    "ai.confidence" to "Umbral de confianza",
    "ai.no_model" to "No se encontró modelo IA",
    "ai.custom_model" to "Modelo personalizado",
    "error.generic" to "Ocurrió un error",
    "error.save" to "Error al guardar",
    "error.load" to "Error al cargar",
    "error.export" to "Error al exportar",
    "error.network" to "Error de red",
)

private val bundles: Map<String, Map<String, String>> by lazy {
    mapOf(
        "en" to englishBundle,
        "vi" to vietnameseBundle,
        "ja" to japaneseBundle,
        "ko" to koreanBundle,
        "zh" to chineseBundle,
        "fr" to frenchBundle,
        "de" to germanBundle,
        "es" to spanishBundle,
    )
}
