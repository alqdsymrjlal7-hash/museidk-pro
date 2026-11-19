-- =====================================================================
-- مساعدك الرقمي للخدمات الإلكترونية | Supabase PostgreSQL
-- مخطط قاعدة البيانات الموحد: الحسابات، الخدمات، المؤسسات، الطلبات،
-- المستندات، الإشعارات، الفواتير، المدفوعات، وسجل النشاط.
-- شغّل الملف في SQL Editor داخل مشروع Supabase جديد.
-- لا تضع service_role key في الواجهة أو GitHub.
-- =====================================================================

begin;
create extension if not exists pgcrypto;

-- 1) الحسابات والأدوار --------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text unique,
  phone text,
  account_type text not null default 'individual'
    check (account_type in ('individual','business')),
  role text not null default 'customer'
    check (role in ('customer','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- يمنع المستخدم من ترقية نفسه إلى مدير بتعديل ملفه الشخصي.
create or replace function public.protect_profile_role()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role and not public.is_admin() then
    raise exception 'ليس لديك صلاحية تغيير دور الحساب';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_role_before_update on public.profiles;
create trigger protect_profile_role_before_update
before update on public.profiles
for each row execute function public.protect_profile_role();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public
as $$
declare v_type text;
begin
  v_type := case when new.raw_user_meta_data->>'account_type' = 'business'
                 then 'business' else 'individual' end;
  insert into public.profiles(id, full_name, email, phone, account_type, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    new.email,
    nullif(new.raw_user_meta_data->>'phone',''),
    v_type,
    'customer'
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = excluded.full_name,
    phone = excluded.phone,
    account_type = excluded.account_type;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- 2) الخدمات ------------------------------------------------------------
create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text not null default '',
  requirements text,
  price numeric(12,2) check (price is null or price >= 0),
  currency char(3) not null default 'SAR',
  is_active boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
drop trigger if exists services_set_updated_at on public.services;
create trigger services_set_updated_at before update on public.services
for each row execute function public.set_updated_at();

-- 3) المؤسسات والعمال/المستفيدون --------------------------------------
create table if not exists public.institutions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  registration_number text,
  activity text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists institutions_owner_idx on public.institutions(owner_id);
drop trigger if exists institutions_set_updated_at on public.institutions;
create trigger institutions_set_updated_at before update on public.institutions
for each row execute function public.set_updated_at();

create table if not exists public.beneficiaries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  institution_id uuid references public.institutions(id) on delete set null,
  full_name text not null,
  identity_number text,
  phone text,
  beneficiary_type text not null default 'beneficiary'
    check (beneficiary_type in ('worker','beneficiary','dependent','other')),
  expiry_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists beneficiaries_owner_idx on public.beneficiaries(owner_id);
create index if not exists beneficiaries_institution_idx on public.beneficiaries(institution_id);
drop trigger if exists beneficiaries_set_updated_at on public.beneficiaries;
create trigger beneficiaries_set_updated_at before update on public.beneficiaries
for each row execute function public.set_updated_at();

-- التحقق من أن المؤسسة المرتبطة تخص مالك السجل نفسه.
create or replace function public.check_owned_institution()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  if new.institution_id is not null and not exists (
    select 1 from public.institutions i
    where i.id = new.institution_id and i.owner_id = new.owner_id
  ) then
    raise exception 'المؤسسة المحددة لا تتبع هذا الحساب';
  end if;
  return new;
end;
$$;
drop trigger if exists beneficiaries_check_institution on public.beneficiaries;
create trigger beneficiaries_check_institution
before insert or update of institution_id, owner_id on public.beneficiaries
for each row execute function public.check_owned_institution();

-- 4) الطلبات والمعاملات -------------------------------------------------
create table if not exists public.service_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete cascade,
  institution_id uuid references public.institutions(id) on delete set null,
  service_id uuid references public.services(id) on delete set null,
  service_name text not null,
  entity_name text,
  details text not null,
  attachment_path text,
  status text not null default 'new'
    check (status in ('new','in_progress','waiting_client','completed','rejected')),
  admin_notes text,
  amount numeric(12,2) check (amount is null or amount >= 0),
  currency char(3) not null default 'SAR',
  due_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists requests_client_idx on public.service_requests(client_id, created_at desc);
