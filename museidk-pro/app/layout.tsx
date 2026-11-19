import type { Metadata } from "next";
import "./globals.css";
import Shell from "@/components/Shell";
export const metadata: Metadata = {
  title: "مساعدك الرقمي | للخدمات الإلكترونية",
  description: "مكتب مساعدك الرقمي للخدمات الإلكترونية ومتابعة المعاملات",
};
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="ar" dir="rtl"><body><Shell>{children}</Shell></body></html>;
}