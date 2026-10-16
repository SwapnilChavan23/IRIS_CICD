# IRIS HealthConnect CI/CD – Setup & Deployment Instructions

Manual, review-driven CI/CD between the local **DEV** (port 52773) and **TEST** (port 52774)
IRIS for Health instances, namespace **USER**, using git, git bash and VS Code.

```
 IRIS DEV ──export-dev.sh──▶ DEV_Git (branch DEV) ──git merge──▶ TEST_Git (branch TEST) ──deploy-test.sh──▶ IRIS TEST
                                   │  review diff, commit, push         │  review diff, push
                                   ▼                                    ▼
                               GitHub: DEV                          GitHub: TEST
```

## 1. What was set up

| Item | Purpose |
|---|---|
| Branches `DEV`, `TEST` (from `main`) | One branch per environment |
| `DEV_Git/` | git **worktree** of branch `DEV` – mirrors IRIS DEV |
| `TEST_Git/` | git **worktree** of branch `TEST` – mirrors IRIS TEST |
| `src/` (inside each worktree) | Exported source, one file per document, e.g. `src/INFORMATION/Interop/RoutingRule.cls` |
| `scripts/iris_sync.py` | Talks to IRIS through the built-in Atelier REST API (`/api/atelier`) – nothing to install in IRIS |
| `scripts/export-dev.sh` | IRIS DEV → `DEV_Git/src` |
| `scripts/load-dev.sh` | `DEV_Git/src` → IRIS DEV (only needed when code changes in git first) |
| `scripts/deploy-test.sh` | `TEST_Git/src` → IRIS TEST, upload changed docs + compile (`--dry-run` to preview) |
| `scripts/status.sh` | Show differences between a worktree and its instance |
| `.env` (git-ignored) / `.env.example` | IRIS credentials for DEV and TEST |
| `IRIS_CICD.code-workspace` | VS Code workspace with both worktrees and server definitions |

What is under source control: classes, routines/includes, lookup tables, HL7/X12 schemas and
dashboards **stored in the USER database**. Product code mapped in from ENSLIB/HSLIB/IRISLIB and the
`Ens*` system includes are skipped. To also track another database, set e.g. `IRIS_SRC_DBS=USER,HSCUSTOM` in `.env`.

## 2. Setup steps performed

1. Created `.gitignore` (ignores `.env`, the `DEV_Git/`/`TEST_Git/` folders inside `main`, local `.vscode/settings.json`, `.DS_Store`) and stopped tracking `.DS_Store`.
2. Added the scripts in `scripts/` and `.env.example`; committed to `main`.
3. Created branches and worktrees:
   ```bash
   cd /Users/home/IRIS_CICD
   git branch DEV && git branch TEST
   git worktree add DEV_Git DEV
   git worktree add TEST_Git TEST
   ```
4. Added `IRIS_CICD.code-workspace` plus per-worktree `.vscode/settings.json`:
   - `DEV_Git` → server `iris-dev`, namespace USER, connection **active** (save = upload + compile on DEV).
   - `TEST_Git` → server `iris-test`, connection **inactive** on purpose, so TEST only changes through `deploy-test.sh`.
5. Created `/Users/home/IRIS_CICD/.env` from `.env.example` with the DEV/TEST credentials.
6. First export of DEV (`./scripts/export-dev.sh`) committed as the baseline.
7. **Standardised class names.** DEV used `INFORMATION.DEV.*` and TEST `INFORMATION.TEST.*`, so code could
   not be promoted. Everything was renamed to the environment-neutral package
   `INFORMATION.Interop.*` with the production `INFORMATION.Interop.Production`, committed on `DEV`,
   and loaded/compiled into IRIS DEV with `./scripts/load-dev.sh`.
8. Merged `DEV` into `TEST` locally and verified with `./scripts/deploy-test.sh --dry-run`.

## 3. One-time cutover steps

Steps 1–3 were completed on 2026-10-16: branches pushed, and `INFORMATION.Interop.Production` is running on
both DEV and TEST (see the troubleshooting table in section 5 for the issues hit). Step 5 was done the same day
(old classes backed up, then deleted on both instances). Step 4 is still open.

1. **Push the branches to GitHub** (from git bash):
   ```bash
   cd /Users/home/IRIS_CICD && git push -u origin main
   cd DEV_Git  && git push -u origin DEV
   cd ../TEST_Git && git push -u origin TEST
   ```
2. **Switch DEV to the new production:** Management Portal (DEV, USER) → Interoperability → Production
   Configuration → stop `INFORMATION.DEV` → open and start `INFORMATION.Interop.Production`.
3. **First deployment to TEST:** `cd TEST_Git && ./scripts/deploy-test.sh`, then in the TEST portal stop
   `INFORMATION.TEST` and start `INFORMATION.Interop.Production`.
