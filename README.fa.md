# paqet-tunnel (راهنمای فارسی)

[English](README.md) | [فارسی](README.fa.md) | [Changelog](CHANGELOG.md)

ابزار نصب و مدیریت ساده برای تونل‌کردن ترافیک VPN از طریق یک سرور واسط با استفاده از [paqet](https://github.com/hanselime/paqet) (تونل در سطح raw packet برای عبور بهتر از محدودیت‌های شبکه).

## این نسخه چه چیزهایی دارد؟

- راه‌اندازی تعاملی برای **Server A (ایران)** و **Server B (خارج)**
- پشتیبانی از **چند تونل** روی Server A
- منوی مدیریت، تست اتصال، ویرایش تنظیمات و ریست خودکار
- **بهینه‌سازی خودکار KCP به سبک PaqX** بر اساس CPU و RAM (برای نصب‌های جدید)
- **بهینه‌سازی کرنل** (BBR / TCP Fast Open / socket buffers) با فایل جداگانه در `/etc/sysctl.d/99-paqet-tunnel.conf`
- **آپدیت هسته paqet** از ریلیزهای `hanselime/paqet`
- **اعمال مجدد Auto-Tune روی کانفیگ‌های موجود** بدون ساخت دوباره تونل
- **نمایش Read-only پروفایل خودکار** (فقط نمایش، بدون تغییر)

## سناریو استفاده

این ابزار برای سناریویی طراحی شده که:

- **Server A** داخل ایران است (نقطه ورود کاربران)
- **Server B** خارج از ایران است (سرور VPN / X-UI / V2Ray)
- ترافیک کاربران به Server A وصل می‌شود و از طریق `paqet` به Server B تونل می‌شود

## نصب سریع

روی هر دو سرور (با دسترسی root):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Recoba86/paqet-tunnel/main/install.sh)
```

## مراحل راه‌اندازی

### 1) راه‌اندازی Server B (خارج)

1. اجرای اسکریپت
2. انتخاب گزینه `1` (Setup Server B)
3. تایید/ویرایش تنظیمات شبکه (interface / local IP / gateway MAC)
4. تعیین پورت `paqet` (پیش‌فرض: `8888`)
5. وارد کردن پورت(های) ورودی V2Ray/X-UI (مثل `443`)
6. ذخیره **Secret Key** تولیدشده

نکته:
- در این مرحله، اسکریپت به‌صورت خودکار **پروفایل KCP مناسب CPU/RAM** را حساب می‌کند.
- بهینه‌سازی sysctl کرنل هم اعمال می‌شود.

### 2) راه‌اندازی Server A (ایران)

1. اجرای اسکریپت
2. انتخاب گزینه `2` (Setup Server A)
3. (اختیاری) اجرای Iran Network Optimization
4. تعیین نام تونل (مثلا `usa` یا `germany`)
5. وارد کردن IP سرور B
6. وارد کردن پورت `paqet` سرور B
7. وارد کردن Secret Key
8. تعیین پورت(های) فوروارد (همان پورت‌های V2Ray)

نکته:
- روی Server A هم پروفایل KCP و بهینه‌سازی کرنل به‌صورت خودکار اعمال می‌شود.

## منوی اصلی (خلاصه)

```text
── Setup ──
1) Setup Server B (Abroad - VPN server)
2) Setup Server A (Iran - entry point)

── Management ──
3) Check Status
4) View Configuration
5) Edit Configuration
6) Manage Tunnels (add/remove/restart)
7) Test Connection

── Maintenance ──
8) Updates (installer + core)
k) Apply Auto KCP Tuning (existing configs)
p) View Current Auto Profile
9) Show Port Defaults
a) Automatic Reset (scheduled restart)
d) Connection Protection & MTU Tuning (fix fake RST/disconnects)
f) IPTables Port Forwarding (relay/NAT)
u) Uninstall paqet
```

## بخش Updates (گزینه 8)

زیرمنوی آپدیت شامل دو بخش است:

- **1) Check/Update Installer Script**
  - آپدیت خود اسکریپت `paqet-tunnel`
- **2) Update paqet Core (binary)**
  - آپدیت باینری `paqet` از ریلیزهای رسمی `hanselime/paqet`
  - قبل از جایگزینی، از باینری فعلی بکاپ می‌گیرد
  - سرویس‌های مرتبط را بعد از آپدیت ری‌استارت می‌کند

## Auto-Tune روی کانفیگ‌های موجود (گزینه k)

اگر قبلا تونل‌ها را ساخته‌اید و می‌خواهید بدون ساخت مجدد، تنظیمات جدید Auto-Tune را اعمال کنید:

- گزینه `k` را اجرا کنید
- اسکریپت CPU/RAM سرور فعلی را می‌خواند
- مقادیر KCP (`conn`, `mtu`, `rcvwnd`, `sndwnd`, و سایر تنظیمات) را آپدیت می‌کند
- از هر فایل کانفیگ بکاپ می‌گیرد (`*.autotune.bak.<timestamp>`)
- در انتها می‌تواند سرویس‌ها را ری‌استارت کند

## View Current Auto Profile (گزینه p)

این گزینه فقط نمایش می‌دهد:

- تعداد هسته CPU
- مقدار RAM
- پروفایل محاسبه‌شده KCP (مثل `conn`, `mtu`, `rcvwnd`, `sndwnd`)

هیچ تغییری در کانفیگ یا سرویس ایجاد نمی‌کند.

## پیش‌فرض‌های مهم

- **Default KCP MTU = `1300`**
- اگر شبکه محدودتر باشد، می‌توانید از منوی `d` یا تنظیمات دستی، MTU را به `1280` کاهش دهید.

## نکات مهم برای V2Ray/X-UI روی Server B

Inbound باید روی `0.0.0.0` گوش کند (نه فقط public IP).

در X-UI:

1. Inbounds → Edit
2. Listen IP = `0.0.0.0`
3. Save / Restart

## عیب‌یابی سریع

- **Timeout / عدم اتصال**
  - تطابق Secret Key در هر دو سمت را چک کنید
  - فایروال ابری و `iptables` را بررسی کنید
  - از گزینه `7` (Test Connection) استفاده کنید

- **کندی سرعت**
  - از گزینه `k` برای اعمال مجدد Auto-Tune استفاده کنید
  - `conn` را در تنظیمات KCP بیشتر کنید (مثلا 4 یا 8)
  - MTU را بین `1280` تا `1300` تست کنید

- **دانلود در ایران بلوک است**
  - از Iran Optimization استفاده کنید
  - فایل ریلیز `paqet` را دستی دانلود و مسیرش را به اسکریپت بدهید

## فایل‌های مهم

- کانفیگ سرور B: `/opt/paqet/config.yaml`
- کانفیگ تونل‌های سرور A: `/opt/paqet/config-<name>.yaml`
- باینری `paqet`: `/opt/paqet/paqet`
- فایل بهینه‌سازی کرنل: `/etc/sysctl.d/99-paqet-tunnel.conf`

## لایسنس

MIT

## Credits

- [paqet](https://github.com/hanselime/paqet) by hanselime
- [paqet-tunnel](https://github.com/g3ntrix/paqet-tunnel) by g3ntrix (base project)
