# Third-party code and assets

Rule: free and safe first. Code comes from its authors' repositories at a pinned version and is read
before use; nothing is loaded by asset id at runtime; Creator Store models are used only if they contain
no scripts, or after their scripts are sandboxed and read.

| Item | Where | Version | Licence | Used for | Review |
|---|---|---|---|---|---|
| ProfileStore | [MadStudioRoblox/ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) → `vendor/ProfileStore.luau` | commit `45c9847cbcf1fc260369c50eb335aba7c35aecdd`, sha256 `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f` | Apache-2.0 (`vendor/ProfileStore.LICENSE`) | Player data sessions | Uses only DataStoreService, MessagingService, HttpService (`GenerateGUID` only) and RunService. No `require` by asset id, `loadstring`, `getfenv`, or HTTP requests. Unmodified. |
| luau-web | [npm](https://www.npmjs.com/package/luau-web) / [xNasuni/luau-web](https://github.com/xNasuni/luau-web) | 1.5.0 (exact) | MIT | Tests only (dev dependency) | No dependencies, no install scripts (installed with `--ignore-scripts` anyway). Its Node glue reads its own WebAssembly with `fs.readFileSync`; no other file, network or process access. |
| @johnnymorganz/stylua | [npm](https://www.npmjs.com/package/@johnnymorganz/stylua) / [JohnnyMorganz/StyLua](https://github.com/JohnnyMorganz/StyLua) | 2.5.2 (exact) | MPL-2.0 | `npm run format` without Rokit (dev dependency) | Official WebAssembly build, same version as CI's binary. No dependencies or install scripts; its Node glue only reads its own `.wasm`. |
| Rojo, StyLua, Selene | GitHub releases | 7.7.1, 2.5.2, 0.32.0 | MPL-2.0, MPL-2.0, MPL-2.0 | CI build, format, lint | Official release binaries, pinned by version in CI and `rokit.toml`. |

No art, audio or models are in the repository yet.
