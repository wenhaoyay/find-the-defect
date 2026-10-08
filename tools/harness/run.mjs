// Runs the Luau test suite without Roblox Studio.
//
// The game's code is plain Luau; only the engine around it is Roblox. This runner
// loads the real Luau VM (luau-web, WebAssembly), builds the instance tree from
// default.project.json exactly as Rojo would, and hands it to a small engine
// emulator (rbx.luau): virtual clock, task scheduler, signals, instances, Players,
// DataStores and MessagingService shared by several emulated servers.
//
//   node tools/harness/run.mjs            run every tests/**/*.spec.luau
//   node tools/harness/run.mjs Data       only spec files whose path contains "Data"

import { LuauState } from 'luau-web'
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs'
import { join, relative, sep, basename } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(fileURLToPath(import.meta.url), '..', '..', '..')
const filter = process.argv[2] ?? ''

// ---------------------------------------------------------------------------
// Rojo project -> flat manifest of instances

function classForFile(name) {
    if (name.endsWith('.server.luau')) return ['Script', name.slice(0, -'.server.luau'.length)]
    if (name.endsWith('.client.luau')) return ['LocalScript', name.slice(0, -'.client.luau'.length)]
    if (name.endsWith('.luau')) return ['ModuleScript', name.slice(0, -'.luau'.length)]
    return null
}

function addPath(entries, instancePath, fsPath) {
    const full = join(root, fsPath)
    if (!existsSync(full)) throw new Error(`Rojo $path does not exist: ${fsPath}`)
    if (statSync(full).isFile()) {
        const mapped = classForFile(basename(fsPath))
        if (!mapped) throw new Error(`Unsupported file in project: ${fsPath}`)
        entries.push({ path: instancePath, className: mapped[0], file: fsPath })
        return
    }
    const names = readdirSync(full).sort()
    const init = names.find(n => /^init(\.server|\.client)?\.luau$/.test(n))
    if (init) {
        entries.push({ path: instancePath, className: classForFile(init)[0], file: join(fsPath, init) })
    } else {
        entries.push({ path: instancePath, className: 'Folder' })
    }
    for (const name of names) {
        if (name === init) continue
        const childFs = join(fsPath, name)
        if (statSync(join(root, childFs)).isDirectory()) {
            addPath(entries, [...instancePath, name], childFs)
        } else {
            const mapped = classForFile(name)
            if (mapped) entries.push({ path: [...instancePath, mapped[1]], className: mapped[0], file: childFs })
        }
    }
}

function walkTree(entries, node, instancePath) {
    if (instancePath.length > 0) {
        if (node.$path) addPath(entries, instancePath, node.$path)
        else entries.push({ path: instancePath, className: node.$className ?? 'Folder' })
    }
    for (const [key, child] of Object.entries(node)) {
        if (!key.startsWith('$')) walkTree(entries, child, [...instancePath, key])
    }
}

const project = JSON.parse(readFileSync(join(root, 'default.project.json'), 'utf8'))
const entries = []
walkTree(entries, project.tree, [])

// JS arrays arrive in Luau 0-indexed, so data crosses as generated Luau source.
const luauString = s => JSON.stringify(s)
const manifestSource =
    'return {\n' +
    entries
        .map(e => {
            const path = e.path.map(luauString).join(', ')
            const file = e.file ? `, file = ${luauString(e.file.split(sep).join('/'))}` : ''
            return `\t{ path = { ${path} }, className = ${luauString(e.className)}${file} },`
        })
        .join('\n') +
    '\n}'

// ---------------------------------------------------------------------------
// Spec files

function findSpecs(dir) {
    const out = []
    for (const name of readdirSync(dir).sort()) {
        const full = join(dir, name)
        if (statSync(full).isDirectory()) out.push(...findSpecs(full))
        else if (name.endsWith('.spec.luau')) out.push(relative(root, full).split(sep).join('/'))
    }
    return out
}
const specs = findSpecs(join(root, 'tests')).filter(p => p.includes(filter))
const specSource = 'return {\n' + specs.map(p => `\t${luauString(p)},`).join('\n') + '\n}'

// ---------------------------------------------------------------------------
// Luau VM

const state = await LuauState.createAsync({
    print: (...args) => console.log(args.join(' ')),
    host_readFile: path => readFileSync(join(root, path), 'utf8').replace(/\r\n/g, '\n'),
    host_compile: (source, chunkName) => state.loadstring(source, chunkName, true),
    host_write: text => process.stdout.write(text),
})

const load = (file, name) => state.loadstring(readFileSync(join(root, file), 'utf8'), name, true)
const [manifest] = await state.loadstring(manifestSource, 'manifest', true)()
const [specList] = await state.loadstring(specSource, 'specs', true)()
const [Rbx] = await load('tools/harness/rbx.luau', 'rbx')(manifest)
const [runSuite] = await load('tools/harness/testkit.luau', 'testkit')()
const [failed] = await runSuite(Rbx, specList)

process.exitCode = failed === 0 ? 0 : 1
