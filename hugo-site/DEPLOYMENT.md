# Deployment to GitHub Pages

This repository is configured to build and deploy the Hugo site automatically via GitHub Actions.

How it works:

1. Push changes to `main` (files under `hugo-site/`).
2. GitHub Actions builds the site using Hugo (extended) and the workflow at `.github/workflows/hugo.yml`.
3. The `actions/deploy-pages` action publishes the generated `public/` output to the Pages site.

Ensure the repository's Pages settings allow GitHub Actions to publish to Pages and the `main` branch is configured.
