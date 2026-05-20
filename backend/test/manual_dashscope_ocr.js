#!/usr/bin/env node

const DEFAULT_MODEL = "qwen3.6-plus";
const DEFAULT_API_BASE = "https://dashscope.aliyuncs.com/compatible-mode/v1";
const DEFAULT_TIMEOUT_MS = 180000;
const DEFAULT_PROMPT = `你是一个数学题图片结构化识别助手。

你的任务不是解题，也不是分析错因，而是从图片中准确提取内容，并把内容划分为以下三个部分：

1. question_core：题目主干
2. standard_solution：标准题解
3. wrong_solution：学生错误过程或错误思路

请严格遵守以下规则：

1. 不要解题。
2. 不要判断错因。
3. 不要补充图片中没有的内容。
4. 数学公式统一转为 LaTeX。
5. 模糊无法识别的字符用 [UNK] 标记。

只输出 JSON，不要输出解释，不要输出 Markdown。

{
  "question_core": "",
  "standard_solution": "",
  "wrong_solution": "",
  "uncertain_parts": [],
  "ocr_confidence": "high | medium | low"
}`;

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || !args.imageUrl) {
    printUsage();
    process.exit(args.help ? 0 : 1);
  }

  const apiKey = args.apiKey || process.env.DASHSCOPE_API_KEY;
  if (!apiKey) {
    console.error("Missing API key. Set DASHSCOPE_API_KEY or pass --api-key.");
    process.exit(1);
  }

  const startedAt = Date.now();
  const imageInfo = await downloadImage(args.imageUrl, args.timeoutMs);
  const requestBody = buildRequestBody({
    model: args.model,
    prompt: args.prompt,
    dataUrl: imageInfo.dataUrl,
  });

  console.log("== Download ==");
  console.log(`url: ${args.imageUrl}`);
  console.log(`bytes: ${imageInfo.bytes.length}`);
  console.log(`content-type: ${imageInfo.contentType}`);
  console.log(`download-ms: ${imageInfo.elapsedMs}`);
  console.log(`data-url-length: ${imageInfo.dataUrl.length}`);
  console.log("");

  const ocrResult = await callDashScope({
    apiBase: args.apiBase,
    apiKey,
    timeoutMs: args.timeoutMs,
    body: requestBody,
  });

  console.log("== DashScope ==");
  console.log(`status: ${ocrResult.status}`);
  console.log(`request-ms: ${ocrResult.elapsedMs}`);
  console.log("");
  console.log("== Response JSON ==");
  console.log(JSON.stringify(ocrResult.json, null, 2));
  console.log("");
  console.log(`total-ms: ${Date.now() - startedAt}`);
}

function parseArgs(argv) {
  const args = {
    apiBase: DEFAULT_API_BASE,
    model: DEFAULT_MODEL,
    timeoutMs: DEFAULT_TIMEOUT_MS,
    prompt: DEFAULT_PROMPT,
    imageUrl: "",
    apiKey: "",
    help: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const current = argv[i];
    if (current === "--help" || current === "-h") {
      args.help = true;
      continue;
    }
    if (current === "--image-url") {
      args.imageUrl = argv[++i] || "";
      continue;
    }
    if (current === "--api-key") {
      args.apiKey = argv[++i] || "";
      continue;
    }
    if (current === "--model") {
      args.model = argv[++i] || DEFAULT_MODEL;
      continue;
    }
    if (current === "--api-base") {
      args.apiBase = argv[++i] || DEFAULT_API_BASE;
      continue;
    }
    if (current === "--timeout-ms") {
      args.timeoutMs = Number(argv[++i] || DEFAULT_TIMEOUT_MS);
      continue;
    }
    if (current === "--prompt") {
      args.prompt = argv[++i] || DEFAULT_PROMPT;
      continue;
    }
    if (!current.startsWith("--") && !args.imageUrl) {
      args.imageUrl = current;
      continue;
    }

    throw new Error(`Unknown argument: ${current}`);
  }

  if (!Number.isFinite(args.timeoutMs) || args.timeoutMs <= 0) {
    throw new Error(`Invalid --timeout-ms: ${args.timeoutMs}`);
  }

  return args;
}

function printUsage() {
  console.log(`Usage:
  node backend/test/manual_dashscope_ocr.js --image-url "<image-url>"

Options:
  --image-url   Required. Image URL to download first.
  --api-key     Optional. Falls back to DASHSCOPE_API_KEY.
  --model       Optional. Default: ${DEFAULT_MODEL}
  --api-base    Optional. Default: ${DEFAULT_API_BASE}
  --timeout-ms  Optional. Default: ${DEFAULT_TIMEOUT_MS}
  --prompt      Optional. Override OCR prompt.
  --help        Show this help.

Example:
  $env:DASHSCOPE_API_KEY="sk-xxxx"
  node backend/test/manual_dashscope_ocr.js --image-url "http://localhost:9001/..."
`);
}

