# GitHub setup

Repository: [H4z3W4z/the-ninth-tide](https://github.com/H4z3W4z/the-ninth-tide). The owner created it with public visibility for initial development. It includes the design document, puzzle solutions, and endings.

## Clone and contribute

```sh
git clone https://github.com/H4z3W4z/the-ninth-tide.git
cd the-ninth-tide
```

Import `project.godot` in Godot to review the Intake Office. Follow README.md and AGENTS.md before changing assets or gameplay. Use ordinary branches and pull requests for subsequent changes; preserve the approved art references and update the asset manifest when artwork changes.

The authoring session uses the connected GitHub tools to populate the repository. Local GitHub CLI credentials are not required for those operations. On a developer machine, authenticate your preferred Git client when you need push access.

## Binary assets

The first asset set is small enough for ordinary Git, and no single asset approaches the normal large-file limit. PNGs are marked binary in .gitattributes. Do not add engine downloads, cache folders, or exported builds to Git. Before substantially expanding source audio or high-resolution artwork, choose a Git LFS policy and enable it on every contributor machine; no LFS filter is silently required by this initial scaffold.

## GitHub connection

The ChatGPT Codex Connector must be installed on the repository owner's GitHub account with access to this repository. Authorizing the app to act as the user is a separate step and does not install it on an account. Initial writes returned HTTP 403, `Resource not accessible by integration`, until the owner completed the installation; the README upload then succeeded.

To configure access, use the [ChatGPT Codex Connector installation page](https://github.com/apps/chatgpt-codex-connector/installations/new), choose the repository owner's account, and grant access to this repository. An existing installation can be configured under GitHub Settings > Applications > Installed GitHub Apps. No personal access token needs to be pasted into a chat.
