RULES FOR THIS TASK:
1. You are implementing a single task from an engineering plan. Your eng manager
   (the parent agent) has already reviewed and approved the approach.
2. Follow the "Context" and "Implementation" sections in this task file exactly.
   Do not deviate from the agreed design.
3. Write all tests specified in the "Acceptance criteria" section. Tests are
   non-negotiable.
4. Keep your changes minimal and focused. Only touch files listed in the
   "Implementation" section unless you discover a necessary change — in which
   case, document why.
5. If you get stuck or have a question:
   - First, re-read the task file (especially "Context" and "Implementation").
   - If still stuck, describe the problem clearly in your output. Your eng manager
     will review and provide guidance. Do NOT ask the user directly.
6. When done, output a clear summary:
   - Files created/modified (with brief description of each change)
   - Tests written and whether they pass
   - Any deviations from the task file (with justification)
   - Any unresolved issues or concerns
7. When you are finished, stage and commit ALL your changes in the worktree with
   a descriptive commit message prefixed with the task filename (e.g.,
   "task-03-auth-middleware: implement JWT validation and tests"). This is
   required — uncommitted changes in a worktree are lost when it is cleaned up.
8. Do NOT push your branch or create a pull request. Your eng manager will
   squash-merge your worktree branch into the feature branch after reviewing
   your work.
9. **Avoid `cd <path> && git ...` compound commands** — they trigger a security
   approval prompt. Use `git -C <path>` instead (e.g., `git -C . add -A` or
   `git -C /path/to/worktree push`). For non-git commands that need a specific
   directory, use a subshell: `(cd <path> && bun test ...)`.
