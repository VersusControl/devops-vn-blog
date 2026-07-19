# DevOps VN

DevOps VN is a website that shares knowledge about DevOps and Cloud Computing.

**Sponsored by [Versus Incident](https://github.com/VersusControl/versus-incident)**

## How to Contribute

Contributions are welcome — whether you're translating an article, fixing a
typo, improving styling, or adding a new post. Follow the steps below.

### 1. Fork and clone

1. Click **Fork** on the GitHub repository to create your own copy.
2. Clone your fork locally:

   ```bash
   git clone https://github.com/<your-username>/devops-vn-blog.git
   cd devops-vn-blog
   ```

3. Add the original repository as an `upstream` remote so you can keep your fork
   up to date:

   ```bash
   git remote add upstream https://github.com/VersusControl/devops-vn-blog.git
   ```

### 2. Create a branch

Always work on a descriptive feature branch rather than `main`:

```bash
git checkout -b add/terraform-part-19
# or: fix/typo-networking-osi, chore/update-styles, etc.
```

### 3. Make your change

Run the site locally first (see [Local Development](#local-development)) so you
can preview your changes at `http://127.0.0.1:4000`.

**Adding or translating an article**

1. Create a new Markdown file in `_articles/` using a descriptive kebab-case
   slug, e.g. `_articles/terraform-19-workspaces-in-depth.md`.
2. Add the front matter at the top of the file:

   ```yaml
   ---
   layout: post
   title: "Your Article Title"
   date: 2024-01-31
   author: Your Name
   subtitle: "A one-line summary shown under the title."
   tags: [terraform, aws, iac]
   image: /assets/images/posts/<slug>/cover.png
   ---
   ```

3. Put images for the post in `assets/images/posts/<slug>/` and reference them
   with root-absolute paths, e.g.
   `![Alt text](/assets/images/posts/<slug>/01.png)`.
   The `image:` in the front matter is the cover/hero — do **not** repeat it
   inline in the body.
4. Use the existing `tags` values where possible (`terraform`, `kubernetes`,
   `aws`, `azure`, `networking`, `linux`, `prometheus`, etc.) so the post
   appears automatically on the [Topics](topics.md) and Tags pages.
5. Keep writing style consistent with existing articles and translate content
   into clear English.

### 4. Test your change

Build the site and make sure it compiles with no errors and no broken links or
images:

```bash
bundle exec jekyll build
```

Preview locally and check the affected pages render correctly:

```bash
bundle exec jekyll serve
```

### 5. Commit and push

Write a clear, imperative commit message:

```bash
git add .
git commit -m "Add Terraform Series Part 19: Workspaces in depth"
git push origin add/terraform-part-19
```

### 6. Open a Pull Request

1. Go to your fork on GitHub and click **Compare & pull request**.
2. Target the `main` branch of `VersusControl/devops-vn-blog`.
3. Describe **what** you changed and **why**. Include screenshots for visual
   changes.
4. Make sure the build passes; a maintainer will review and merge.

Once merged into `main`, the site is rebuilt and deployed automatically (see
[Deployment](#deployment)).

## Project Structure

```
_config.yml                 # Site configuration
_layouts/                   # base, home, post, page templates
_articles/                  # Blog posts (translated articles go here)
assets/css/main.css         # Styles
assets/images/              # Images (author photo, post images)
index.md                    # Home page
about.md                    # About page
topics.md                   # Topics / series overview
.github/workflows/deploy.yml # GitHub Pages deployment
```
