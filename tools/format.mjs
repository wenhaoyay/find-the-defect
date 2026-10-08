// Formats the Luau sources with StyLua's official WebAssembly build — the same
// version CI's binary uses — so formatting works on machines without Rokit.
//
//   node tools/format.mjs           rewrite files in place
//   node tools/format.mjs --check   list files that would change; exit 1 if any

import { formatCode, Config, OutputVerification, CallParenType, CollapseSimpleStatement, IndentType, LineEndings, LuaVersion, QuoteStyle } from '@johnnymorganz/stylua'
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(fileURLToPath(import.meta.url), '..', '..')
const check = process.argv.includes('--check')

// stylua.toml holds flat `key = value` lines only; read the ones we set.
const settings = Object.fromEntries(
    readFileSync(join(root, 'stylua.toml'), 'utf8')
        .split('\n')
        .map(line => line.replace(/#.*/, '').trim())
        .filter(Boolean)
        .map(line => line.split('=').map(part => part.trim().replace(/^"|"$/g, ''))),
)
// formatCode takes ownership of its Config, so each call gets a new one.
function makeConfig() {
    const config = Config.new()
    config.syntax = LuaVersion[settings.syntax]
    config.column_width = Number(settings.column_width)
    config.line_endings = LineEndings[settings.line_endings]
    config.indent_type = IndentType[settings.indent_type]
    config.indent_width = Number(settings.indent_width)
    config.quote_style = QuoteStyle[settings.quote_style]
    config.call_parentheses = CallParenType[settings.call_parentheses]
    config.collapse_simple_statement = CollapseSimpleStatement[settings.collapse_simple_statement]
    return config
}

const ignored = readFileSync(join(root, '.styluaignore'), 'utf8')
    .split('\n')
    .map(line => line.trim().replace(/\/$/, ''))
    .filter(Boolean)

function luauFiles(dir) {
    const out = []
    for (const name of readdirSync(join(root, dir)).sort()) {
        const path = join(dir, name)
        const unix = path.split(sep).join('/')
        if (ignored.some(prefix => unix === prefix || unix.startsWith(prefix + '/'))) continue
        if (statSync(join(root, path)).isDirectory()) out.push(...luauFiles(path))
        else if (name.endsWith('.luau')) out.push(path)
    }
    return out
}

let changed = 0
for (const file of ['src', 'tests', 'tools'].flatMap(luauFiles)) {
    const source = readFileSync(join(root, file), 'utf8').replace(/\r\n/g, '\n')
    const formatted = formatCode(source, makeConfig(), undefined, OutputVerification.Full)
    if (formatted !== source) {
        changed += 1
        const name = relative(root, join(root, file)).split(sep).join('/')
        if (check) console.log(`would reformat ${name}`)
        else writeFileSync(join(root, file), formatted)
    }
}
console.log(check ? `${changed} file(s) need formatting` : `${changed} file(s) formatted`)
if (check && changed > 0) process.exitCode = 1
