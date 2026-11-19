import Link from "next/link";
import { ArrowLeft, ShieldCheck, FileText, Building2, Bell, Users, Clock3 } from "lucide-react";
const services = [
 ["الخدمات الحكومية","متابعة وإنجاز الخدمات الحكومية الإلكترونية.",ShieldCheck],
 ["أبشر ومقيم","خدمات الأفراد والمنشآت ومتابعة الطلبات.",Users],
 ["مكتب العمل والتأمينات","خدمات المنشآت والموظفين والتأمينات الاجتماعية.",Building2],
 ["الجوازات","متابعة خدمات الجوازات والإجراءات المرتبطة بها.",FileText],
 ["التعقيب الإلكتروني","متابعة المعاملات وتحديث حالتها باستمرار.",Clock3],
 ["الطباعة والتصميم","خدمات الطباعة والتنسيق والتصميم.",Bell]
];
export default function Home() {
 return <>
  <section className="hero"><div className="container hero-grid"><div><span className="eyebrow">خدماتك في مكان واحد</span><h1>مساعدك الرقمي<br/>لإنجاز خدماتك بسهولة</h1><p>منصة منظمة لاستقبال طلباتك، ومتابعة معاملاتك، وإدارة مستنداتك ومواعيد التجديد من مكان واحد، بخطوات واضحة وتجربة سهلة.</p><div className="hero-actions"><Link className="btn-primary" href="/request">اطلب خدمتك الآن <ArrowLeft size={18}/></Link><Link className="btn-secondary" href="/services">اكتشف الخدمات</Link></div></div><div className="hero-art"><div className="art-mark">مساعدك<br/>الرقمي</div><div className="art-caption"><b>خدمات إلكترونية أكثر سهولة</b><p>متابعة • تنظيم • إنجاز</p></div></div></div></section>
  <div className="container stats"><div className="stat"><b>24/5</b><span>استقبال الطلبات طوال أيام العمل</span></div><div className="stat"><b>مكان واحد</b><span>للمعاملات والمستندات</span></div><div className="stat"><b>متابعة</b><span>لمعرفة حالة طلبك</span></div></div>
  <section className="section"><div className="container"><div className="section-title"><span className="eyebrow">خدماتنا</span><h2>خدمات متنوعة تلبي احتياجك</h2><p>اختر الخدمة المناسبة، واطلع على متطلباتها، ثم أرسل طلبك لمتابعته.</p></div><div className="cards">{services.map(([name,desc,Icon])=>{const I=Icon as any;return <article className="card" key={name as string}><div className="card-icon"><I size={23}/></div><h3>{name as string}</h3><p>{desc as string}</p><Link className="text-link" href="/services">تفاصيل الخدمات ←</Link></article>})}</div></div></section>
  <section className="section"><div className="container"><div className="cta-band"><div><h2>هل ترغب في إنجاز معاملة؟</h2><p>ابدأ طلبك إلكترونياً وتابع مستجداته من حسابك.</p></div><Link className="btn-secondary" href="/request">ابدأ طلب الخدمة <ArrowLeft size={17}/></Link></div></div></section>
 </>;
}