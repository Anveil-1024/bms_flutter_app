# 蓝牙 APP 固件升级接口说明

本文档面向 **蓝牙 APP 客户端** 开发，说明如何从升级服务器查询版本、下载固件并完成 OTA 校验。  
管理端上传、删除等写操作接口仅作附录，APP **一般无需调用**。

---

## 1. 基本信息

| 项目 | 说明 |
|------|------|
| 服务根地址 | `http://39.96.159.115`（以服务器 `config.json` 中 `base_url` 为准） |
| 协议 | HTTP（当前未配置 HTTPS） |
| 数据格式 | JSON（`Content-Type: application/json; charset=utf-8`） |
| 跨域 | 已配置 `Access-Control-Allow-Origin: *`，WebView / 部分跨域场景可用 |
| 固件格式 | `.bin` 二进制文件 |

**约定：**

- **产品线 ID（`product_id`）**：一种互不相容的固件序列，如 `7240_Public`、`9645`。APP 必须根据设备实际型号/程序分支选定唯一 ID，**不可混刷**其他产品线的包。
- **版本号（`version`）**：字符串，通常为数字（如 `1011`）。服务器按数值比较取「最新版」（非纯数字版本按字符串排序兜底）。
- **文件名规则**：`{product_id}_{version}.bin`，例如 `7240_Public_1011.bin`。

---

## 2. APP 推荐调用流程

```
┌─────────────┐     ① GET /api/version.json      ┌──────────────┐
│  蓝牙 APP   │ ────────────────────────────────► │  升级服务器   │
└─────────────┘                                   └──────────────┘
       │                                                    │
       │  解析 battery_update[product_id]                   │
       │  比较本地版本 vs latest_version                     │
       │                                                    │
       │  ② 若有新版本：GET latest_download_url              │
       │ ───────────────────────────────────────────────────►│
       │                                                    │
       │  ③ 校验 sha256、size                               │
       │  ④ 经蓝牙将固件写入设备                            │
       ▼                                                    ▼
```

### 2.1 确定本机 `product_id`

APP 需在本地维护 **设备型号 / 硬件 ID → product_id** 映射表，例如：

| 设备识别方式 | 映射示例 |
|--------------|----------|
| 蓝牙广播 / GATT 读型号 | `7240` → `7240_Public` |
| 用户手动选择电池型号 | 用户选「7240 公版」→ `7240_Public` |
| 同硬件不同程序 | 再读「程序类型」字段 → `7240_Public` 或 `7240_legacy` |

服务器 **不会** 根据蓝牙信息自动匹配产品线，由 APP 决定查询哪个 key。

### 2.2 拉取版本清单

**推荐接口（静态 JSON，由 Nginx 直接提供）：**

```http
GET /api/version.json
```

等价动态接口（内容与静态文件一致，经 Flask）：

```http
GET /upload-api/version
GET /upload-api/versions
```

**建议：** 优先使用 `/api/version.json`，并带查询参数或请求头避免缓存（服务器已设 `Cache-Control: no-cache`，客户端仍建议每次 OTA 检查重新请求）。

### 2.3 判断是否需要升级

1. 从 JSON 中取 `battery_update[product_id]`。
2. 若该 key 不存在或 `latest_version` 为 `null`，表示该产品线暂无固件。
3. 将设备当前固件版本（字符串）与 `latest_version` 比较：
   - 版本均为纯数字时，建议按 **整数** 比较（如 `1011` > `1010`）。
   - 含非数字字符时，按字符串或与设备侧约定规则比较。
4. 若本地版本 **小于** `latest_version`，则需要升级。

### 2.4 下载固件

使用清单中的 **`latest_download_url`**（最新版完整 URL），或从 `files` 数组中取指定版本的 `download_url`。

```http
GET /downloads/{product_id}/{product_id}_{version}.bin
```

示例：

```http
GET http://39.96.159.115/downloads/7240_Public/7240_Public_1011.bin
```

响应为二进制流；`Content-Disposition: attachment`。APP 应使用 **流式下载** 并校验大小。

### 2.5 完整性校验（必须）

下载完成后，对文件做 **SHA-256**，与清单中对应文件的 `sha256` 字段比对（十六进制小写）。

```text
sha256(文件内容) == entry.sha256
```

同时校验 `size`（字节数）与本地文件长度一致。

