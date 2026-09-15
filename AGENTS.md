# Repository workflow

- Make changes on a separate branch and open a pull request against `main`.
- Describe what changed, how it was tested, and any simulated failure paths in the PR.
- Do not merge pull requests yourself.
- Tests must use isolated temporary folders and doubles for Windows known folders;
  never run cleanup against the user's real files.
