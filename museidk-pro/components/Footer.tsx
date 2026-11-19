import Link from "next/link";
import { Mail, MapPin, MessageCircle } from "lucide-react";
export default function Footer() {
  return <footer className="footer"><div className="container footer-grid">
    <div><div className="footer-brand">مساعدك الرقمي للخدمات الإلكترونية</div><p>نساعدك على إنجاز خدماتك الإلكترونية ومتابعة معاملاتك في مكان واحد.</p></div>
    <div><h3>روابط سريعة</h3><Link href="/services">الخدمات</Link><Link href="/about">عن المكتب</Link><Link href="/contact">تواصل معنا</Link><Link href="/request">طلب خدمة</Link></div>
    <div><h3>تواصل معنا</h3><a href="mailto:info@museidk.com"><Mail size={16}/> info@museidk.com</a><a href="https://wa.me/c/966535717061" target="_blank" rel="noreferrer"><MessageCircle size={16}/> واتساب</a><span><MapPin size={16}/> السعودية، مكة المكرمة، المظيلف، دوقة</span></div>
  </div><div className="copyright">© {new Date().getFullYear()} مساعدك الرقمي. جميع الحقوق محفوظة.</div></footer>;
}