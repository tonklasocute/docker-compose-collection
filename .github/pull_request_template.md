## What & why

<!-- One template or one fix per PR. Link an issue if there is one. -->

## Checklist

- [ ] Commit messages follow conventional commits, with the template as scope (`feat(redis): ...`)
- [ ] `scripts/lint.sh` passes
- [ ] `scripts/test-template.sh <template>` passes locally (paste the summary below)
- [ ] Images are pinned to explicit versions; no `latest`
- [ ] New or changed variables are in `.env.example` (with comments) and in the template README
- [ ] The README is updated (ports, credentials, troubleshooting, image size for app images)
- [ ] `CHANGELOG.md` has an entry under *Unreleased*
- [ ] No real secrets: only `change-me-...` placeholders

## Test output

```
<!-- e.g. the ✓ lines and PASS/FAIL from scripts/test-template.sh -->
```
