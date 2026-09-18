# Put the Project on GitHub

This is optional. The project works locally without GitHub.

## 1. Create the local Git repository

From Terminal in the project folder:

```bash
git init
git add .
git commit -m "Initial release v0.1.0 build 1"
```

## 2. Create an empty GitHub repository

Create a new repository on GitHub without adding another README, `.gitignore`, or license, because those files already exist here.

## 3. Connect and push

Replace `YOUR-ACCOUNT` and the repository name if needed:

```bash
git branch -M main
git remote add origin git@github.com:YOUR-ACCOUNT/zotero-metadata-enricher.git
git push -u origin main
```

The included GitHub Actions workflow runs verification on a macOS runner so the Apple-only helper is compiled against an Apple SDK as well as the plugin package being checked.

## Normal update workflow

```bash
git status
git add .
git commit -m "Describe the change"
git push
```

For a release, follow [RELEASES.md](RELEASES.md) before committing/pushing the release version.
