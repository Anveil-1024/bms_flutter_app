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

- **Android**：`android_download_url` 指向外部分发网站（下载页/首页），由用户在网页完成安装。App **不**下载或安装 APK。使用蒲公英分发时填下载页短链 `https://www.pgyer.com/<短链接>` 即可。
- **iOS**：`ios_store_url` 指向 App Store 产品页。App **不**安装 IPA。若要蒲公英内测包点更新直接弹安装，填写 `ios_build_key`（见下方「蒲公英内测安装」）。

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
       │  立即升级：Android 打开蒲公英下载页；iOS 配了 buildKey 则弹内测安装，否则打开 App Store
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
  "android_download_url": "https://www.pgyer.com/abcd",
  "ios_store_url": "https://apps.apple.com/app/idXXXXXXXX",
  "ios_build_key": "",
  "install_password": ""
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `latest_version` | string | 当前最新 App 版本，与 `pubspec.yaml` 的 version 名称部分对齐（不含 `+build`） |
| `min_supported_version` | string | 最低可继续使用的版本；低于此版本一律强制升级 |
| `force` | bool | 为 `true` 时，凡低于 `latest_version` 的用户一律强制 |
| `release_notes_zh` / `release_notes_en` | string | 弹窗更新说明，按 App 语言选用 |
| `android_download_url` | string | Android 外部分发网站，**不是** APK 直链；用蒲公英时填 `https://www.pgyer.com/<短链接>` |
| `ios_store_url` | string | iOS App Store 产品页 |
| `ios_build_key` | string | 可选。蒲公英 `buildKey`，填写后 iOS 点「立即更新」直接弹系统安装；留空则走 `ios_store_url` |
| `install_password` | string | 可选。蒲公英密码安装时的安装密码，仅 `ios_build_key` 生效时使用 |

版本比较规则：按 `.` 分段做数字比较（`1.0.10 > 1.0.2`）。忽略 `+build` 与 `-pre` 后缀。

判定：

1. 本地 `< min_supported_version` → **强制**
2. 本地 `< latest_version` 且 `force == true` → **强制**
3. 本地 `< latest_version` → **软提醒**（可「稍后」，同一 `latest_version` 启动时不再弹；手动检查仍会提示）
4. 否则 → 已是最新

网络失败默认 **放行**（fail-open），避免无网用户进不了 App。

### 蒲公英内测安装

`ios_build_key` 非空时，iOS 点「立即更新」会打开：

```
itms-services://?action=download-manifest&url=https%3A%2F%2Fwww.pgyer.com%2Fapp%2Fplist%2F<buildKey>
```

系统直接弹安装确认，不再跳浏览器。`install_password` 非空时会在 plist 地址后追加 `?password=`。

注意：

- 仅适用于蒲公英内测/企业签名包；App Store 包请留空 `ios_build_key`，否则会安装失败。
- **不要**在清单里配置带 `_api_key` 的 `/apiv2/app/install` 链接，API Key 会随清单下发到所有客户端。Android 直接用下载页短链。
- `buildKey` 可在蒲公英后台该版本的详情/API 返回中获取，每次发版都会变化，上线新版本时要同步更新。

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
