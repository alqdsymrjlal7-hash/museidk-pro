 "use client";
import Link from "next/link";
import Image from "next/image";
import { useEffect, useState } from "react";
import { Menu, X, LayoutDashboard, LogIn } from "lucide-react";
import { supabase } from "@/lib/supabase";

const links = [
  ["الرئيسية", "/"], ["الخدمات", "/services"], ["عن المكتب", "/about"], ["تواصل معنا", "/contact"]
];

export default function Header() {
  const [open, setOpen] = useState(false);
  const [user, setUser] = useState<string | null>(null);
  useEffect(() => {
    if (!supabase) return;
    supabase.auth.getUser().then(({ data }) => setUser(data.user?.email ?? null));
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => setUser(session?.user?.email ?? null));
    return () => listener.subscription.unsubscribe();
  }, []);
  return <header className="site-header">
    <div className="container nav-wrap">
      <Link href="/" className="brand" onClick={() => setOpen(false)}>
        <Image src="/images/logo.png" alt="شعار مساعدك الرقمي" width={54} height={54} priority />
        <span><b>مساعدك الرقمي</b><small>للخدمات الإلكترونية</small></span>
      </Link>
      <button className="menu-toggle" onClick={() => setOpen(!open)} aria-label="القائمة">{open ? <X/> : <Menu/>}</button>
      <nav className={open ? "nav-links show" : "nav-links"}>
        {links.map(([label, href]) => <Link key={href} href={href} onClick={() => setOpen(false)}>{label}</Link>)}
        {user ? <Link className="nav-cta" href="/client"><LayoutDashboard size={17}/> حسابي</Link> : <Link className="nav-cta" href="/login"><LogIn size={17}/> دخول / تسجيل</Link>}
      </nav>
    </div>
  </header>;
}