# Feedback Report API

客户端已接入反馈上报能力。服务端完成下方接口后，应用会优先在线提交；接口不可用或网络失败时，客户端会把反馈写入本地待上报队列。

## Endpoint

```http
POST /api/public/feedback/report
Content-Type: application/json
Authorization: Bearer <jwt>   # 登录态存在时携带
```

## Request

```json
{
  "id": "9a0b3d1b-5b8c-4f92-8a7b-2c060f4d9d73",
  "module": "todo",
  "type": "bug",
  "severity": "normal",
  "title": "记账统计页面筛选异常",
  "content": "点击购物分类后图表有动画，但下方列表没有刷新。",
  "contact": "user@example.com",
  "includeDiagnostics": true,
  "createdAt": "2026-05-28T21:30:00.000",
  "diagnostics": {
    "platform": "macos",
    "platformVersion": "Version 15.x",
    "locale": "zh_CN",
    "appVersion": "0.1.0+1",
    "client": "flutter"
  }
}
```

## Fields

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | 是 | 客户端生成的 UUID，用于幂等去重 |
| `module` | string | 是 | `todo` / `bookkeeping` / `notes` / `copilot` / `sync` / `account` / `theme` / `other` |
| `type` | string | 是 | `bug` / `suggestion` / `usability` / `data` / `question` |
| `severity` | string | 是 | `normal` / `important` / `urgent` |
| `title` | string | 是 | 反馈标题，建议 2-80 字 |
| `content` | string | 是 | 详细描述，建议至少 8 字 |
| `contact` | string | 否 | 用户填写的联系方式 |
| `includeDiagnostics` | boolean | 是 | 是否允许附带诊断信息 |
| `createdAt` | string | 是 | 客户端创建时间，ISO-8601 |
| `diagnostics` | object | 否 | 平台、系统版本、语言、应用版本等；不包含个人业务内容 |

## Response

成功：

```json
{
  "code": "0000",
  "message": "success",
  "traceId": "fb_20260528_000001",
  "data": {
    "reportId": "fb_20260528_000001",
    "status": "received"
  }
}
```

失败：

```json
{
  "code": "4001",
  "message": "title is required",
  "traceId": "fb_20260528_000002",
  "data": null
}
```

## Suggested Server Behavior

- 以 `id` 做幂等键，同一用户重复提交同一个 `id` 时直接返回已有 `reportId`。
- 保存原始请求体，便于后续扩展附件、截图、日志。
- 登录态存在时关联用户；未登录也允许匿名提交。
- 对 `title`、`content`、`contact` 做长度限制和基础清洗。
- 后台可按 `module`、`type`、`severity`、`createdAt` 建索引。

## Client Behavior

- 应用端入口：个人信息 -> 帮助与反馈。
- 支持邮件反馈：`feedback@myassistant.app`。
- 在线提交失败时，客户端写入本地文件：

```text
<ApplicationSupportDirectory>/feedback/pending_reports.jsonl
```

- 当前客户端已记录本地待上报数量；后续可在服务端接口完成后补充定时重试和手动重传。
