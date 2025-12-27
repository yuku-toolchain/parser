// this is a wasm module, and i know it's not expected to use for these kinds of tasks, also not expected to use in node
// so replace it with the yuku node (napi) module when we have it
import { parseSync, preload } from "../dist/browser"
import { Glob } from "bun"
import equal from "fast-deep-equal"
import { diff } from "jest-diff"
import { basename, dirname, join } from "path"

await preload()

console.clear()

type TestType = "ast" | "should_pass" | "should_fail" | "snapshot"
type Language = "js" | "ts" | "jsx" | "tsx" | "dts"

interface TestConfig {
  path: string
  type: TestType
  languages: Language[]
  exclude?: string[] // file paths to exclude
}

const configs: TestConfig[] = [
  { path: "test/js/pass", type: "ast", languages: ["js"] },
  { path: "test/js/fuzz", type: "ast", languages: ["js"] },
  { path: "test/js/fail", type: "should_fail", languages: ["js"],
    exclude: [
      // these are the semantic tests, remove these from the list
      // when we implement semantic checks
      "67c714796e7f40a4.js",
      "e6559958e6954318.js",
      "4e2cce832b4449f1.js",
      "317c81f05510f4ad.js",
      "76465e2c7af91e73.js",
      "fb130c395c6aafe7.js",
      "c7ad2478fd72bffe.js",
      "5e6f67a0e748cc42.js",
      "efcb54b62e8f0e06.js",
      "8b72c44bd531621a.js",
      "d17d3aebb6a3cf43.js",
      "2b050de45ab44c8c.js",
      "3078b4fed5626e2a.js",
      "04bc213db9cd1130.js",
      "4a887c2761eb95fb.js",
      "16947dc1d11e5e70.js",
      "8d5ef4dee9c7c622.js",
      "e808e347646c2670.js",
      "f2db53245b89c72f.js",
      "73d061b5d635a807.js",
      "b88ab70205263170.module.js",
      "6cd36f7e68bdfb7a.js",
      "a4bfa8e3b523c466.module.js",
      "858b72be7f8f19d7.js",
      "2226edabbd2261a7.module.js",
      "d54b2db4548f1d82.module.js",
      "5059efc702f08060.js",
      "f063969b23239390.module.js"
  ] },
  { path: "test/js/snapshot", type: "snapshot", languages: ["js"] },
]

interface TestResult {
  passed: number
  failed: number
  total: number
  failures: string[]
}

const results = new Map<string, TestResult>()

const getLanguage = (path: string): Language => {
  if (path.endsWith(".tsx")) return "tsx"
  if (path.endsWith(".jsx")) return "jsx"
  if (path.endsWith(".d.ts")) return "dts"
  if (path.endsWith(".ts")) return "ts"
  return "js"
}

const getBaseName = (file: string): string => {
  const name = basename(file)
  const firstDot = name.indexOf(".")
  return firstDot >= 0 ? name.substring(0, firstDot) : name
}

const isTestArtifact = (path: string): boolean => {
  return (
    path.endsWith(".expected.json") ||
    path.endsWith(".snapshot.json") ||
    path.includes(".snap")
  )
}

const isExcluded = (path: string, excludePatterns: string[] = []): boolean => {
  return excludePatterns.some(pattern => {
    // Support both exact filename matches and partial path matches
    return path.includes(pattern) || basename(path) === pattern
  })
}

const shouldIncludeFile = (path: string, languages: Language[], exclude?: string[]): boolean => {
  if (isTestArtifact(path)) return false
  if (isExcluded(path, exclude)) return false
  const lang = getLanguage(path)
  return languages.includes(lang)
}

const runTest = async (
  file: string,
  type: TestType,
  result: TestResult,
): Promise<void> => {
  try {
    const content = await Bun.file(file).text()
    const lang = getLanguage(file)
    const sourceType = file.includes(".module.") ? "module" : "script"

    const parsed = parseSync(content, { sourceType, lang })

    const hasErrors = parsed.errors && parsed.errors.length > 0

    if (type === "should_pass") {
      if (hasErrors) {
        result.failures.push(file)
        return
      }
      result.passed++
      return
    }

    if (type === "should_fail") {
      if (!hasErrors) {
        result.failures.push(file)
        return
      }
      result.passed++
      return
    }

    if (type === "ast") {
      const dir = dirname(file)
      const base = getBaseName(file)
      const expectedFile = join(dir, `${base}.expected.json`)

      const expectedExists = await Bun.file(expectedFile).exists()

      if (!expectedExists) {
        result.failures.push(`${file} (missing expected.json)`)
        return
      }

      const expected = await Bun.file(expectedFile).json()

      if (!hasErrors && !equal(parsed, expected)) {
        const difference = diff(expected, parsed, { contextLines: 2 })
        console.log(`\nx ${file}\n${difference}\n`)
        result.failures.push(file)
        return
      }

      result.passed++
      return
    }

    if (type === "snapshot") {
      const dir = dirname(file)
      const base = getBaseName(file)
      const snapshotFile = join(dir, `${base}.snapshot.json`)
      const snapshotExists = await Bun.file(snapshotFile).exists()

      if (!snapshotExists) {
        await Bun.write(snapshotFile, JSON.stringify(parsed, null, 2))
        result.passed++
        return
      }

      const snapshot = await Bun.file(snapshotFile).json()

      if (!equal(parsed, snapshot)) {
        const difference = diff(snapshot, parsed, { contextLines: 2 })
        console.log(`\nx ${file}\n${difference}\n`)
        result.failures.push(file)
        return
      }

      result.passed++
    }
  } catch (err) {
    result.failures.push(`${file} (error: ${err})`)
  }
}

const runCategory = async (config: TestConfig) => {
  const result: TestResult = { passed: 0, failed: 0, total: 0, failures: [] }
  results.set(config.path, result)

  const pattern = `${config.path}/**/*`
  const glob = new Glob(pattern)
  const files: string[] = []

  for await (const file of glob.scan(".")) {
    if (shouldIncludeFile(file, config.languages, config.exclude)) {
      files.push(file)
    }
  }

  result.total = files.length

  if (result.total === 0) return

  process.stdout.write(`${config.path} `)

  for (const file of files) {
    await runTest(file, config.type, result)
    process.stdout.write(`\r${config.path} ${result.passed}/${result.total}`)
  }

  result.failed = result.failures.length

  const status = result.failed === 0 ? "✓" : "x"
  console.log(`\r${status} ${config.path} ${result.passed}/${result.total}`)

  if (result.failures.length > 0) {
    result.failures.forEach(f => console.log(`  x ${f}`))
  }
}

console.log("Running tests...\n")

for (const config of configs) {
  await runCategory(config)
}

console.log("\nSummary:")

let totalPassed = 0
let totalFailed = 0
let totalTests = 0

for (const [path, result] of results) {
  if (result.total === 0) continue
  console.log(`  ${path}: ${result.passed}/${result.total}`)
  totalPassed += result.passed
  totalFailed += result.failed
  totalTests += result.total
}

console.log(`\nTotal: ${totalPassed}/${totalTests}`)

if (totalFailed > 0) {
  process.exit(1)
}