4. **Environment-specific settings** (file paths, hosts, ports, credentials) must not live in the production
   class. Set them per instance under Interoperability → Configure → **System Default Settings**, e.g. the
   TEST-only `FilePath=/Users/home/Desktop/Desktop/`. Note that DEV's production also contains `Out_REST`
   and `FHIR_SDA_Process`, which TEST didn't have before – check their endpoints in TEST.
5. Once both instances run `INFORMATION.Interop.Production` correctly, delete the old classes
   (`INFORMATION.DEV*` on DEV; `INFORMATION.TEST*`, `INFORMATION.ADT*` on TEST), then re-run `status.sh` to confirm.

## 4. Day-to-day deployment workflow (DEV → TEST)

**Step 1 – Develop in DEV.** Use the Management Portal (production, rules, DTLs, BPLs) and/or VS Code:
open `IRIS_CICD.code-workspace` and edit files under the *DEV* folder (saving compiles on IRIS DEV).

**Step 2 – Export DEV and review**
```bash
cd /Users/home/IRIS_CICD/DEV_Git
git pull                         # stay in sync with GitHub
./scripts/export-dev.sh          # IRIS DEV -> src/
git status
git diff                         # review every change
```

**Step 3 – Commit and push DEV**
```bash
git add src
git commit -m "ADT: route A08 to new FHIR operation"
git push
```

**Step 4 – Promote to TEST and review**
```bash
cd /Users/home/IRIS_CICD/TEST_Git
git pull
git diff TEST..DEV -- src        # what will be promoted
git merge DEV                    # or open a DEV -> TEST pull request on GitHub and `git pull` afterwards
```

**Step 5 – Deploy to IRIS TEST**
```bash
./scripts/deploy-test.sh --dry-run   # shows new / modified documents, changes nothing
./scripts/deploy-test.sh             # uploads changed documents and compiles them
git push                             # TEST branch on GitHub = what is deployed
```

**Step 6 – Activate in TEST.** If the production class changed, Production Configuration → **Update**
(or restart the production). Test the interfaces.

Useful checks at any time:
```bash
./scripts/status.sh      # in DEV_Git or TEST_Git: differences between git and the instance
git log --oneline -10    # deployment history
```

### Rollback
```bash
cd /Users/home/IRIS_CICD/TEST_Git
git revert <commit>      # or: git checkout <good-commit> -- src && git commit -m "Rollback ..."
./scripts/deploy-test.sh
git push
```

## 5. Notes & troubleshooting

- `.env` is read literally (passwords may contain `$`, quotes, etc.) and is never committed.
- `401 Unauthorized` → check `IRIS_DEV_*` / `IRIS_TEST_*` in `.env`.
- Scripts refuse to run on the wrong branch (`export-dev.sh`/`load-dev.sh` only in `DEV_Git`,
  `deploy-test.sh` only in `TEST_Git`), and `deploy-test.sh` refuses uncommitted changes in `src/`.
- Deletions are **not** propagated to TEST automatically: `status.sh` lists them as `only-on-server`;
  delete those classes in TEST by hand after review.
- VS Code: install the *InterSystems ObjectScript Extension Pack*; it will prompt for the password of
  `iris-dev` / `iris-test` once and store it in the macOS Keychain.

### Issues hit during the initial setup (2026-10-16)

| Symptom | Cause | Fix |
|---|---|---|
| `ErrProductionSuspendedMismatch: Production 'INFORMATION.DEV' was suspended` when starting the new production on DEV | Old production was stopped with 8 messages still queued for the disabled `BadMessageHandler` | Start the old production, Monitor → Queues → abort the stuck messages, stop it cleanly, then start the new one (or `do ##class(Ens.Director).CleanProduction()` to discard queues) |
| `<CLASS DOES NOT EXIST> *HS.FHIRServer.Interop.HTTPOperation` on TEST | TEST's USER namespace was never activated for HealthShare Foundation, so no `HS.*` classes were mapped | Run the Foundation installer for USER on TEST (below) |
| Installer fails with `<CLASS DOES NOT EXIST> *HS.Util.Installer.Foundation` | `iris session TEST -U HSLIB` still logs in to the account's default namespace (USER) | Run `set $namespace="HSLIB"` after logging in |
| Installer fails with `... before HSSYS exists` | Account lacked `%All`, so HSSYS was invisible to it | Give the account `%All` on that instance (Security → Users → Roles) |

Foundation activation (once per instance/namespace; DEV and TEST must match):
```
iris session TEST -U HSLIB
set $namespace="HSLIB"
do ##class(HS.Util.Installer.Foundation).Install("USER")
halt
```
Success is logged in `/opt/Intersystems/IRISTEST/mgr/HS.Util.Installer.USER-<n>.log`. Afterwards recompile
(`do $system.OBJ.Compile("INFORMATION.Interop.*","cuk")` in USER) and start the production.

Keep an eye on memory: both instances run on one Mac and TEST logged repeated
`Physical Memory is 97-98% used` paging warnings.
