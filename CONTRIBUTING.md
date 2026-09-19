# Contributing to jevis

Bug reports, documentation improvements, and code contributions are welcome.
For substantial changes, open an issue first to discuss the proposed behavior.

## License and contribution rights

Unless explicitly stated otherwise, contributions submitted for inclusion in
this project are licensed under the [Apache License 2.0](LICENSE).
Contributors retain their copyright. We do not require a separate Contributor
License Agreement (CLA) or a copyright assignment.

Every commit submitted in a pull request must include a sign-off certifying
the [Developer Certificate of Origin (DCO) 1.1](DCO). Read the DCO before
signing off. Only contribute work that you have the right to submit under
the applicable license, including any required permission from your employer.
Preserve applicable third-party license and attribution notices.

## Sign off your commits

Use your own name and email address when creating a commit:

```bash
git commit -s -m "Describe your change"
```

This adds a trailer to the commit message:

```text
Signed-off-by: Your Name <you@example.com>
```

The sign-off certifies the DCO; it is not a cryptographic commit signature.
If you forgot the sign-off on your latest commit, and can certify the DCO
for that contribution, add it with:

```bash
git commit --amend --no-edit --signoff
```

Maintainers should check that each submitted commit has the required sign-off
before merging. Do not add another person's sign-off on their behalf.

## Development and pull requests

1. Fork the repository and create a branch for your change.
2. For behavior changes, write a failing test, implement the smallest fix, and
   refactor once the tests pass. Keep structural and behavioral changes separate.
3. Run the package checks from the repository root:

   ```bash
   flutter pub get
   flutter test
   flutter analyze
   ```

4. Open a pull request explaining the problem, resulting behavior, and checks run.

Documentation-only changes do not require Flutter tests. Check links and keep
the English, Korean, and Japanese READMEs consistent when changing shared guidance.
Write code comments in English. Never include API keys or local credentials in
commits. See the [README](README.md#example-and-tests) for live integration tests,
which require your own API key and a supported device.

## Public documentation

Keep user-facing reference documentation in `docs/` and link to it from the
READMEs. Keep `CHANGELOG.md` at the repository root. The `doc/` directory is
reserved for private research and experiment records and is excluded from Git
and package publication. Do not copy experimental reports, fixtures, or internal
review notes into `docs/`, or link public documentation to `doc/`.
