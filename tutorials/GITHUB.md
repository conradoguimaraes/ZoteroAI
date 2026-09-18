# Put the Project on GitHub

This is optional.

From the project folder:

```bash
git init
git add .
git commit -m "Zotero Metadata Enricher v0.2.5 build 7"
```

Create an empty GitHub repository, then:

```bash
git branch -M main
git remote add origin git@github.com:YOUR-ACCOUNT/zotero-metadata-enricher.git
git push -u origin main
```

Normal updates:

```bash
git status
git add .
git commit -m "Describe the change"
git push
```