async function downloadImage(imageUrl, timeoutMs) {
  const startedAt = Date.now();
  const response = await fetchWithTimeout(imageUrl, {
    method: "GET",
    headers: {
      Accept: "image/*,application/octet-stream;q=0.9,*/*;q=0.8",
    },
    timeoutMs,
  });

  if (!response.ok) {
    const body = await safeReadText(response);
    throw new Error(
      `Image download failed: ${response.status} ${response.statusText} ${body}`,
    );
  }

  const arrayBuffer = await response.arrayBuffer();
  const bytes = Buffer.from(arrayBuffer);
  if (bytes.length === 0) {
    throw new Error("Image download failed: empty body");
  }

  const contentType = detectImageContentType(
    response.headers.get("content-type"),
    imageUrl,
    bytes,
  );
  if (!contentType.startsWith("image/")) {
    throw new Error(
      `Image download failed: unsupported content-type ${contentType}`,
    );
  }

  return {
    bytes,
    contentType,
    dataUrl: `data:${contentType};base64,${bytes.toString("base64")}`,
    elapsedMs: Date.now() - startedAt,
  };
}

function buildRequestBody({ model, prompt, dataUrl }) {
  return {
    model,
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image_url",
            image_url: {
              url: dataUrl,
            },
          },
          {
            type: "text",
            text: prompt,
          },
        ],
      },
    ],
  };
}

async function callDashScope({ apiBase, apiKey, timeoutMs, body }) {
  const startedAt = Date.now();
  const response = await fetchWithTimeout(
    `${trimRightSlash(apiBase)}/chat/completions`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      timeoutMs,
    },
  );

  const text = await response.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch (error) {
    throw new Error(`DashScope returned non-JSON response: ${text}`);
  }

  return {
    status: response.status,
    elapsedMs: Date.now() - startedAt,
    json,
  };
}

async function fetchWithTimeout(url, options) {
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(new Error(`Timeout after ${options.timeoutMs}ms`)),
    options.timeoutMs,
  );

  try {
    return await fetch(url, {
      method: options.method,
      headers: options.headers,
      body: options.body,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}

async function safeReadText(response) {
  try {
    return await response.text();
  } catch {
    return "";
  }
}

function trimRightSlash(value) {
  return value.endsWith("/") ? value.slice(0, -1) : value;
}

function detectImageContentType(headerValue, imageUrl, bytes) {
  const parsedHeader = parseMediaType(headerValue);
  if (parsedHeader && !isGenericBinaryContentType(parsedHeader)) {
    return parsedHeader;
  }

  const lowerUrl = imageUrl.toLowerCase();
  if (lowerUrl.endsWith(".png")) return "image/png";
  if (lowerUrl.endsWith(".jpg") || lowerUrl.endsWith(".jpeg"))
    return "image/jpeg";
  if (lowerUrl.endsWith(".webp")) return "image/webp";
  if (lowerUrl.endsWith(".gif")) return "image/gif";
  if (lowerUrl.endsWith(".bmp")) return "image/bmp";
  if (lowerUrl.endsWith(".tif") || lowerUrl.endsWith(".tiff"))
    return "image/tiff";

  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return "image/png";
  }

  if (
    bytes.length >= 3 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[2] === 0xff
  ) {
    return "image/jpeg";
  }

  if (
    bytes.length >= 12 &&
    bytes.subarray(0, 4).toString("ascii") === "RIFF" &&
    bytes.subarray(8, 12).toString("ascii") === "WEBP"
  ) {
    return "image/webp";
  }

  if (bytes.length >= 6) {
    const sig = bytes.subarray(0, 6).toString("ascii");
    if (sig === "GIF87a" || sig === "GIF89a") {
      return "image/gif";
    }
  }

  if (bytes.length >= 2 && bytes[0] === 0x42 && bytes[1] === 0x4d) {
    return "image/bmp";
  }

  if (bytes.length >= 4) {
    const littleTiff =
      bytes[0] === 0x49 &&
      bytes[1] === 0x49 &&
      bytes[2] === 0x2a &&
      bytes[3] === 0x00;
    const bigTiff =
      bytes[0] === 0x4d &&
      bytes[1] === 0x4d &&
      bytes[2] === 0x00 &&
      bytes[3] === 0x2a;
    if (littleTiff || bigTiff) {
      return "image/tiff";
    }
  }

  return parsedHeader || "application/octet-stream";
}

function parseMediaType(headerValue) {
  if (!headerValue) {
    return "";
  }
  return String(headerValue).split(";")[0].trim().toLowerCase();
}

function isGenericBinaryContentType(contentType) {
  const normalized = String(contentType).trim().toLowerCase();
  return (
    normalized === "application/octet-stream" ||
    normalized === "binary/octet-stream"
  );
}

main().catch((error) => {
  console.error("== Error ==");
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
