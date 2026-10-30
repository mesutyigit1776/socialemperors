# CLAUDE.md

## Project

A preservation project for Social Empires, the Facebook Flash game by Social Point (2011–2019). This repository is a fork of `AcidCaos/socialemperors`.

- The Python/Flask server (`server.py`) emulates the Social Point backend. The original Flash client files in `assets/` connect to it.
- The game simulation runs in the Flash client: map, pathfinding, battles, unit AI and magic. The server stores the game state and applies the commands the client sends.
- `docs/AUDIT.md` records the condition of the code at commit `54df29e`. Read it before you change the server.
- `docs/NATIVE_PORT.md` records the port plan and its status.

### Port status

- Option A (original client + Ruffle desktop + bundled server): paused at about 20%. Ruffle 0.7.1 is in `templates/js/ruffle/`. The server fixes from the audit for the player-name check, the asset loader and safe saves are done.
- Option C (new client in Godot 4): the current work. Do this work on a separate branch, not on `main`.

### Layout

| Path | Contents |
|---|---|
| `server.py` | Flask routes. The `dynamic.flash1.dev.socialpoint.es/...` routes emulate the original backend. |
| `command.py`, `op.py` | Command table and game command handlers |
| `engine.py` | Game rules and calculations |
| `sessions.py` | Save loading and saving, PvP pool. Use `write_json_file` for every JSON file write. |
| `version.py` | Save versions and save migration |
| `get_game_config.py`, `mods.py`, `config/` | Game configuration JSON and JSON-patch mods |
| `templates/` | HTML pages, `js/external_interface.js`, bundled Ruffle |
| `assets/` | Original Social Point game files (about 1.3 GB) |
| `villages/` | Starting, quest and neighbour villages |
| `bundle.py` | Paths for source runs and PyInstaller builds |
| `build/` | Windows PyInstaller scripts |

### Run

```bash
pip install -r requirements.txt
```

```bash
python server.py
```

Then open `http://127.0.0.1:5050/`. Saves go to `saves/<USERID>.save.json`, and the previous version goes to `<USERID>.save.json.bak`.

### Checks

- The project has no automated tests. Do not add CI.
- On the Godot port branch, run `godot/checks/village_check.gd` after a change to the village rules or the save code. See `godot/README.md`. Run it locally; it is not CI.
- To check a server change, run the server and play in a browser with the Ruffle runner, or use headless Chromium with Playwright. Report what you tested and what you could not test.

### Code style

- Python files use tabs for indentation. Match the style of the code around the change.

### Legal

The code and the art in `assets/` and in the Flash client belong to Socialpoint, which is part of Take-Two.

- You may read decompiled client code to learn the game rules. Write the Godot code yourself. Do not copy or translate decompiled code line by line.
- Keep decompiled output out of the repository.
- The Godot port does not contain Social Point files. An import tool converts the art from the files that the user supplies.
- Do not add more Social Point files to the repository unless the owner of this fork asks for it.

## Git

- `main` is the only long-lived branch. Godot 4 port work goes on its own branch.
- Do not push to a different branch, and do not force-push, unless the owner asks for it.
- Commit author: `mesutyigit1776 <348371457+mesutyigit1776@users.noreply.github.com>`. Committer: Claude (`noreply@anthropic.com`), with a signed commit, so that GitHub shows "Verified".
- Write commit messages in ASD-STE100 Simplified Technical English. Use a short subject line, then short sentences in paragraphs. Do not make the message longer than necessary. Do not use bullet lists unless the content is a list.
- Keep the `Co-Authored-By: Claude ...` trailer. Do not add a `Claude-Session:` line.

## Engineering Rules for AI Agents

### 1. General Rules

- Read the related code before you make a change.
- Find the cause of a problem before you fix it.
- Make the smallest change that solves the problem.
- Preserve existing behavior unless the task requires a change.
- Do not change code that is not related to the task.
- Follow the existing project rules unless they conflict with a required change.
- Do not add complexity without a clear reason.
- Explain important design decisions when the code alone is not sufficient.

### 2. Dependencies and Coupling

- Make dependencies explicit.
- Do not rely on hidden dependencies or undocumented assumptions.
- Do not use global state when an explicit dependency is appropriate.
- Do not rely on call order unless the design requires it.
- Keep side effects visible and limited.
- Do not introduce circular dependencies.
- Keep modules independent when their functions do not require a dependency.

### 3. Folder Structure

- Group related code by feature or domain when practical.
- Keep files that change together close together.
- Do not split one feature across unrelated folders without a clear reason.
- Do not create folders only to follow a technical layer.
- Follow the established project structure when it works well.
- Change the folder structure only when the change gives a clear benefit.