create index if not exists requests_status_idx on public.service_requests(status, created_at desc);
create index if not exists requests_institution_idx on public.service_requests(institution_id);
drop trigger if exists requests_set_updated_at on public.service_requests;
create trigger requests_set_updated_at before update on public.service_requests
for each row execute function public.set_updated_at();

create or replace function public.check_request_institution()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  if new.institution_id is not null and not exists (
    select 1 from public.institutions i
    where i.id = new.institution_id and i.owner_id = new.client_id
  ) then
    raise exception 'المؤسسة المحددة لا تتبع صاحب الطلب';
  end if;
  return new;
end;
$$;
drop trigger if exists requests_check_institution on public.service_requests;
create trigger requests_check_institution
before insert or update of institution_id, client_id on public.service_requests
for each row execute function public.check_request_institution();

-- 5) المستندات ----------------------------------------------------------
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  institution_id uuid references public.institutions(id) on delete set null,
  request_id uuid references public.service_requests(id) on delete set null,
  file_name text not null,
  file_path text not null unique,
  document_type text not null default 'عام',
  expiry_date date,
  created_at timestamptz not null default now()
);
create index if not exists documents_owner_idx on public.documents(owner_id, created_at desc);

create or replace function public.check_document_ownership()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  if split_part(new.file_path, '/', 1) <> new.owner_id::text then
    raise exception 'مسار الملف يجب أن يكون داخل مجلد مالك المستند';
  end if;
  if new.institution_id is not null and not exists (
    select 1 from public.institutions i
    where i.id = new.institution_id and i.owner_id = new.owner_id
  ) then
    raise exception 'المؤسسة المحددة لا تتبع مالك المستند';
  end if;
  if new.request_id is not null and not exists (
    select 1 from public.service_requests r
    where r.id = new.request_id and r.client_id = new.owner_id
  ) then
    raise exception 'الطلب المحدد لا يتبع مالك المستند';
  end if;
  return new;
end;
$$;
drop trigger if exists documents_check_ownership on public.documents;
create trigger documents_check_ownership
before insert or update on public.documents
for each row execute function public.check_document_ownership();

-- 6) الإشعارات ----------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  related_request_id uuid references public.service_requests(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications(user_id, created_at desc);

-- إشعار للعميل عند إنشاء طلب أو تغيير حالته.
create or replace function public.notify_request_changes()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.notifications(user_id, title, message, related_request_id)
    values (new.client_id, 'تم استلام طلبك',
      'استلمنا طلب خدمة ' || new.service_name || ' وسيتم مراجعته.', new.id);
  elsif new.status is distinct from old.status then
    insert into public.notifications(user_id, title, message, related_request_id)
    values (new.client_id, 'تحديث حالة المعاملة',
      'تم تحديث حالة طلب ' || new.service_name || ' إلى: ' ||
      case new.status
        when 'new' then 'جديد'
        when 'in_progress' then 'قيد التنفيذ'
        when 'waiting_client' then 'بانتظار استكمال العميل'
        when 'completed' then 'مكتمل'
        when 'rejected' then 'مرفوض'
        else new.status end, new.id);
  end if;
  return new;
end;
$$;
drop trigger if exists requests_notify_changes on public.service_requests;
create trigger requests_notify_changes
after insert or update of status on public.service_requests
for each row execute function public.notify_request_changes();

-- 7) الفواتير والمدفوعات (تهيئة قاعدة البيانات؛ بوابة الدفع تحتاج مزوداً ومفاتيحاً)
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_number text not null unique,
  client_id uuid not null references public.profiles(id) on delete restrict,
  request_id uuid references public.service_requests(id) on delete set null,
  subtotal numeric(12,2) not null check (subtotal >= 0),
  tax_amount numeric(12,2) not null default 0 check (tax_amount >= 0),
  total_amount numeric(12,2) not null check (total_amount >= 0),
  currency char(3) not null default 'SAR',
  status text not null default 'unpaid'
    check (status in ('draft','unpaid','paid','cancelled','refunded')),
  issue_date date not null default current_date,
  due_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists invoices_client_idx on public.invoices(client_id, created_at desc);