### 2.6 可选：获取产品线列表

用于设置页展示可选型号、或动态拉取服务器已注册产品线：

```http
GET /api/products.json
```

或：

```http
GET /upload-api/api/products
```

---

## 3. 核心数据结构

### 3.1 版本清单 `GET /api/version.json`

**响应示例：**

```json
{
  "base_url": "http://39.96.159.115",
  "manifest_url": "http://39.96.159.115/api/version.json",
  "products_url": "http://39.96.159.115/api/products.json",
  "updated_at": "2026-06-01T08:01:53Z",
  "battery_update": {
    "7240_Public": {
      "product_id": "7240_Public",
      "name": "7240公版",
      "description": "",
      "version": ["1011"],
      "latest_version": "1011",
      "download_url": "http://39.96.159.115/downloads/7240_Public/",
      "latest_download_url": "http://39.96.159.115/downloads/7240_Public/7240_Public_1011.bin",
      "files": [
        {
          "version": "1011",
          "filename": "7240_Public_1011.bin",
          "size": 65936,
          "sha256": "d6b09487aadf5d894afa82e7bf4938323d364b347c13e8479289659b81689473",
          "download_url": "http://39.96.159.115/downloads/7240_Public/7240_Public_1011.bin",
          "updated_at": "2026-06-01T08:01:53Z"
        }
      ]
    }
  }
}
```

**顶层字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `base_url` | string | 服务根 URL |
| `manifest_url` | string | 本清单地址 |
| `products_url` | string | 产品线注册表地址 |
| `updated_at` | string | 清单更新时间（UTC，ISO 8601，`Z` 结尾） |
| `battery_update` | object | 以 `product_id` 为 key 的固件信息集合 |

**`battery_update[product_id]` 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `product_id` | string | 产品线 ID，与 key 相同 |
| `name` | string | 显示名称 |
| `description` | string | 说明（可为空） |
| `version` | string[] | 该产品线下所有版本号列表（升序） |
| `latest_version` | string \| null | 最新版本号；无文件时为 `null` |
| `download_url` | string | 该产品线固件目录 URL（以 `/` 结尾） |
| `latest_download_url` | string \| null | **最新固件直接下载地址（APP 优先使用）** |
| `files` | array | 所有历史版本详情 |

**`files[]` 单项：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `version` | string | 版本号 |
| `filename` | string | 文件名 |
| `size` | number | 文件大小（字节） |
| `sha256` | string | SHA-256 十六进制摘要（小写） |
| `download_url` | string | 该版本下载 URL |
| `updated_at` | string | 文件更新时间（UTC） |

---

### 3.2 产品线注册表 `GET /api/products.json`

**响应示例：**

