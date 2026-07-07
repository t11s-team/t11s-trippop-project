/**
 * Lightweight i18n dictionary.
 *
 * Why a custom dict instead of react-i18next?
 *  - We only have ~80 UI strings and 4 languages.
 *  - No need for pluralization rules, ICU MessageFormat, etc.
 *  - Bundle stays tiny, debugging stays obvious.
 *
 * If we ever need plural rules / namespaces / lazy-loaded locales,
 * swap this for react-i18next — the t(key) call sites stay the same.
 */

export const SUPPORTED_LANGS = ["ko", "en", "zh", "ar"];

/** Right-to-left languages (Arabic, Hebrew, ...). */
export const RTL_LANGS = ["ar"];

/** Human labels for the language switcher. */
export const LANG_LABELS = {
  ko: "한국어",
  en: "English",
  zh: "中文",
  ar: "العربية",
};

/** Short codes shown in the LangSelect pill. */
export const LANG_SHORT = {
  ko: "KO",
  en: "EN",
  zh: "ZH",
  ar: "AR",
};

/**
 * Full translation dictionary.
 *
 * Key convention: dotted namespace (page.field) for clarity.
 * Brand name "TripPop" is never translated — it appears verbatim in JSX.
 */
const dict = {
  ko: {
    // Auth — SignIn
    "auth.title.signin": "한국의 가장 핫한 팝업을 만나보세요",
    "auth.subtitle.signin": "전시, 이벤트, 특별한 경험을 몇 초 만에 예약하세요.",
    "auth.email.placeholder": "이메일을 입력하세요",
    "auth.password.placeholder": "비밀번호를 입력하세요",
    "auth.forgot": "비밀번호를 잊으셨나요?",
    "auth.signin": "로그인",
    "auth.signin.loading": "로그인 중...",
    "auth.trust.noPhone": "한국 전화번호가 필요 없어요",
    "auth.noAccount": "계정이 없으신가요?",
    "auth.haveAccount": "이미 계정이 있으신가요?",
    "auth.signup.link": "회원가입",
    "auth.signin.link": "로그인",

    // Auth — SignUp
    "auth.title.signup": "회원가입",
    "auth.subtitle.signup": "K-컬쳐 체험을 시작해 보세요",
    "auth.name.placeholder": "이름",
    "auth.email.signup.placeholder": "abc@email.com",
    "auth.password.signup.placeholder": "비밀번호",
    "auth.password.confirm.placeholder": "비밀번호 확인",
    "auth.signup": "가입하기",
    "auth.signup.loading": "계정 생성 중...",
    "auth.back": "뒤로 가기",

    // Validation
    "validate.email.required": "이메일을 입력해 주세요",
    "validate.email.invalid": "올바른 이메일을 입력해 주세요",
    "validate.password.required": "비밀번호를 입력해 주세요",
    "validate.password.short": "8자 이상 입력해 주세요",
    "validate.name.required": "이름을 입력해 주세요",
    "validate.confirm.required": "비밀번호를 한 번 더 입력해 주세요",
    "validate.confirm.mismatch": "비밀번호가 일치하지 않습니다",

    // Home
    "home.title": "K-컬쳐 체험을 둘러보세요",
    "home.subtitle": "팝업, 전시, 다양한 체험을 쉽게 예약하세요.",
    "home.search.placeholder": "팝업 검색…",
    "home.search.aria": "팝업 검색",
    "home.filter": "필터",
    "home.hot": "인기 팝업",
    "home.seeAll": "전체 보기",
    "home.loading": "체험을 불러오는 중…",
    "home.error": "이벤트를 불러올 수 없어요. 새로고침 해주세요.",
    "home.empty": "조건에 맞는 팝업이 없어요.",
    "home.left": "{n}자리 남음",
    "home.available": "예약 가능",

    // PromoBanner
    "promo.limited": "선착순 모집",
    "promo.noPhone": "한국 전화번호 불필요",
    "promo.title": "한정 자리, 실시간 예약",
    "promo.only": "{n}자리만 남음",
    "promo.reserve": "예약하기",

    // Categories
    "cat.all": "전체",
    "cat.popup": "팝업",
    "cat.kpop": "K-POP",
    "cat.exhibition": "전시",
    "cat.experience": "체험",

    // FilterModal
    "filter.title": "필터",
    "filter.close": "필터 닫기",
    "filter.when": "언제",
    "filter.when.today": "오늘",
    "filter.when.tomorrow": "내일",
    "filter.when.thisWeek": "이번 주",
    "filter.pickDate": "날짜 선택",
    "filter.location": "위치",
    "filter.location.seoul": "서울, 대한민국",
    "filter.location.current": "현재 위치",
    "filter.useLocation": "현재 위치 사용",
    "filter.themes": "테마",
    "filter.themes.optional": "(선택)",
    "filter.theme.kpop": "K-POP",
    "filter.theme.brand": "브랜드",
    "filter.theme.art": "아트 & 디자인",
    "filter.theme.photobooth": "포토부스",
    "filter.theme.characters": "캐릭터",
    "filter.availability": "예약 가능 여부",
    "filter.availableNow": "지금 예약 가능",
    "filter.availableNow.desc": "바로 예약하기",
    "filter.limited": "잔여석 적은 것만",
    "filter.limited.desc": "마감 임박",
    "filter.reset": "초기화",
    "filter.apply": "필터 적용",

    // EventDetail
    "detail.loading": "불러오는 중…",
    "detail.error": "이 팝업을 불러올 수 없어요.",
    "detail.backHome": "홈으로",
    "detail.back": "뒤로 가기",
    "detail.save": "저장하기",
    "detail.unsave": "저장 해제",
    "detail.about": "이 팝업 소개",
    "detail.offers": "특별 혜택",
    "detail.location": "위치",
    "detail.viewMap": "지도에서 보기",
    "detail.eventDetails": "이벤트 상세",
    "detail.gallery.intro": "팝업 체험을 더 자세히 살펴보세요",
    "detail.reserve": "예약하기",
    "detail.reserving": "예약 중…",
    "detail.reserved": "예약 완료 ✓",
    "detail.noSlots": "이 팝업은 예약 가능한 자리가 없습니다.",
    "detail.confirmed": "예약이 완료되었습니다!",
    "detail.alreadyReserved": "이미 예약된 자리입니다 — 기존 예약을 유지합니다.",
    "detail.selectSlot": "날짜 선택",
    "detail.selectSlot.required": "예약하려면 날짜를 먼저 선택해 주세요.",
    "detail.slot.soldout": "마감",

    // Reservations
    "res.title": "내 예약",
    "res.loading": "불러오는 중…",
    "res.empty.title": "예약 내역이 없어요",
    "res.empty.desc": "팝업을 찾아 자리를 예약해 보세요.",
    "res.empty.cta": "팝업 둘러보기",
    "res.status.confirmed": "확정",
    "res.status.cancelled": "취소됨",
    "res.status.pending": "대기 중",

    // Profile
    "profile.title": "마이페이지",
    "profile.guest": "게스트",
    "profile.menu.reservations": "내 예약",
    "profile.menu.saved": "저장한 항목",
    "profile.menu.security": "계정 & 보안",
    "profile.menu.notifications": "알림",
    "profile.menu.language": "언어",
    "profile.signout": "로그아웃",

    // Placeholder + Nav
    "placeholder.comingSoon": "곧 만나요",
    "nav.home": "홈",
    "nav.reservations": "예약",
    "nav.schedule": "일정",
    "nav.saved": "저장",
    "nav.me": "내 정보",
    "nav.primary": "주 메뉴",

    // Language switcher
    "lang.change": "언어 변경",

    // Errors
    "error.network": "서버에 연결할 수 없어요. 네트워크를 확인해 주세요.",
    "error.duplicateEmail": "이미 가입된 이메일입니다.",
    "error.noAccount": "이 이메일로 가입된 계정이 없습니다. 회원가입 해주세요.",
    "error.sessionExpired": "세션이 만료되어 다시 로그인해주세요.",
    "error.reserve.duplicate": "이미 예약하셨습니다.",
    "error.reserve.soldout": "마감되었습니다.",
    "error.reserve.retry": "잠시 후 다시 시도해 주세요.",
    "error.reserve.failed": "예약에 실패했습니다. 다시 시도해 주세요.",

    // Date — day names (short)
    "date.day.sun": "일",
    "date.day.mon": "월",
    "date.day.tue": "화",
    "date.day.wed": "수",
    "date.day.thu": "목",
    "date.day.fri": "금",
    "date.day.sat": "토",
  },

  en: {
    // Auth — SignIn
    "auth.title.signin": "Explore Korea's hottest pop-ups",
    "auth.subtitle.signin":
      "Book exhibitions, events, and unique experiences in seconds.",
    "auth.email.placeholder": "Enter your email",
    "auth.password.placeholder": "Enter your password",
    "auth.forgot": "Forgot Password?",
    "auth.signin": "Sign In",
    "auth.signin.loading": "Signing in...",
    "auth.trust.noPhone": "No Korean Phone number required",
    "auth.noAccount": "Don't have an account?",
    "auth.haveAccount": "Already have an account?",
    "auth.signup.link": "Sign Up",
    "auth.signin.link": "Sign In",

    // Auth — SignUp
    "auth.title.signup": "Sign up",
    "auth.subtitle.signup": "Start exploring K-culture experiences",
    "auth.name.placeholder": "Full name",
    "auth.email.signup.placeholder": "abc@email.com",
    "auth.password.signup.placeholder": "Your password",
    "auth.password.confirm.placeholder": "Confirm password",
    "auth.signup": "Sign Up",
    "auth.signup.loading": "Creating account...",
    "auth.back": "Go back",

    // Validation
    "validate.email.required": "Email is required",
    "validate.email.invalid": "Enter a valid email",
    "validate.password.required": "Password is required",
    "validate.password.short": "Use at least 8 characters",
    "validate.name.required": "Full name is required",
    "validate.confirm.required": "Please confirm your password",
    "validate.confirm.mismatch": "Passwords do not match",

    // Home
    "home.title": "Explore K-Culture Experiences",
    "home.subtitle": "Book pop-ups, exhibitions and experiences easily.",
    "home.search.placeholder": "Search pop-ups…",
    "home.search.aria": "Search pop-ups",
    "home.filter": "Filter",
    "home.hot": "HOT Pop-ups",
    "home.seeAll": "See all",
    "home.loading": "Loading experiences…",
    "home.error": "Couldn't load events. Pull to refresh.",
    "home.empty": "No pop-ups match your filters.",
    "home.left": "{n} left",
    "home.available": "Available",

    // PromoBanner
    "promo.limited": "LIMITED SLOTS",
    "promo.noPhone": "NO KOREAN PHONE NEEDED",
    "promo.title": "Book Limited Slots in Real-Time",
    "promo.only": "Only {n} left",
    "promo.reserve": "Reserve Now",

    // Categories
    "cat.all": "ALL",
    "cat.popup": "Pop-up",
    "cat.kpop": "K-POP",
    "cat.exhibition": "Exhibition",
    "cat.experience": "Experience",

    // FilterModal
    "filter.title": "Filter",
    "filter.close": "Close filter",
    "filter.when": "When",
    "filter.when.today": "Today",
    "filter.when.tomorrow": "Tomorrow",
    "filter.when.thisWeek": "This week",
    "filter.pickDate": "Pick a date",
    "filter.location": "Location",
    "filter.location.seoul": "Seoul, South Korea",
    "filter.location.current": "Current location",
    "filter.useLocation": "Use current location",
    "filter.themes": "Themes",
    "filter.themes.optional": "(Optional)",
    "filter.theme.kpop": "K-POP",
    "filter.theme.brand": "Brand",
    "filter.theme.art": "Art & Design",
    "filter.theme.photobooth": "Photobooth",
    "filter.theme.characters": "Characters",
    "filter.availability": "Availability",
    "filter.availableNow": "Available now",
    "filter.availableNow.desc": "Book immediately",
    "filter.limited": "Limited slots only",
    "filter.limited.desc": "Almost sold out",
    "filter.reset": "Reset",
    "filter.apply": "Apply Filters",

    // EventDetail
    "detail.loading": "Loading…",
    "detail.error": "Couldn't load this pop-up.",
    "detail.backHome": "Back to Home",
    "detail.back": "Go back",
    "detail.save": "Save",
    "detail.unsave": "Remove from saved",
    "detail.about": "About this pop-up",
    "detail.offers": "Special Offers",
    "detail.location": "Location",
    "detail.viewMap": "View on Map",
    "detail.eventDetails": "Event Details",
    "detail.gallery.intro": "Take a closer look at the pop-up experience",
    "detail.reserve": "Reserve Now",
    "detail.reserving": "Reserving…",
    "detail.reserved": "Reserved ✓",
    "detail.noSlots": "No slots available for this pop-up.",
    "detail.confirmed": "Reservation confirmed!",
    "detail.alreadyReserved": "Already reserved — confirmation kept.",
    "detail.selectSlot": "Select a date",
    "detail.selectSlot.required": "Pick a date before reserving.",
    "detail.slot.soldout": "Sold out",

    // Reservations
    "res.title": "My Reservations",
    "res.loading": "Loading…",
    "res.empty.title": "No reservations yet",
    "res.empty.desc": "Find a pop-up and reserve your spot.",
    "res.empty.cta": "Explore pop-ups",
    "res.status.confirmed": "Confirmed",
    "res.status.cancelled": "Cancelled",
    "res.status.pending": "Pending",

    // Profile
    "profile.title": "Me",
    "profile.guest": "Guest",
    "profile.menu.reservations": "My Reservations",
    "profile.menu.saved": "Saved",
    "profile.menu.security": "Account & Security",
    "profile.menu.notifications": "Notifications",
    "profile.menu.language": "Language",
    "profile.signout": "Sign Out",

    // Placeholder + Nav
    "placeholder.comingSoon": "Coming soon",
    "nav.home": "Home",
    "nav.reservations": "Reservations",
    "nav.schedule": "Schedule",
    "nav.saved": "Saved",
    "nav.me": "Me",
    "nav.primary": "Primary",

    // Language switcher
    "lang.change": "Change language",

    // Errors
    "error.network": "Cannot reach the server. Check your connection.",
    "error.duplicateEmail": "An account with this email already exists.",
    "error.noAccount": "No account found for this email. Try signing up.",
    "error.sessionExpired": "Your session expired. Please sign in again.",
    "error.reserve.duplicate": "You've already reserved this.",
    "error.reserve.soldout": "Sold out.",
    "error.reserve.retry": "Something went wrong. Please try again.",
    "error.reserve.failed": "Reservation failed. Please try again.",

    // Date — day names (short)
    "date.day.sun": "Sun",
    "date.day.mon": "Mon",
    "date.day.tue": "Tue",
    "date.day.wed": "Wed",
    "date.day.thu": "Thu",
    "date.day.fri": "Fri",
    "date.day.sat": "Sat",
  },

  zh: {
    // Auth
    "auth.title.signin": "探索韩国最火爆的快闪活动",
    "auth.subtitle.signin": "几秒钟内即可预订展览、活动和独特体验。",
    "auth.email.placeholder": "请输入邮箱",
    "auth.password.placeholder": "请输入密码",
    "auth.forgot": "忘记密码?",
    "auth.signin": "登录",
    "auth.signin.loading": "登录中...",
    "auth.trust.noPhone": "无需韩国手机号",
    "auth.noAccount": "还没有账号?",
    "auth.haveAccount": "已经有账号?",
    "auth.signup.link": "注册",
    "auth.signin.link": "登录",

    "auth.title.signup": "注册",
    "auth.subtitle.signup": "开启你的 K-culture 体验之旅",
    "auth.name.placeholder": "姓名",
    "auth.email.signup.placeholder": "abc@email.com",
    "auth.password.signup.placeholder": "密码",
    "auth.password.confirm.placeholder": "确认密码",
    "auth.signup": "注册",
    "auth.signup.loading": "正在创建账号...",
    "auth.back": "返回",

    "validate.email.required": "请输入邮箱",
    "validate.email.invalid": "请输入有效的邮箱",
    "validate.password.required": "请输入密码",
    "validate.password.short": "至少 8 个字符",
    "validate.name.required": "请输入姓名",
    "validate.confirm.required": "请再次输入密码",
    "validate.confirm.mismatch": "两次密码不一致",

    "home.title": "探索 K-Culture 体验",
    "home.subtitle": "轻松预订快闪、展览和各类体验。",
    "home.search.placeholder": "搜索快闪活动…",
    "home.search.aria": "搜索快闪活动",
    "home.filter": "筛选",
    "home.hot": "热门快闪",
    "home.seeAll": "查看全部",
    "home.loading": "正在加载体验…",
    "home.error": "无法加载活动。请下拉刷新。",
    "home.empty": "没有符合筛选条件的快闪。",
    "home.left": "剩 {n} 位",
    "home.available": "可预订",

    "promo.limited": "限量名额",
    "promo.noPhone": "无需韩国手机号",
    "promo.title": "实时预订限量名额",
    "promo.only": "仅剩 {n} 位",
    "promo.reserve": "立即预订",

    "cat.all": "全部",
    "cat.popup": "快闪",
    "cat.kpop": "K-POP",
    "cat.exhibition": "展览",
    "cat.experience": "体验",

    "filter.title": "筛选",
    "filter.close": "关闭筛选",
    "filter.when": "时间",
    "filter.when.today": "今天",
    "filter.when.tomorrow": "明天",
    "filter.when.thisWeek": "本周",
    "filter.pickDate": "选择日期",
    "filter.location": "地点",
    "filter.location.seoul": "韩国 首尔",
    "filter.location.current": "当前位置",
    "filter.useLocation": "使用当前位置",
    "filter.themes": "主题",
    "filter.themes.optional": "(可选)",
    "filter.theme.kpop": "K-POP",
    "filter.theme.brand": "品牌",
    "filter.theme.art": "艺术 & 设计",
    "filter.theme.photobooth": "拍照亭",
    "filter.theme.characters": "卡通形象",
    "filter.availability": "可预订情况",
    "filter.availableNow": "立即可订",
    "filter.availableNow.desc": "马上预订",
    "filter.limited": "仅剩少量",
    "filter.limited.desc": "即将售罄",
    "filter.reset": "重置",
    "filter.apply": "应用筛选",

    "detail.loading": "加载中…",
    "detail.error": "无法加载该快闪。",
    "detail.backHome": "返回首页",
    "detail.back": "返回",
    "detail.save": "收藏",
    "detail.unsave": "取消收藏",
    "detail.about": "关于这个快闪",
    "detail.offers": "特别优惠",
    "detail.location": "位置",
    "detail.viewMap": "在地图中查看",
    "detail.eventDetails": "活动详情",
    "detail.gallery.intro": "更深入了解快闪体验",
    "detail.reserve": "立即预订",
    "detail.reserving": "正在预订…",
    "detail.reserved": "已预订 ✓",
    "detail.noSlots": "该快闪没有可预订名额。",
    "detail.confirmed": "预订成功!",
    "detail.alreadyReserved": "已预订过 — 保留原预订。",
    "detail.selectSlot": "选择日期",
    "detail.selectSlot.required": "请先选择日期再预订。",
    "detail.slot.soldout": "已售罄",

    "res.title": "我的预订",
    "res.loading": "加载中…",
    "res.empty.title": "暂无预订",
    "res.empty.desc": "找一个快闪并预订你的位置。",
    "res.empty.cta": "去看快闪",
    "res.status.confirmed": "已确认",
    "res.status.cancelled": "已取消",
    "res.status.pending": "处理中",

    "profile.title": "个人中心",
    "profile.guest": "访客",
    "profile.menu.reservations": "我的预订",
    "profile.menu.saved": "收藏",
    "profile.menu.security": "账户与安全",
    "profile.menu.notifications": "通知",
    "profile.menu.language": "语言",
    "profile.signout": "登出",

    "placeholder.comingSoon": "敬请期待",
    "nav.home": "首页",
    "nav.reservations": "预订",
    "nav.schedule": "日程",
    "nav.saved": "收藏",
    "nav.me": "我的",
    "nav.primary": "主菜单",

    "lang.change": "切换语言",

    "error.network": "无法连接服务器。请检查网络。",
    "error.duplicateEmail": "该邮箱已被注册。",
    "error.noAccount": "未找到该邮箱的账号。请注册。",
    "error.sessionExpired": "登录已过期，请重新登录。",
    "error.reserve.duplicate": "您已经预订过了。",
    "error.reserve.soldout": "已售罄。",
    "error.reserve.retry": "出了点问题，请重试。",
    "error.reserve.failed": "预订失败，请重试。",

    "date.day.sun": "周日",
    "date.day.mon": "周一",
    "date.day.tue": "周二",
    "date.day.wed": "周三",
    "date.day.thu": "周四",
    "date.day.fri": "周五",
    "date.day.sat": "周六",
  },

  ar: {
    // Auth
    "auth.title.signin": "اكتشف أكثر الفعاليات المؤقتة شهرة في كوريا",
    "auth.subtitle.signin": "احجز المعارض والفعاليات والتجارب الفريدة خلال ثوانٍ.",
    "auth.email.placeholder": "أدخل بريدك الإلكتروني",
    "auth.password.placeholder": "أدخل كلمة المرور",
    "auth.forgot": "هل نسيت كلمة المرور؟",
    "auth.signin": "تسجيل الدخول",
    "auth.signin.loading": "جارٍ تسجيل الدخول...",
    "auth.trust.noPhone": "لا حاجة لرقم هاتف كوري",
    "auth.noAccount": "ليس لديك حساب؟",
    "auth.haveAccount": "لديك حساب بالفعل؟",
    "auth.signup.link": "إنشاء حساب",
    "auth.signin.link": "تسجيل الدخول",

    "auth.title.signup": "إنشاء حساب",
    "auth.subtitle.signup": "ابدأ استكشاف تجارب الثقافة الكورية",
    "auth.name.placeholder": "الاسم الكامل",
    "auth.email.signup.placeholder": "abc@email.com",
    "auth.password.signup.placeholder": "كلمة المرور",
    "auth.password.confirm.placeholder": "تأكيد كلمة المرور",
    "auth.signup": "إنشاء حساب",
    "auth.signup.loading": "جارٍ إنشاء الحساب...",
    "auth.back": "رجوع",

    "validate.email.required": "البريد الإلكتروني مطلوب",
    "validate.email.invalid": "أدخل بريدًا إلكترونيًا صالحًا",
    "validate.password.required": "كلمة المرور مطلوبة",
    "validate.password.short": "استخدم 8 أحرف على الأقل",
    "validate.name.required": "الاسم الكامل مطلوب",
    "validate.confirm.required": "يرجى تأكيد كلمة المرور",
    "validate.confirm.mismatch": "كلمتا المرور غير متطابقتين",

    "home.title": "استكشف تجارب الثقافة الكورية",
    "home.subtitle": "احجز الفعاليات المؤقتة والمعارض والتجارب بسهولة.",
    "home.search.placeholder": "ابحث عن الفعاليات…",
    "home.search.aria": "ابحث عن الفعاليات",
    "home.filter": "تصفية",
    "home.hot": "الأكثر رواجًا",
    "home.seeAll": "عرض الكل",
    "home.loading": "جارٍ تحميل التجارب…",
    "home.error": "تعذّر تحميل الفعاليات. اسحب للتحديث.",
    "home.empty": "لا توجد فعاليات مطابقة لعوامل التصفية.",
    "home.left": "متبقي {n}",
    "home.available": "متاح",

    "promo.limited": "أماكن محدودة",
    "promo.noPhone": "لا حاجة لرقم هاتف كوري",
    "promo.title": "احجز الأماكن المحدودة في الوقت الفعلي",
    "promo.only": "متبقي {n} فقط",
    "promo.reserve": "احجز الآن",

    "cat.all": "الكل",
    "cat.popup": "فعالية مؤقتة",
    "cat.kpop": "K-POP",
    "cat.exhibition": "معرض",
    "cat.experience": "تجربة",

    "filter.title": "تصفية",
    "filter.close": "إغلاق التصفية",
    "filter.when": "متى",
    "filter.when.today": "اليوم",
    "filter.when.tomorrow": "غدًا",
    "filter.when.thisWeek": "هذا الأسبوع",
    "filter.pickDate": "اختر تاريخًا",
    "filter.location": "الموقع",
    "filter.location.seoul": "سيول، كوريا الجنوبية",
    "filter.location.current": "الموقع الحالي",
    "filter.useLocation": "استخدم الموقع الحالي",
    "filter.themes": "المواضيع",
    "filter.themes.optional": "(اختياري)",
    "filter.theme.kpop": "K-POP",
    "filter.theme.brand": "علامة تجارية",
    "filter.theme.art": "فن وتصميم",
    "filter.theme.photobooth": "كشك التصوير",
    "filter.theme.characters": "شخصيات",
    "filter.availability": "التوفر",
    "filter.availableNow": "متاح الآن",
    "filter.availableNow.desc": "احجز فورًا",
    "filter.limited": "أماكن محدودة فقط",
    "filter.limited.desc": "تكاد تنفد",
    "filter.reset": "إعادة تعيين",
    "filter.apply": "تطبيق التصفية",

    "detail.loading": "جارٍ التحميل…",
    "detail.error": "تعذّر تحميل هذه الفعالية.",
    "detail.backHome": "العودة للرئيسية",
    "detail.back": "رجوع",
    "detail.save": "حفظ",
    "detail.unsave": "إزالة من المحفوظات",
    "detail.about": "عن هذه الفعالية",
    "detail.offers": "عروض خاصة",
    "detail.location": "الموقع",
    "detail.viewMap": "عرض على الخريطة",
    "detail.eventDetails": "تفاصيل الفعالية",
    "detail.gallery.intro": "ألقِ نظرة أقرب على تجربة الفعالية",
    "detail.reserve": "احجز الآن",
    "detail.reserving": "جارٍ الحجز…",
    "detail.reserved": "محجوز ✓",
    "detail.noSlots": "لا توجد أماكن متاحة لهذه الفعالية.",
    "detail.confirmed": "تم تأكيد الحجز!",
    "detail.alreadyReserved": "محجوز مسبقًا — تم الاحتفاظ بالحجز.",
    "detail.selectSlot": "اختر التاريخ",
    "detail.selectSlot.required": "اختر تاريخًا قبل الحجز.",
    "detail.slot.soldout": "نفدت الأماكن",

    "res.title": "حجوزاتي",
    "res.loading": "جارٍ التحميل…",
    "res.empty.title": "لا توجد حجوزات بعد",
    "res.empty.desc": "ابحث عن فعالية واحجز مكانك.",
    "res.empty.cta": "استكشف الفعاليات",
    "res.status.confirmed": "مؤكد",
    "res.status.cancelled": "ملغى",
    "res.status.pending": "قيد المعالجة",

    "profile.title": "حسابي",
    "profile.guest": "زائر",
    "profile.menu.reservations": "حجوزاتي",
    "profile.menu.saved": "المحفوظات",
    "profile.menu.security": "الحساب والأمان",
    "profile.menu.notifications": "الإشعارات",
    "profile.menu.language": "اللغة",
    "profile.signout": "تسجيل الخروج",

    "placeholder.comingSoon": "قريبًا",
    "nav.home": "الرئيسية",
    "nav.reservations": "الحجوزات",
    "nav.schedule": "الجدول",
    "nav.saved": "المحفوظات",
    "nav.me": "حسابي",
    "nav.primary": "القائمة الرئيسية",

    "lang.change": "تغيير اللغة",

    "error.network": "تعذّر الوصول إلى الخادم. تحقق من اتصالك.",
    "error.duplicateEmail": "يوجد حساب بهذا البريد الإلكتروني بالفعل.",
    "error.noAccount": "لم يتم العثور على حساب بهذا البريد. جرّب إنشاء حساب.",
    "error.sessionExpired": "انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.",
    "error.reserve.duplicate": "لقد قمت بالحجز بالفعل.",
    "error.reserve.soldout": "نفدت الأماكن.",
    "error.reserve.retry": "حدث خطأ ما. يرجى المحاولة مرة أخرى.",
    "error.reserve.failed": "فشل الحجز. يرجى المحاولة مرة أخرى.",

    "date.day.sun": "الأحد",
    "date.day.mon": "الإثنين",
    "date.day.tue": "الثلاثاء",
    "date.day.wed": "الأربعاء",
    "date.day.thu": "الخميس",
    "date.day.fri": "الجمعة",
    "date.day.sat": "السبت",
  },
};

/**
 * Resolve a translation key for a given language.
 *
 * Falls back to Korean (the default) if the key is missing in the chosen
 * language, then to the key itself so missing strings are visible during dev.
 *
 * @param {string} key   - dotted i18n key, e.g. "home.title"
 * @param {string} lang  - "ko" | "en" | "zh" | "ar"
 * @param {object} [vars] - optional interpolation, e.g. { n: 12 } for "{n}"
 */
export function t(key, lang, vars) {
  const value = dict[lang]?.[key] ?? dict.ko[key] ?? key;
  if (!vars) return value;
  return value.replace(/\{(\w+)\}/g, (_, name) =>
    Object.hasOwn(vars, name) ? String(vars[name]) : `{${name}}`
  );
}

/**
 * Detect a preferred language from the browser, narrowed to SUPPORTED_LANGS.
 * Used once on first visit before the user has picked anything.
 */
export function detectBrowserLanguage() {
  if (typeof navigator === "undefined") return "ko";
  const candidates = navigator.languages?.length
    ? navigator.languages
    : [navigator.language];
  for (const raw of candidates) {
    const code = (raw || "").toLowerCase().split("-")[0];
    if (SUPPORTED_LANGS.includes(code)) return code;
  }
  return "ko"; // project default per team decision
}
