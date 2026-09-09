# APP 升级检测接口说明

本文档面向 **GRB Link 客户端** 与运维，说明如何用独立清单检测 App 版本并引导用户升级。  
**本接口与固件 OTA 的 `/api/version.json` 完全分开，互不解析、互不影响。**

---

## 1. 基本信息

| 项目 | 说明 |
|------|------|
| 服务根地址 | `https://grb.asia` |
| 清单地址 | `GET https://grb.asia/api/app-version.json` |
| 协议 | HTTPS |
| 数据格式 | JSON（`Content-Type: application/json; charset=utf-8`） |
| 缓存 | 服务器建议 `Cache-Control: no-cache`；客户端请求同样带 `Cache-Control: no-cache` |

**分发约定：**

- **Android**：`android_download_url` 指向外部分发网站（下载页/首页），由用户在网页完成安装。App **不**下载或安装 APK。
- **iOS**：`ios_store_url` 指向 App Store 产品页。App **不**安装 IPA。

示例文件见同目录 [`app_version.example.json`](app_version.example.json)，部署时作为 `https://grb.asia/api/app-version.json` 并填入真实链接。

---

## 2. 调用流程

```
┌─────────────┐     GET /api/app-version.json      ┌──────────────┐
│  GRB Link   │ ─────────────────────────────────► │  升级服务器   │
└─────────────┘                                    └──────────────┘
       │
       │  semver 比较本地 version vs latest / min_supported
       │  强制 → 不可关闭弹窗；软提醒 → 可稍后（记住 skipped 版本）
       │  立即升级：Android 打开外部分发网站；iOS 打开 App Store
       ▼
```

启动后首页做一次检测（失败则放行，下次再查）。关于页可手动「检查更新」。

---

## 3. 字段说明

```json
{
  "latest_version": "1.0.3",
  "min_supported_version": "1.0.2",
  "force": false,
  "release_notes_zh": "修复蓝牙断连；新增升级检测",
  "release_notes_en": "Fix BLE disconnect; add app update check",
  "android_download_url": "https://example.com/grb-link/",
  "ios_store_url": "https://apps.apple.com/app/idXXXXXXXX"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `latest_version` | string | 当前最新 App 版本，与 `pubspec.yaml` 的 version 名称部分对齐（不含 `+build`） |
| `min_supported_version` | string | 最低可继续使用的版本；低于此版本一律强制升级 |
| `force` | bool | 为 `true` 时，凡低于 `latest_version` 的用户一律强制 |
| `release_notes_zh` / `release_notes_en` | string | 弹窗更新说明，按 App 语言选用 |
| `android_download_url` | string | Android 外部分发网站，**不是** APK 直链 |
| `ios_store_url` | string | iOS App Store 产品页 |

版本比较规则：按 `.` 分段做数字比较（`1.0.10 > 1.0.2`）。忽略 `+build` 与 `-pre` 后缀。

判定：

1. 本地 `< min_supported_version` → **强制**
2. 本地 `< latest_version` 且 `force == true` → **强制**
3. 本地 `< latest_version` → **软提醒**（可「稍后」，同一 `latest_version` 启动时不再弹；手动检查仍会提示）
4. 否则 → 已是最新

网络失败默认 **放行**（fail-open），避免无网用户进不了 App。

---

## 4. 运维与发布节奏

尚未包含检测逻辑的旧包无法被强制拦住。按下面顺序铺开：

1. **种子包**：发布含升级检测的 App（如 `1.0.3`）。清单先写：
   - `latest_version`: `1.0.3`
   - `min_supported_version`: `1.0.2`
   - `force`: `false`
2. **核对链接**：确认 Android 网站可打开、iOS App Store 产品页可用后再对外宣传升级。
3. **功能版**：发新版本时只上调 `latest_version`（及更新说明、链接）。此时旧种子包会收到软提醒。
4. **清场**：确认多数用户已升级后，再上调 `min_supported_version`，或把 `force` 设为 `true`。不要在商店/网站包尚未可装时强制。

发版检查清单：

- [ ] 已上传/提交对应平台安装包
- [ ] 已把 `android_download_url` / `ios_store_url` 改成可访问的真实地址
- [ ] 已更新 `latest_version` 与更新说明
- [ ] `force` 在验证完成前保持 `false`
- [ ] 需要拦旧版时才改 `min_supported_version` 或 `force`