```json
{
  "products": [
    {
      "id": "7240_Public",
      "name": "7240公版",
      "description": ""
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `products` | array | 已注册产品线列表 |
| `products[].id` | string | 产品线 ID，与 `battery_update` 的 key 对应 |
| `products[].name` | string | 显示名称 |
| `products[].description` | string | 说明 |

**说明：** 注册表中存在但尚未上传固件的产品线，会出现在 `products.json` 中，但 `battery_update[id].latest_version` 可能为 `null`、`files` 为空数组。

---

## 4. APP 侧接口一览

| 用途 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 版本检查 | GET | `/api/version.json` | **主接口**，获取各产品线最新版与下载信息 |
| 产品线列表 | GET | `/api/products.json` | 可选，设置页展示型号 |
| 固件下载 | GET | `/downloads/{product_id}/{filename}` | 二进制下载 |
| 健康检查 | GET | `/upload-api/health` | 返回 `{"status":"ok"}`，可用于网络探测 |
| 版本清单（动态） | GET | `/upload-api/version` | 与静态 `version.json` 相同 |

**APP 通常不需要：** `/upload-api/upload`、`/upload-api/api/files/*`、`/upload-api/api/products` 的 POST/PATCH/DELETE（管理后台使用）。

---

## 5. 示例代码

### 5.1 检查更新（伪代码）

```text
product_id = 从设备或配置取得，例如 "7240_Public"
local_version = 从设备读取，例如 "1010"

manifest = HTTP_GET(base_url + "/api/version.json")
block = manifest.battery_update[product_id]
if block is null or block.latest_version is null:
    提示「暂无可用固件」
    return

if int(block.latest_version) <= int(local_version):
    提示「已是最新版本」
    return

// 取最新文件元数据
file = block.files 中 version == block.latest_version 的那一项
download_url = block.latest_download_url
expected_size = file.size
expected_sha256 = file.sha256

bin = HTTP_GET(download_url)   // 二进制
assert len(bin) == expected_size
assert SHA256(bin) == expected_sha256

// 通过蓝牙协议写入设备...
```

### 5.2 Android（Kotlin）拉取清单示例

```kotlin
val client = OkHttpClient()
val request = Request.Builder()
    .url("http://39.96.159.115/api/version.json")
    .get()
    .build()
client.newCall(request).execute().use { resp ->
    val json = JSONObject(resp.body!!.string())
    val block = json.getJSONObject("battery_update").getJSONObject("7240_Public")
    val latest = block.getString("latest_version")
    val url = block.getString("latest_download_url")
    // ...
}
```

### 5.3 iOS（Swift）SHA256 校验示例

```swift
import CryptoKit

func sha256Hex(data: Data) -> String {
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02x", $0) }.joined()
}
// sha256Hex(data: firmwareData) == expectedSha256FromJson
```

---

## 6. 错误与边界情况

| 场景 | HTTP / 表现 | APP 建议处理 |
|------|-------------|--------------|
| 网络不可达 | 连接超时 / 失败 | 提示检查网络，支持重试 |
| `product_id` 在清单中不存在 | 200，但无对应 key | 提示「不支持的设备型号」，勿升级 |
| `latest_version` 为 `null` | 200，`files` 为空 | 提示「服务器暂无固件」 |
| 下载 404 | 404 | 提示联系管理员重新上传固件 |
| `sha256` 不一致 | — | **中止升级**，勿写入设备 |
| 同版本号多文件 | 不应出现 | 文件名唯一，以清单为准 |

---

## 7. 版本比较说明

服务器生成清单时，对 **纯数字** 版本号按整数排序取最大值作为 `latest_version`，例如 `1009` < `1011`。

若未来版本号含字母（如 `1011a`），排序规则可能变为字符串序，**建议设备与服务器统一使用纯数字版本号**，或在 APP 内实现与设备固件一致的比较逻辑。

---

## 8. 与管理端的对应关系（供联调参考）

| 管理端操作 | 对 APP 的影响 |
|------------|----------------|
| 新增产品线 `7240` | `products.json` 与 `battery_update` 出现新 key |
| 上传 `7240_1012.bin` | `latest_version` 变为 `1012`，`latest_download_url` 更新 |
| 删除某版本文件 | `files` 减少，最新版可能回退 |
| 删除整条产品线 | `battery_update` 中 key 消失，APP 不应再对该 ID 升级 |

清单在每次上传/删除后自动刷新，`updated_at` 会更新。APP 可对比本地缓存的 `updated_at` 决定是否重新拉取（可选优化）。

---

## 9. 附录：管理 API（APP 无需集成）

以下接口前缀均为 `/upload-api`，仅供 Web 管理页使用。

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/products` | 产品线列表 |
| POST | `/api/products` | 创建产品线，body: `{"id","name","description?"}` |
| PATCH | `/api/products/{id}` | 修改名称、说明 |
| DELETE | `/api/products/{id}` | 删除产品线及下属固件 |
| GET | `/api/files?product_id=&category=` | 固件列表（含备注、分类） |
| POST | `/upload` | multipart：`product_id`、`version`、`file` |
| DELETE | `/api/files/{product_id}/{filename}` | 删除固件 |

---

## 10. 联调检查清单

- [ ] 能访问 `GET /api/version.json` 并解析 `battery_update`
- [ ] 本设备 `product_id` 与清单 key 一致
- [ ] 能下载 `latest_download_url`，大小等于 `size`
- [ ] SHA-256 校验通过后再发蓝牙 OTA
- [ ] 本地版本 ≥ `latest_version` 时不误提示升级
- [ ] 弱网 / 中断下载有重试或取消逻辑

---

## 11. 变更记录

| 日期 | 说明 |
|------|------|
| 2026-06-01 | 初版：基于产品线 `product_id` 架构，移除原 S/T 类型 |

如有新产品线或 URL 变更，以服务器实际返回的 `base_url`、`manifest_url` 为准。
