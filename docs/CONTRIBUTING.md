# How to Contribute

## Did you find a bug or would you like to suggest an improvement?

Please go to [Issues](https://github.com/SUSE/rmt/issues/new), create a new issue, and describe what you think could be fixed or improved.

## Do you want to make code changes?

We always welcome outside contributions to RMT, however, we ask that you keep to our standards for code changes:

- That modified code follows RMT's coding standards with `rubocop`.
- If any code is hard to understand, please provided comments.
- If any changes were made to the user experience, they are documented in the `MANUAL.md` file.
- Any changes should be fully tested and retain RMT's commitment to 100% test coverage.
- If changes are non-trivial, please create a changelog entry at `package/obs/rmt-server.changes`.
- All changes should at least be self-reviewed before it's ready for an external review.

Before you submit a pull request, it's recommended to submit an issue first to gather initial feedback and guidance.

## Issue and Pull Request Labels

| Label Name |  Description |
| --- | --- |
| `2 reviewers` | This is a major pull request which requires more than two reviewers. |
| `bug` | Confirmed bug reports or issues likely to be bugs. |
| `duplicate` | This is an issue which was already previously reported. |
| `enhancement` | This is a usability improvement or feature request. |
| `help-wanted` | This is an issue which can be worked on by a first time contributor. |
| `question` | This is an open question which needs to gather more feedback or research. |
| `user-feedback` | This is an issue or feature request from users of RMT. |
| `WIP` | This is a work in progress and should not be merged. |
| `depfu` | Automated pull requests by depfu to upgrade RMT's dependencies. |

Thanks,

The RMT Team