### 4. Duplication

- Do not duplicate business rules or sources of truth.
- Reuse existing code when it has the required function.
- Keep shared rules in one suitable place.
- Do not copy code to avoid using an existing interface.
- Do not create a shared abstraction only to remove a small amount of repetition.
- Keep similar code separate when the code has different purposes.

### 5. Invalid States

- Use types and data structures that prevent invalid states when practical.
- Use explicit states and allowed transitions.
- Enforce required conditions when data enters the domain.
- Do not rely only on comments to describe required conditions.
- Do not allow unrelated parts of the code to change protected state.
- Keep invalid states out of normal program flow.

### 6. Large Modules and Objects

- Keep each module focused on a clear purpose.
- Keep each class and function focused on a clear task.
- Split a module when it contains unrelated responsibilities.
- Keep closely related operations together.
- Do not create many small files without a clear benefit.
- Do not make one module responsible for unrelated features.
- Do not place all shared logic in one central module.

### 7. Changes That Affect Many Files

- Keep related changes local when practical.
- Place shared behavior behind a suitable interface.
- Avoid designs that require the same change in many places.
- Keep each rule in one suitable location.
- Do not add extra layers only to reduce the number of changed files.
- Fix the design when one simple change requires many unrelated changes.

### 8. Layer Boundaries

- Follow the project's dependency direction.
- Access another layer through its defined interface.
- Do not access another layer's private state.
- Do not bypass an interface without a clear reason.
- Keep high-level rules independent of low-level implementation details.
- Do not introduce dependencies that violate the project architecture.
- Document and limit necessary exceptions.

### 9. Wrappers

- Do not add a wrapper that only passes data to another function.
- Add a wrapper when it enforces a rule or provides a required boundary.
- Keep wrappers that protect a public interface or control a dependency.
- Do not add extra layers without a clear function.
- Remove an existing wrapper only when it has no required purpose.

### 10. Errors and Validation

- Validate untrusted data at system boundaries.
- Validate user input, external data, file data, and network responses.
- Check required conditions before data enters the domain.
- Keep domain rules close to the data and operations they protect.
- Return clear errors when an operation fails.
- Do not ignore errors.
- Do not catch an error unless the code can handle it or add useful information.
- Do not check the same condition repeatedly without a clear reason.
- Do not add defensive code for impossible states without a known failure case.
- Keep required checks even when they appear repetitive.

### 11. Comments

- Use clear names and simple code.
- Do not write comments that repeat the code.
- Do not explain obvious operations.
- Add comments to explain important rules, limits, or design choices.
- Explain why unusual behavior is necessary.
- Remove comments that are no longer correct.
- Keep comments short and specific.
- Do not use comments to replace clear code or required validation.

### 12. Tests and Stable Benchmarks

- Keep existing tests and benchmark cases stable.
- Do not change tests after every code change.
- Do not add a unit test for every function or edit.
- Add a test only when it checks important behavior, a required condition, or a likely regression.
- Do not add tests that repeat existing coverage.
- Do not test private implementation details unless the project requires it.
- Do not change test inputs, expected outputs, or assertions to make new code pass.
- Do not delete or weaken a test because the code fails it.
- Do not change a benchmark to make new code appear faster.
- Keep benchmark inputs, workloads, and measurement rules unchanged.
- Keep existing tests unchanged when internal code changes do not change required behavior.
- Change a test only when the required behavior changes or the test has a confirmed defect.
- Explain the reason for every necessary change to a test.
- Keep test changes small and separate from unrelated code changes.
- Preserve the previous benchmark results when a comparison is required.
- Do not report a test or benchmark result unless you obtained it.

### 13. Regression Prevention

- Check the callers, dependencies, and tests before you change code.
- Identify the behavior that the change must preserve.
- Check for effects on other features.
- Add a focused regression test when it provides lasting value.
- Run the relevant existing tests after the change.
- Run broader checks when the change can affect other parts of the project.
- Investigate test failures before you change the tests.
- Do not hide failures or use special cases only to make tests pass.
- Report checks that you could not run.
- Keep unrelated behavior unchanged.

### 14. Final Review

Before you finish a task, check the following:

- Does the change solve the stated problem?
- Does the change preserve required behavior?
- Does the code introduce duplication or hidden dependencies?
- Does each module have a clear purpose?
- Are validation and error handling at the correct boundaries?
- Are the existing tests and benchmarks unchanged unless a change is required?
- Have the relevant tests and checks been run?
- Are all reported results accurate?

Do not refactor unrelated code. Do not add unnecessary files, wrappers, comments, tests, or abstractions. Prefer the smallest correct solution that fits the existing architecture.
