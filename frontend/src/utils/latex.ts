export const latexDelimiters = [
  { left: '$$', right: '$$', display: true },
  { left: '\\[', right: '\\]', display: true },
  { left: '$', right: '$', display: false },
  { left: '\\(', right: '\\)', display: false },
]

const rawLatexCommandPattern = /\\[a-zA-Z]+/
const explicitLatexDelimiterPattern = /(\$\$[\s\S]*\$\$|\\\[[\s\S]*\\\]|(?<!\\)\$[^$]+(?<!\\)\$|\\\([\s\S]*\\\))/
const optionPrefixPattern = /^([A-Za-z]\s*[.、)|]|[0-9]+\s*[.、)])\s+/
const mathDominantPattern = /^[A-Za-z0-9\s\\{}[\]()_^|=+\-*/<>,.:;'`~!?%&]+$/
const cjkPattern = /[\u3400-\u9fff]/
const cjkSeparatorPattern = /([\u3400-\u9fff\u3000-\u303f\uff00-\uffef])/
const mathSignalPattern =
  /\\[a-zA-Z]+|[_^=<>]|(?:\b[a-zA-Z]+\s*\([^)]*\))|(?:[A-Za-z0-9)][+\-*/][A-Za-z0-9(])/

function containsExplicitLatexDelimiters(line: string) {
  return explicitLatexDelimiterPattern.test(line)
}

function isMathDominantLine(line: string) {
  return mathDominantPattern.test(line) && !cjkPattern.test(line)
}

function wrapRawLatexLine(line: string) {
  const trimmed = line.trim()
  if (!trimmed) {
    return line
  }

  const leadingWhitespace = line.match(/^\s*/)?.[0] ?? ''
  const optionPrefixMatch = trimmed.match(optionPrefixPattern)
  const optionPrefix = optionPrefixMatch?.[0] ?? ''
  const body = trimmed.slice(optionPrefix.length).trim()

  if (body && !containsExplicitLatexDelimiters(trimmed) && isMathDominantLine(body)) {
    if (rawLatexCommandPattern.test(body) || mathSignalPattern.test(body)) {
      return `${leadingWhitespace}${optionPrefix}\\(${body}\\)`
    }
  }

  return wrapInlineRawLatex(line)
}

function splitByExplicitLatexDelimiters(line: string) {
  const segments: Array<{ value: string; isExplicitMath: boolean }> = []
  let cursor = 0

  for (const match of line.matchAll(new RegExp(explicitLatexDelimiterPattern, 'g'))) {
    const matched = match[0] ?? ''
    const start = match.index ?? 0
    if (start > cursor) {
      segments.push({ value: line.slice(cursor, start), isExplicitMath: false })
    }
    segments.push({ value: matched, isExplicitMath: true })
    cursor = start + matched.length
  }

  if (cursor < line.length) {
    segments.push({ value: line.slice(cursor), isExplicitMath: false })
  }

  return segments
}

function shouldWrapRawMathChunk(chunk: string) {
  const trimmed = chunk.trim()
  if (!trimmed || containsExplicitLatexDelimiters(trimmed)) {
    return false
  }

  return rawLatexCommandPattern.test(trimmed) || mathSignalPattern.test(trimmed)
}

function wrapChunkIfNeeded(chunk: string) {
  if (!shouldWrapRawMathChunk(chunk)) {
    return chunk
  }

  const leadingWhitespace = chunk.match(/^\s*/)?.[0] ?? ''
  const trailingWhitespace = chunk.match(/\s*$/)?.[0] ?? ''
  const trimmed = chunk.trim()
  return `${leadingWhitespace}\\(${trimmed}\\)${trailingWhitespace}`
}

function wrapInlineRawLatex(line: string) {
  return splitByExplicitLatexDelimiters(line)
    .map((segment) => {
      if (segment.isExplicitMath) {
        return segment.value
      }

      return segment.value
        .split(cjkSeparatorPattern)
        .map((chunk) => (cjkSeparatorPattern.test(chunk) ? chunk : wrapChunkIfNeeded(chunk)))
        .join('')
    })
    .join('')
}

export function normalizeLatexContent(content: string) {
  return content
    .split(/\r?\n/)
    .map(wrapRawLatexLine)
    .join('\n')
}
