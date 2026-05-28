# Feedback Report API

当前客户端按用户要求优先通过邮件直接发送反馈到 `yuyutian_assistant@foxmail.com`，邮件正文使用下方请求结构格式化。下方接口作为后续服务端上报能力预留；服务端完成后，客户端可恢复在线提交和失败重试。

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

## Current Client Behavior

- 应用端入口：个人信息 -> 帮助与反馈。
- 当前提交按钮会打开系统邮件客户端，收件人为 `yuyutian_assistant@foxmail.com`。
- 邮件主题格式：`[MyAssistant反馈][模块][优先级] 标题`。
- 邮件正文包含模块、类型、优先级、联系方式、提交时间、问题描述和诊断信息。
- 支持选择截图；由于 `mailto` 通常无法可靠自动携带附件，客户端会在邮件正文中列出截图路径，用户可在邮件客户端中附加对应图片。

## Future API Client Behavior

- 在线提交失败时，客户端写入本地文件：

```text
<ApplicationSupportDirectory>/feedback/pending_reports.jsonl
```

- 当前客户端已记录本地待上报数量；后续可在服务端接口完成后补充定时重试和手动重传。
