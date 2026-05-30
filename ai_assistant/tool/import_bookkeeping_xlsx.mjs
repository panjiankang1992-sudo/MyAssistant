import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = process.argv[2];
if (!inputPath) {
  console.error("Usage: node import_bookkeeping_xlsx.mjs <xlsx> [--all-containers]");
  process.exit(1);
}

const importId = "ocr-2026-screenshot";
const allContainers = process.argv.includes("--all-containers");
const home = process.env.HOME;
if (!home) {
  console.error("HOME is not set.");
  process.exit(1);
}

const containers = [
  {
    id: "com.yuyutian.assistant",
    basePath: path.join(home, "Library/Containers/com.yuyutian.assistant/Data"),
  },
  ...(allContainers
    ? [
        {
          id: "com.example.aiAssistant",
          basePath: path.join(home, "Library/Containers/com.example.aiAssistant/Data"),
        },
      ]
    : []),
];

const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(inputPath));
const detailRows = await inspectDetailRows();
const monthlyRows = await inspectValues("月度汇总!A1:H20", 20, 8);
const entries = parseEntries(detailRows);
const monthlyChecks = compareMonthly(entries, monthlyRows);

const results = [];
for (const container of containers) {
  results.push(await importIntoContainer(container, entries));
}

console.log(
  JSON.stringify(
    {
      source: inputPath,
      parsedEntries: entries.length,
      monthlyChecks,
      results,
    },
    null,
    2,
  ),
);

async function inspectValues(range, tableMaxRows, tableMaxCols) {
  const inspected = await workbook.inspect({
    kind: "table",
    range,
    include: "values,formulas",
    tableMaxRows,
    tableMaxCols,
  });
  const firstLine = inspected.ndjson.trim().split("\n")[0];
  return JSON.parse(firstLine).values;
}

async function inspectDetailRows() {
  const rows = [];
  for (let start = 1; start <= 1200; start += 200) {
    const end = start + 199;
    const chunk = await inspectValues(`明细!A${start}:D${end}`, 200, 4);
    if (!chunk || chunk.length === 0) continue;
    if (start === 1) {
      rows.push(...chunk);
    } else {
      rows.push(...chunk.filter((row) => row.some((value) => value != null)));
    }
    const nonEmpty = chunk.filter((row) => row.some((value) => value != null));
    if (start > 1 && nonEmpty.length === 0) break;
  }
  return rows;
}

function parseEntries(rows) {
  const result = [];
  for (let i = 1; i < rows.length; i += 1) {
    const row = rows[i] ?? [];
    const [serial, rawCategory, rawAmount, rawKind] = row;
    if (serial == null || rawCategory == null || rawAmount == null || rawKind == null) {
      continue;
    }
    const amount = Number(rawAmount);
    if (!Number.isFinite(amount) || amount <= 0) continue;

    const kind = String(rawKind).trim() === "收入" ? "income" : "expense";
    const sourceCategory = String(rawCategory).trim() || "其他";
    const category = categoryFor(sourceCategory, kind);
    const date = excelSerialToLocalIso(Number(serial), i);
    result.push({
      id: `import-${importId}-${String(i).padStart(4, "0")}`,
      kind,
      categoryId: category.id,
      categoryName: category.name,
      categoryEmoji: category.emoji,
      note: `截图识别导入 · 原分类：${sourceCategory}`,
      amount: round2(amount),
      currency: "CNY",
      cnyAmount: round2(amount),
      date,
      aiGenerated: true,
      tags: [],
      createdAt: date,
    });
  }
  result.sort((a, b) => b.date.localeCompare(a.date));
  return result;
}

function compareMonthly(entries, rows) {
  const actual = new Map();
  for (const entry of entries) {
    const month = entry.date.slice(0, 7);
    const current = actual.get(month) ?? { income: 0, expense: 0, count: 0 };
    current[entry.kind] = round2(current[entry.kind] + entry.cnyAmount);
    current.count += 1;
    actual.set(month, current);
  }

  const checks = [];
  for (let i = 1; i < rows.length; i += 1) {
    const row = rows[i] ?? [];
    const month = row[0];
    if (!month) continue;
    const expected = {
      income: round2(Number(row[1] ?? 0)),
      expense: round2(Number(row[2] ?? 0)),
      count: Number(row[4] ?? 0),
      sourceCheck: row[7] ?? "",
    };
    const got = actual.get(String(month)) ?? { income: 0, expense: 0, count: 0 };
    checks.push({
      month,
      expected,
      actual: got,
      matches:
        expected.income === round2(got.income) &&
        expected.expense === round2(got.expense) &&
        expected.count === got.count,
    });
  }
  return checks;
}