drop trigger if exists invoices_set_updated_at on public.invoices;
create trigger invoices_set_updated_at before update on public.invoices
for each row execute function public.set_updated_at();

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete restrict,
  client_id uuid not null references public.profiles(id) on delete restrict,
  provider text not null default 'manual',
  provider_reference text unique,
  amount numeric(12,2) not null check (amount > 0),
  currency char(3) not null default 'SAR',
  status text not null default 'pending'
    check (status in ('pending','succeeded','failed','cancelled','refunded')),
  paid_at timestamptz,
  provider_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists payments_client_idx on public.payments(client_id, created_at desc);
create index if not exists payments_invoice_idx on public.payments(invoice_id);
drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at before update on public.payments
for each row execute function public.set_updated_at();

-- 8) سجل النشاط الإداري -------------------------------------------------
create table if not exists public.activity_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists activity_logs_created_idx on public.activity_logs(created_at desc);

-- 9) تفعيل RLS ----------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.services enable row level security;
alter table public.institutions enable row level security;
alter table public.beneficiaries enable row level security;
alter table public.service_requests enable row level security;
alter table public.documents enable row level security;
alter table public.notifications enable row level security;
alter table public.invoices enable row level security;
alter table public.payments enable row level security;
alter table public.activity_logs enable row level security;

-- إزالة السياسات المعرفة بهذا الملف لإتاحة إعادة تشغيله على نفس المخطط.
do $$ declare p record; begin
  for p in select schemaname, tablename, policyname
           from pg_policies where schemaname = 'public'
             and tablename in ('profiles','services','institutions','beneficiaries',
               'service_requests','documents','notifications','invoices','payments','activity_logs')
  loop execute format('drop policy if exists %I on %I.%I', p.policyname, p.schemaname, p.tablename); end loop;
end $$;

-- الحسابات: العميل يرى ويحدث ملفه، ولا يغير دوره. المدير يدير الحسابات.
create policy profiles_select_own_admin on public.profiles
for select to authenticated using (id = (select auth.uid()) or public.is_admin());
create policy profiles_update_own_admin on public.profiles
for update to authenticated
using (id = (select auth.uid()) or public.is_admin())
with check (id = (select auth.uid()) or public.is_admin());

-- الخدمات متاحة للزوار إذا كانت نشطة، والإدارة الكاملة للمدير.
create policy services_public_read on public.services
for select to anon, authenticated using (is_active = true or public.is_admin());
create policy services_admin_all on public.services
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- بيانات المؤسسات والمستفيدين محصورة بمالك الحساب أو المدير.
create policy institutions_owner_admin on public.institutions
for all to authenticated
using (owner_id = (select auth.uid()) or public.is_admin())
with check (owner_id = (select auth.uid()) or public.is_admin());
create policy beneficiaries_owner_admin on public.beneficiaries
for all to authenticated
using (owner_id = (select auth.uid()) or public.is_admin())
with check (owner_id = (select auth.uid()) or public.is_admin());

-- العميل ينشئ طلبه ويقرأ طلباته فقط؛ تعديل الحالات للمدير.
create policy requests_client_read on public.service_requests
for select to authenticated using (client_id = (select auth.uid()) or public.is_admin());
create policy requests_client_insert on public.service_requests
for insert to authenticated with check (client_id = (select auth.uid()));
create policy requests_admin_update_delete on public.service_requests
for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy documents_owner_admin on public.documents
for all to authenticated
using (owner_id = (select auth.uid()) or public.is_admin())
with check (owner_id = (select auth.uid()) or public.is_admin());

