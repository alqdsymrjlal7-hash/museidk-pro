 "use client";
import {useRouter} from "next/navigation";import {supabase} from "@/lib/supabase";
export default function SignOutButton(){const router=useRouter();async function out(){if(supabase)await supabase.auth.signOut();router.push("/");}return <button className="btn-outline" onClick={out}>تسجيل الخروج</button>}