async function importIntoContainer(container, entries) {
  const folder = path.join(
    container.basePath,
    "Library/Application Support",
    container.id,
    "bookkeeping",
  );
  await fs.mkdir(folder, { recursive: true });
  const filePath = path.join(folder, "entries.json");
  const existing = await readExistingEntries(filePath);
  const preserved = existing.filter((entry) => !String(entry.id ?? "").startsWith(`import-${importId}-`));
  const merged = [...entries, ...preserved].sort((a, b) =>
    String(b.date ?? "").localeCompare(String(a.date ?? "")),
  );

  const timestamp = new Date().toISOString().replaceAll(":", "").replaceAll(".", "-");
  let backup = null;
  try {
    await fs.access(filePath);
    backup = `${filePath}.bak-import-${timestamp}`;
    await fs.copyFile(filePath, backup);
  } catch {
    // New file.
  }
  await fs.writeFile(filePath, `${JSON.stringify({ entries: merged }, null, 2)}\n`, "utf8");
  return {
    container: container.id,
    filePath,
    backup,
    preservedExistingEntries: preserved.length,
    importedEntries: entries.length,
    totalEntries: merged.length,
  };
}

async function readExistingEntries(filePath) {
  try {
    const text = await fs.readFile(filePath, "utf8");
    const data = JSON.parse(text);
    return Array.isArray(data.entries) ? data.entries : [];
  } catch {
    return [];
  }
}

function excelSerialToLocalIso(serial, rowIndex) {
  const base = Date.UTC(1899, 11, 30);
  const date = new Date(base + serial * 86400000);
  const yyyy = date.getUTCFullYear();
  const mm = String(date.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(date.getUTCDate()).padStart(2, "0");
  const minute = rowIndex % 60;
  const second = Math.floor(rowIndex / 60) % 60;
  return `${yyyy}-${mm}-${dd}T12:${String(minute).padStart(2, "0")}:${String(second).padStart(2, "0")}.000`;
}

function categoryFor(name, kind) {
  const normalized = name.trim();
  if (kind === "income") {
    if (normalized === "工资") return { id: "salary", name: "工资", emoji: "💼" };
    if (normalized === "奖金") return { id: "bonus", name: "奖金", emoji: "🎁" };
    if (normalized === "退款") return { id: "refund", name: "退款", emoji: "↩️" };
    return { id: "other_income", name: normalized === "其他" ? "其他收入" : normalized, emoji: "💰" };
  }

  const defaults = {
    餐饮: ["food", "🍜"],
    购物: ["shopping", "🛍"],
    交通: ["traffic", "🚌"],
    零食: ["snack", "🍭"],
    蔬菜: ["vegetable", "🥬"],
    水果: ["fruit", "🍓"],
    娱乐: ["entertainment", "🎭"],
    汽车: ["car", "🚕"],
    美妆: ["beauty", "💄"],
    日用: ["daily", "🧴"],
    学习: ["study", "📚"],
    医疗: ["medical", "💊"],
    其他: ["other", "🔹"],
  };
  if (defaults[normalized]) {
    const [id, emoji] = defaults[normalized];
    return { id, name: normalized, emoji };
  }
  if (normalized === "生活缴费") return { id: "utilities", name: normalized, emoji: "💡" };
  if (normalized === "未识别") return { id: "unrecognized", name: normalized, emoji: "❓" };
  if (["15", "质", "落茨", "覃皇耆宁/】宁-星星抖首创业", "彗享亘亡吾.{〉>\"吏车】贾′用"].includes(normalized)) {
    return { id: "unrecognized", name: "未识别", emoji: "❓" };
  }
  if (normalized === "贺") return { id: "gift_expense", name: "礼物", emoji: "🎁" };
  if (normalized === "数码") return { id: "digital", name: normalized, emoji: "💻" };
  return { id: slug(normalized), name: normalized, emoji: "🔹" };
}

function slug(value) {
  const encoded = Buffer.from(value).toString("hex").slice(0, 24);
  return `imported_${encoded || "category"}`;
}

function round2(value) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}