create policy notifications_owner_admin on public.notifications
for select to authenticated using (user_id = (select auth.uid()) or public.is_admin());
create policy notifications_mark_read on public.notifications
for update to authenticated using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
create policy notifications_admin_all on public.notifications
for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy invoices_client_read_admin_all on public.invoices
for select to authenticated using (client_id = (select auth.uid()) or public.is_admin());
create policy invoices_admin_manage on public.invoices
for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy payments_client_read_admin_all on public.payments
for select to authenticated using (client_id = (select auth.uid()) or public.is_admin());
create policy payments_admin_manage on public.payments
for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy activity_logs_admin_only on public.activity_logs
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- 10) مساحة تخزين خاصة للمستندات ---------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('client-documents','client-documents',false,5242880,
  array['application/pdf','image/png','image/jpeg'])
on conflict (id) do update set
  public = false,
  file_size_limit = 5242880,
  allowed_mime_types = array['application/pdf','image/png','image/jpeg'];

drop policy if exists client_documents_upload_own on storage.objects;
drop policy if exists client_documents_read_own on storage.objects;
drop policy if exists client_documents_update_own on storage.objects;
drop policy if exists client_documents_delete_own on storage.objects;
drop policy if exists client_documents_admin_all on storage.objects;
create policy client_documents_upload_own on storage.objects
for insert to authenticated with check (
  bucket_id = 'client-documents' and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy client_documents_read_own on storage.objects
for select to authenticated using (
  bucket_id = 'client-documents' and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy client_documents_update_own on storage.objects
for update to authenticated
using (bucket_id = 'client-documents' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'client-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy client_documents_delete_own on storage.objects
for delete to authenticated using (
  bucket_id = 'client-documents' and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy client_documents_admin_all on storage.objects
for all to authenticated using (bucket_id = 'client-documents' and public.is_admin())
with check (bucket_id = 'client-documents' and public.is_admin());

-- 11) بيانات الخدمات الافتراضية ----------------------------------------
insert into public.services(name, description, requirements, sort_order) values
('الخدمات الحكومية العامة','استقبال ومتابعة الطلبات الحكومية الإلكترونية.','تختلف المتطلبات حسب الخدمة',1),
('أبشر','خدمات الأفراد والأعمال المرتبطة بمنصة أبشر.','بيانات الخدمة المطلوبة',2),
('مقيم','خدمات المنشآت ومتابعة معاملات المقيمين.','بيانات المنشأة والمستفيد',3),
('مكتب العمل','خدمات المنشآت والعمالة وإجراءات مكتب العمل.','بيانات المنشأة والعامل',4),
('التأمينات الاجتماعية','متابعة خدمات الاشتراك والمنشآت والتأمينات.','بيانات المنشأة',5),
('الجوازات','متابعة خدمات الجوازات والإجراءات ذات الصلة.','بيانات المستفيد',6),
('التعقيب الإلكتروني','متابعة الطلبات والمعاملات وإبلاغ العميل بالتحديثات.','تفاصيل المعاملة',7),
('الشركات والمؤسسات','تنظيم خدمات المنشآت وبيانات العمال والمستفيدين.','بيانات المنشأة',8),
('الطباعة والتصميم','خدمات الطباعة والتنسيق والتصميم حسب الطلب.','إرفاق الملف أو وصف المطلوب',9)
on conflict (name) do update set
  description = excluded.description,
  requirements = excluded.requirements,
  sort_order = excluded.sort_order;

commit;

-- =====================================================================
-- ترقية حسابك إلى مدير (نفّذ بعد التسجيل وتأكيد البريد):
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'بريدك@example.com';
-- لا تسمح للمستخدمين باختيار admin من نموذج التسجيل.
-- =====================================================================
