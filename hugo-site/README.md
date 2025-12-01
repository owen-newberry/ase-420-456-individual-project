# hugo-site

Local development:

1. Install Hugo extended (https://gohugo.io/getting-started/quick-start/)
2. From repository root run:

```bash
cd hugo-site
hugo server
```

Build production output:

```bash
cd hugo-site
hugo --minify
```

To preview the production build, run `hugo server --bind 127.0.0.1 --baseURL "https://your-base-url/"`.
# Trigger rebuild
