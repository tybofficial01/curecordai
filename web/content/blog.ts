import type { AppLocale } from "@/i18n/routing";

/** Same string authored once per locale. Falls back to English if a locale is missing. */
export type LocalizedText = Record<AppLocale, string>;

export interface BlogContentBlock {
  /** Optional H2 shown above this block - lets a reader or AI answer engine jump straight to
   *  the sub-question this paragraph answers, instead of one undifferentiated wall of text. */
  heading?: LocalizedText;
  body: LocalizedText;
  /** Optional contextual link to the specific CurecordAI page this block is describing. */
  link?: { href: string; label: LocalizedText };
}

export interface BlogPost {
  slug: string;
  title: LocalizedText;
  excerpt: LocalizedText;
  content: BlogContentBlock[];
  publishedAt: string;
  updatedAt: string;
  authorName: string;
  category: LocalizedText;
}

/** Picks the string for `locale`, falling back to English for any gap. */
export function localize(text: LocalizedText, locale: string): string {
  return text[locale as AppLocale] ?? text.en;
}

export const blogPosts: BlogPost[] = [
  {
    slug: "how-to-organize-medical-records-at-home",
    title: {
      en: "How to Organize Medical Records at Home",
      ur: "گھر پر میڈیکل ریکارڈز کو منظم کرنے کا طریقہ",
      "roman-ur": "Ghar Par Medical Records Ko Organize Karne Ka Tareeqa",
    },
    excerpt: {
      en: "A simple system for keeping every family member's prescriptions, lab reports, and discharge summaries in one place - without losing anything.",
      ur: "ہر خاندان کے فرد کے نسخے، لیب رپورٹس اور ڈسچارج سمریاں ایک ہی جگہ محفوظ رکھنے کا ایک آسان نظام - بغیر کچھ کھوئے۔",
      "roman-ur":
        "Har family member ke prescriptions, lab reports aur discharge summaries ko aik hi jagah mehfooz rakhne ka aik asaan nizam - bina kuch khoye.",
    },
    content: [
      {
        body: {
          en: "Most families store medical documents the same way: a mix of paper folders, phone photos, and WhatsApp chats with a doctor or relative. It works until you need a specific report during an emergency, and nobody can find it.",
          ur: "زیادہ تر خاندان میڈیکل دستاویزات کو ایک ہی انداز میں رکھتے ہیں: کاغذی فولڈرز، فون کی تصاویر اور ڈاکٹر یا رشتہ دار کے ساتھ واٹس ایپ چیٹس کا مجموعہ۔ یہ طریقہ اس وقت تک چلتا ہے جب تک ایمرجنسی میں کسی مخصوص رپورٹ کی ضرورت نہ پڑے، اور پھر کوئی اسے ڈھونڈ نہیں پاتا۔",
          "roman-ur":
            "Ziyada tar families medical documents ko aik hi tareeqay se rakhti hain: paper folders, phone ki tasveerein, aur doctor ya rishtay daar ke sath WhatsApp chats ka mixture. Yeh tareeqa tab tak chalta hai jab tak emergency mein kisi khaas report ki zaroorat na paray, aur phir koi usay dhoond nahi pata.",
        },
      },
      {
        heading: {
          en: "Pick one place for everything",
          ur: "ہر چیز کے لیے ایک ہی جگہ منتخب کریں",
          "roman-ur": "Har Cheez Ke Liye Aik Hi Jagah Muntakhib Karein",
        },
        body: {
          en: "The fastest way to fix this is to pick one place for everything, digital or physical, and commit to it. A digital health vault like CurecordAI works well because every document is timestamped, tagged to the right family member, and searchable - so a lab report from two years ago is as easy to find as one from yesterday.",
          ur: "اس مسئلے کا سب سے تیز حل یہ ہے کہ ہر چیز کے لیے ایک ہی جگہ - چاہے ڈیجیٹل ہو یا فزیکل - منتخب کریں اور اس پر قائم رہیں۔ CurecordAI جیسا ڈیجیٹل ہیلتھ والٹ اچھی طرح کام کرتا ہے کیونکہ ہر دستاویز پر تاریخ درج ہوتی ہے، اسے صحیح خاندان کے فرد سے منسلک کیا جاتا ہے، اور اسے تلاش کیا جا سکتا ہے - اس لیے دو سال پرانی لیب رپورٹ بھی اتنی ہی آسانی سے مل جاتی ہے جتنی کل کی۔",
          "roman-ur":
            "Iska sab se tez hal yeh hai ke har cheez ke liye aik hi jagah - chahe digital ho ya physical - muntakhib karein aur us par qaim rahein. CurecordAI jaisa digital health vault acha kaam karta hai kyunke har document par timestamp lagta hai, usay sahi family member se link kiya jata hai, aur usay search kiya ja sakta hai - is liye do saal purani lab report bhi utni hi asaani se milti hai jitni kal ki.",
        },
        link: {
          href: "/features",
          label: {
            en: "See how CurecordAI's health vault organizes every upload",
            ur: "دیکھیں CurecordAI کا ہیلتھ والٹ ہر اپ لوڈ کو کیسے منظم کرتا ہے",
            "roman-ur": "Dekhein CurecordAI ka health vault har upload ko kaise organize karta hai",
          },
        },
      },
      {
        heading: {
          en: "Start with the documents you already have",
          ur: "ان دستاویزات سے شروعات کریں جو آپ کے پاس پہلے سے موجود ہیں",
          "roman-ur": "Un Documents Se Shuruaat Karein Jo Aap Ke Paas Pehlay Se Mojood Hain",
        },
        body: {
          en: "Photograph or upload prescriptions, lab reports, vaccination cards, and discharge summaries. Group them by family member rather than by date, since most people search by 'my father's reports' rather than 'reports from March'.",
          ur: "نسخوں، لیب رپورٹس، ویکسینیشن کارڈز اور ڈسچارج سمریوں کی تصویر لیں یا انہیں اپ لوڈ کریں۔ انہیں تاریخ کے بجائے خاندان کے فرد کے مطابق گروپ کریں، کیونکہ زیادہ تر لوگ 'مارچ کی رپورٹس' کے بجائے 'میرے والد کی رپورٹس' تلاش کرتے ہیں۔",
          "roman-ur":
            "Prescriptions, lab reports, vaccination cards aur discharge summaries ki photo lein ya inhein upload karein. Inhein date ke bajaye family member ke hisaab se group karein, kyunke ziyada tar log 'March ki reports' ke bajaye 'mere walid ki reports' search karte hain.",
        },
      },
      {
        heading: {
          en: "Build the habit after every visit",
          ur: "ہر وزٹ کے بعد یہ عادت بنائیں",
          "roman-ur": "Har Visit Ke Baad Yeh Aadat Banayein",
        },
        body: {
          en: "Once your existing documents are organized, build the habit of uploading new ones immediately after every appointment. A five second upload after a visit saves hours of searching later.",
          ur: "ایک بار جب آپ کی موجودہ دستاویزات منظم ہو جائیں، تو ہر اپائنٹمنٹ کے فوراً بعد نئی دستاویزات اپ لوڈ کرنے کی عادت بنائیں۔ وزٹ کے بعد پانچ سیکنڈ کا اپ لوڈ بعد میں گھنٹوں کی تلاش بچا دیتا ہے۔",
          "roman-ur":
            "Aik dafa jab aap ke mojooda documents organize ho jayein, to har appointment ke foran baad nayi documents upload karne ki aadat banayein. Visit ke baad sirf paanch second ka upload baad mein ghanton ki talaash bacha deta hai.",
        },
      },
    ],
    publishedAt: "2026-05-12T09:00:00.000Z",
    updatedAt: "2026-06-02T09:00:00.000Z",
    authorName: "CurecordAI Team",
    category: {
      en: "Organization",
      ur: "تنظیم",
      "roman-ur": "Tarteeb",
    },
  },
  {
    slug: "understanding-your-lab-report-a-plain-language-guide",
    title: {
      en: "Understanding Your Lab Report: A Plain Language Guide",
      ur: "اپنی لیب رپورٹ کو سمجھنا: ایک آسان زبان میں گائیڈ",
      "roman-ur": "Apni Lab Report Ko Samajhna: Aik Asaan Zaban Mein Guide",
    },
    excerpt: {
      en: "Lab reports are full of abbreviations and reference ranges. Here is how to read one without a medical degree.",
      ur: "لیب رپورٹس مخففات اور ریفرنس رینجز سے بھری ہوتی ہیں۔ یہاں جانیں کہ بغیر میڈیکل ڈگری کے اسے کیسے پڑھا جائے۔",
      "roman-ur": "Lab reports abbreviations aur reference ranges se bhari hoti hain. Yahan janein ke bina medical degree ke inhein kaise parha jaye.",
    },
    content: [
      {
        heading: {
          en: "What a reference range actually means",
          ur: "ریفرنس رینج کا اصل مطلب کیا ہے",
          "roman-ur": "Reference Range Ka Asal Matlab Kya Hai",
        },
        body: {
          en: "A lab report usually lists three things for each test: the value measured, the unit, and a reference range. The reference range is what a lab considers typical for a healthy person, not a strict pass or fail line.",
          ur: "ایک لیب رپورٹ عام طور پر ہر ٹیسٹ کے لیے تین چیزیں درج کرتی ہے: ناپی گئی ویلیو، یونٹ، اور ریفرنس رینج۔ ریفرنس رینج وہ ہے جسے لیب ایک صحت مند شخص کے لیے عام سمجھتی ہے، نہ کہ پاس یا فیل کی سخت لکیر۔",
          "roman-ur":
            "Aik lab report aam tor par har test ke liye teen cheezein deti hai: napi gayi value, unit, aur reference range. Reference range woh hai jise lab aik sehatmand shakhs ke liye aam samajhti hai, na ke pass ya fail ki sakht line.",
        },
      },
      {
        heading: {
          en: "An out-of-range result isn't automatically a problem",
          ur: "رینج سے باہر نتیجہ خود بخود کوئی مسئلہ نہیں ہوتا",
          "roman-ur": "Range Se Bahar Natija Khud Bakhud Koi Masla Nahi Hota",
        },
        body: {
          en: "A result slightly outside the reference range is not automatically a cause for alarm. Ranges vary between labs and can be affected by age, sex, and even the time of day a sample was taken. Context from a doctor, or from your own health history, matters more than a single number.",
          ur: "ریفرنس رینج سے تھوڑا سا باہر نتیجہ خود بخود پریشانی کی وجہ نہیں بنتا۔ رینجز مختلف لیبز میں مختلف ہو سکتی ہیں اور عمر، جنس، اور یہاں تک کہ نمونہ لینے کے وقت سے بھی متاثر ہو سکتی ہیں۔ ڈاکٹر کی رائے، یا آپ کی اپنی صحت کی تاریخ، ایک اکیلے نمبر سے کہیں زیادہ اہم ہے۔",
          "roman-ur":
            "Reference range se thora sa bahar natija khud bakhud pareshani ki wajah nahi banta. Ranges mukhtalif labs mein mukhtalif ho sakti hain aur umar, jins, aur yahan tak ke sample lene ke waqt se bhi mutasir ho sakti hain. Doctor ki raye, ya aap ki apni sehat ki tareekh, aik akeli number se kahin ziyada ahem hai.",
        },
      },
      {
        heading: {
          en: "How an AI assistant can help you understand a result",
          ur: "ایک AI اسسٹنٹ نتیجہ سمجھنے میں کیسے مدد کر سکتا ہے",
          "roman-ur": "Aik AI Assistant Natija Samajhne Mein Kaise Madad Kar Sakta Hai",
        },
        body: {
          en: "This is exactly the kind of question an AI health assistant like the one built into CurecordAI is designed for - it can explain what a specific value means in the context of your own uploaded history, in plain Urdu or English, so you walk into your next appointment already understanding the basics.",
          ur: "بالکل اسی قسم کے سوال کے لیے CurecordAI میں شامل AI ہیلتھ اسسٹنٹ بنایا گیا ہے - یہ آپ کی اپنی اپ لوڈ کردہ تاریخ کے تناظر میں کسی مخصوص ویلیو کا مطلب آسان اردو یا انگریزی میں بتا سکتا ہے، تاکہ آپ اپنی اگلی اپائنٹمنٹ میں پہلے سے بنیادی باتیں سمجھ کر جائیں۔",
          "roman-ur":
            "Bilkul isi qisam ke sawal ke liye CurecordAI mein shamil AI health assistant banaya gaya hai - yeh aap ki apni upload ki gayi history ke tanazur mein kisi khaas value ka matlab asaan Urdu ya English mein bata sakta hai, taake aap apni agli appointment mein pehlay se basic baatein samajh kar jayein.",
        },
        link: {
          href: "/features",
          label: {
            en: "See how the AI Medical Assistant works",
            ur: "دیکھیں AI میڈیکل اسسٹنٹ کیسے کام کرتا ہے",
            "roman-ur": "Dekhein AI Medical Assistant Kaise Kaam Karta Hai",
          },
        },
      },
      {
        heading: {
          en: "When to talk to your doctor",
          ur: "اپنے ڈاکٹر سے کب بات کرنی چاہیے",
          "roman-ur": "Apne Doctor Se Kab Baat Karni Chahiye",
        },
        body: {
          en: "Always confirm any concerning result with your doctor. An AI assistant can help you understand a report, but it does not replace a medical diagnosis.",
          ur: "کسی بھی پریشان کن نتیجے کی ہمیشہ اپنے ڈاکٹر سے تصدیق کریں۔ AI اسسٹنٹ رپورٹ سمجھنے میں مدد کر سکتا ہے، لیکن یہ میڈیکل تشخیص کا متبادل نہیں ہے۔",
          "roman-ur":
            "Kisi bhi pareshan kun natijay ki hamesha apne doctor se tasdeeq karein. AI assistant report samajhne mein madad kar sakta hai, lekin yeh medical diagnosis ka mutabadil nahi hai.",
        },
      },
    ],
    publishedAt: "2026-06-01T09:00:00.000Z",
    updatedAt: "2026-06-01T09:00:00.000Z",
    authorName: "CurecordAI Team",
    category: {
      en: "Health Literacy",
      ur: "صحت سے متعلق آگاہی",
      "roman-ur": "Sehat Ki Samajh",
    },
  },
  {
    slug: "sharing-medical-history-with-a-new-doctor",
    title: {
      en: "Sharing Your Medical History With a New Doctor",
      ur: "اپنی میڈیکل تاریخ نئے ڈاکٹر کے ساتھ شیئر کرنا",
      "roman-ur": "Apni Medical History Naye Doctor Ke Sath Share Karna",
    },
    excerpt: {
      en: "Switching doctors or seeing a specialist for the first time? Here is how to hand over your full history in under a minute.",
      ur: "ڈاکٹر تبدیل کر رہے ہیں یا پہلی بار کسی اسپیشلسٹ کے پاس جا رہے ہیں؟ یہاں جانیں کہ ایک منٹ سے کم وقت میں اپنی مکمل تاریخ کیسے فراہم کریں۔",
      "roman-ur":
        "Doctor tabdeel kar rahe hain ya pehli dafa kisi specialist ke paas ja rahe hain? Yahan janein ke aik minute se kam waqt mein apni mukammal history kaise faraham karein.",
    },
    content: [
      {
        heading: {
          en: "Why the first visit with a new doctor is slow",
          ur: "نئے ڈاکٹر کے ساتھ پہلی وزٹ سست کیوں ہوتی ہے",
          "roman-ur": "Naye Doctor Ke Sath Pehli Visit Slow Kyun Hoti Hai",
        },
        body: {
          en: "Every new doctor visit tends to start the same way: a list of questions about past diagnoses, current medications, and allergies. If you cannot remember the exact name of a medicine or the date of a past surgery, that first appointment gets slower and less accurate.",
          ur: "ہر نئی ڈاکٹر وزٹ عام طور پر ایک ہی طرح شروع ہوتی ہے: ماضی کی تشخیص، موجودہ ادویات اور الرجیز کے بارے میں سوالات کی فہرست۔ اگر آپ کو کسی دوا کا صحیح نام یا کسی پرانی سرجری کی تاریخ یاد نہ ہو، تو یہ پہلی اپائنٹمنٹ سست اور کم درست ہو جاتی ہے۔",
          "roman-ur":
            "Har nayi doctor visit aam tor par aik hi tareeqay se shuru hoti hai: pichli diagnosis, mojooda medications aur allergies ke baray mein sawalon ki list. Agar aapko kisi dawa ka sahi naam ya kisi purani surgery ki tareekh yaad na ho, to yeh pehli appointment slow aur kam durust ho jati hai.",
        },
      },
      {
        heading: {
          en: "Share your history with a QR code or secure link",
          ur: "اپنی تاریخ QR کوڈ یا محفوظ لنک کے ذریعے شیئر کریں",
          "roman-ur": "Apni History QR Code Ya Secure Link Ke Zariye Share Karein",
        },
        body: {
          en: "A one tap sharing feature solves this directly. Instead of trying to recall your history from memory, you generate a secure link or QR code that gives the doctor immediate access to your organized records - prescriptions, lab results, and past diagnoses, exactly as you uploaded them.",
          ur: "ایک ٹیپ شیئرنگ فیچر اس مسئلے کو براہ راست حل کر دیتا ہے۔ اپنی تاریخ کو یاد سے بتانے کے بجائے، آپ ایک محفوظ لنک یا QR کوڈ بناتے ہیں جو ڈاکٹر کو آپ کے منظم ریکارڈز - نسخے، لیب نتائج اور ماضی کی تشخیص - تک فوری رسائی دیتا ہے، بالکل اسی طرح جیسے آپ نے انہیں اپ لوڈ کیا تھا۔",
          "roman-ur":
            "Aik tap sharing feature is masle ko seedha hal kar deta hai. Apni history yaad se batane ke bajaye, aap aik secure link ya QR code banate hain jo doctor ko aap ke organize records - prescriptions, lab results aur pichli diagnosis - tak foran rasai deta hai, bilkul usi tarah jaisay aapne unhein upload kiya tha.",
        },
        link: {
          href: "/how-it-works",
          label: {
            en: "See how sharing works, step by step",
            ur: "دیکھیں شیئرنگ مرحلہ وار کیسے کام کرتی ہے",
            "roman-ur": "Dekhein Sharing Marhala War Kaise Kaam Karti Hai",
          },
        },
      },
      {
        heading: {
          en: "You control what's shared, and for how long",
          ur: "کیا شیئر ہوگا اور کتنی دیر کے لیے، یہ آپ کے کنٹرول میں ہے",
          "roman-ur": "Kya Share Hoga Aur Kitni Der Ke Liye, Yeh Aap Ke Control Mein Hai",
        },
        body: {
          en: "You stay in control of what is shared. Most sharing tools, including CurecordAI's, let you choose a specific time window and revoke access whenever you want, so nothing stays accessible after your appointment ends.",
          ur: "آپ اس بات کا کنٹرول رکھتے ہیں کہ کیا شیئر کیا جائے۔ زیادہ تر شیئرنگ ٹولز، بشمول CurecordAI کے، آپ کو ایک مخصوص وقت کا انتخاب کرنے اور جب چاہیں رسائی منسوخ کرنے کی اجازت دیتے ہیں، تاکہ آپ کی اپائنٹمنٹ ختم ہونے کے بعد کچھ بھی قابل رسائی نہ رہے۔",
          "roman-ur":
            "Aap is baat ka control rakhte hain ke kya share kiya jaye. Ziyada tar sharing tools, CurecordAI samet, aapko aik khaas waqt muntakhib karne aur jab chahein access cancel karne ki ijazat dete hain, taake aap ki appointment khatam hone ke baad kuch bhi accessible na rahe.",
        },
      },
      {
        heading: {
          en: "Especially useful for people who see multiple specialists",
          ur: "خاص طور پر ان لوگوں کے لیے مفید ہے جو کئی اسپیشلسٹس سے ملتے ہیں",
          "roman-ur": "Khaas Tor Par Un Logon Ke Liye Mufeed Hai Jo Kai Specialists Se Milte Hain",
        },
        body: {
          en: "This is especially useful for elderly parents or family members who see multiple specialists, since it removes the burden of repeating a complex medical history at every single visit.",
          ur: "یہ خاص طور پر بزرگ والدین یا خاندان کے ان افراد کے لیے مفید ہے جو کئی اسپیشلسٹس سے ملتے ہیں، کیونکہ اس سے ہر وزٹ پر پیچیدہ میڈیکل تاریخ دہرانے کا بوجھ ختم ہو جاتا ہے۔",
          "roman-ur":
            "Yeh khaas tor par buzurg walidain ya family ke un afraad ke liye mufeed hai jo kai specialists se milte hain, kyunke is se har visit par pechida medical history dohrane ka bojh khatam ho jata hai.",
        },
      },
    ],
    publishedAt: "2026-06-20T09:00:00.000Z",
    updatedAt: "2026-06-20T09:00:00.000Z",
    authorName: "CurecordAI Team",
    category: {
      en: "Doctor Visits",
      ur: "ڈاکٹر وزٹس",
      "roman-ur": "Doctor Visits",
    },
  },
  {
    slug: "managing-health-records-for-aging-parents",
    title: {
      en: "Managing Health Records for Aging Parents",
      ur: "عمر رسیدہ والدین کے میڈیکل ریکارڈز کا انتظام",
      "roman-ur": "Umar Raseeda Walidain Ke Health Records Ka Intezam",
    },
    excerpt: {
      en: "Caring for a parent often means becoming their health record keeper too. Here is how to do it without the stress.",
      ur: "والدین کی دیکھ بھال کا مطلب اکثر ان کے صحت کے ریکارڈز کا نگہبان بننا بھی ہوتا ہے۔ یہاں جانیں کہ بغیر ذہنی دباؤ کے یہ کیسے کیا جائے۔",
      "roman-ur": "Walidain ki dekh bhaal ka matlab aksar unke health records ka nigehban banna bhi hota hai. Yahan janein ke bina stress ke yeh kaise kiya jaye.",
    },
    content: [
      {
        heading: {
          en: "Becoming your parent's record keeper",
          ur: "اپنے والدین کے ریکارڈز کے نگہبان بننا",
          "roman-ur": "Apne Walidain Ke Records Ka Nigehban Banna",
        },
        body: {
          en: "As parents age, adult children often take on an informal role managing appointments, medications, and paperwork. Without a shared system, this usually means a phone full of photos and a lot of guessing during emergencies.",
          ur: "جیسے جیسے والدین کی عمر بڑھتی ہے، بالغ بچے اکثر غیر رسمی طور پر اپائنٹمنٹس، ادویات اور کاغذی کارروائی کا انتظام سنبھال لیتے ہیں۔ مشترکہ نظام کے بغیر، اس کا مطلب عام طور پر تصاویر سے بھرا فون اور ایمرجنسی کے دوران بہت سا اندازہ لگانا ہوتا ہے۔",
          "roman-ur":
            "Jaise jaise walidain ki umar barhti hai, baligh bachay aksar ghair rasmi tor par appointments, medications aur paperwork ka intezam sambhal lete hain. Mushtarka nizam ke baghair, iska matlab aam tor par tasveeron se bhara phone aur emergency ke doran bohot sa andaza lagana hota hai.",
        },
      },
      {
        heading: {
          en: "One account, a separate profile per parent",
          ur: "ایک اکاؤنٹ، ہر والدین کے لیے الگ پروفائل",
          "roman-ur": "Aik Account, Har Waalid Ke Liye Alag Profile",
        },
        body: {
          en: "A family vault approach - where each parent has their own organized profile under one account - makes this manageable. You can see medication lists, upcoming refills, and past diagnoses in one place, and share that history instantly with any new doctor or hospital.",
          ur: "فیملی والٹ کا طریقہ - جہاں ہر والدین کا اپنا منظم پروفائل ایک ہی اکاؤنٹ کے تحت ہوتا ہے - اسے قابل انتظام بنا دیتا ہے۔ آپ ادویات کی فہرستیں، آنے والی ری فلز، اور ماضی کی تشخیص ایک ہی جگہ دیکھ سکتے ہیں، اور اس تاریخ کو فوری طور پر کسی بھی نئے ڈاکٹر یا ہسپتال کے ساتھ شیئر کر سکتے ہیں۔",
          "roman-ur":
            "Family vault ka tareeqa - jahan har waalid ka apna organize profile aik hi account ke tehat hota hai - isay qabil-e-intezam bana deta hai. Aap medications ki lists, aane wali refills, aur pichli diagnosis aik hi jagah dekh sakte hain, aur yeh history foran kisi bhi naye doctor ya hospital ke sath share kar sakte hain.",
        },
        link: {
          href: "/pricing",
          label: {
            en: "See family vault plan details",
            ur: "فیملی والٹ پلان کی تفصیلات دیکھیں",
            "roman-ur": "Family Vault Plan Ki Tafseelat Dekhein",
          },
        },
      },
      {
        heading: {
          en: "Why this matters in an emergency",
          ur: "ایمرجنسی میں یہ کیوں اہم ہے",
          "roman-ur": "Emergency Mein Yeh Kyun Ahem Hai",
        },
        body: {
          en: "It also matters for emergencies. Having a quick, accurate summary of allergies, current medications, and chronic conditions ready to share can make a real difference when time is limited.",
          ur: "یہ ایمرجنسی کے لیے بھی اہم ہے۔ الرجیز، موجودہ ادویات اور دائمی امراض کا فوری اور درست خلاصہ شیئر کرنے کے لیے تیار رکھنا اس وقت واقعی فرق ڈال سکتا ہے جب وقت محدود ہو۔",
          "roman-ur":
            "Yeh emergency ke liye bhi ahem hai. Allergies, mojooda medications aur chronic conditions ka fori aur durust khulasa share karne ke liye tayyar rakhna us waqt waqai farq daal sakta hai jab waqt mehdood ho.",
        },
      },
      {
        heading: {
          en: "How to get started",
          ur: "کیسے شروع کریں",
          "roman-ur": "Kaise Shuru Karein",
        },
        body: {
          en: "If you are the family member coordinating care for a parent, start by uploading their most recent prescriptions and lab reports, then build the habit of adding new documents after every visit.",
          ur: "اگر آپ خاندان کے وہ فرد ہیں جو والدین کی دیکھ بھال کا انتظام کر رہے ہیں، تو ان کے حالیہ ترین نسخے اور لیب رپورٹس اپ لوڈ کرنے سے شروع کریں، پھر ہر وزٹ کے بعد نئی دستاویزات شامل کرنے کی عادت بنائیں۔",
          "roman-ur":
            "Agar aap family ke woh fard hain jo walidain ki dekh bhaal ka intezam kar rahe hain, to unke sab se haaliya prescriptions aur lab reports upload karne se shuru karein, phir har visit ke baad nayi documents add karne ki aadat banayein.",
        },
      },
    ],
    publishedAt: "2026-07-05T09:00:00.000Z",
    updatedAt: "2026-07-05T09:00:00.000Z",
    authorName: "CurecordAI Team",
    category: {
      en: "Family Care",
      ur: "خاندانی دیکھ بھال",
      "roman-ur": "Family Care",
    },
  },
];

export function getAllPosts(): BlogPost[] {
  return [...blogPosts].sort(
    (a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime()
  );
}

export function getPostBySlug(slug: string): BlogPost | undefined {
  return blogPosts.find((post) => post.slug === slug);
}

export function getRelatedPosts(slug: string, count = 2): BlogPost[] {
  return blogPosts.filter((post) => post.slug !== slug).slice(0, count);
}

// Marketing URL locale -> BCP-47 tag used for date formatting. Roman Urdu is
// Urdu written in the Latin script, so it keeps Latin digits and English month
// names ("ur-Latn" would resolve back to Urdu-script output, which would look
// wrong next to Roman Urdu body text); only Urdu script gets "ur-PK".
const dateLocales: Record<string, string> = {
  en: "en-US",
  ur: "ur-PK",
  "roman-ur": "en-US",
};

export function formatPostDate(iso: string, locale = "en"): string {
  return new Date(iso).toLocaleDateString(dateLocales[locale] ?? "en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}
