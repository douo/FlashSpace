# FlashSpace Release Documentation Reference

Use `docs/upstream-v4.16.74-merge-impact.md` as the canonical user-facing merge impact document.

When updating the document after future upstream merges, include:

- Upstream version integrated.
- New upstream user-facing features.
- Specific impact on the user's workflow.
- Local behaviors explicitly preserved.
- Settings that may need review after upgrade.
- Packaging notes for personal builds.

Do not document internal speculation. Only document behavior confirmed by code review, build output, or user testing.

## Personal Packaging Note

Keep this distinction clear:

- Code history should not contain a `project.yml` CLI codesign patch.
- Personal packaging can still ad-hoc sign `Contents/Resources/flashspace` after build.
- Personal packaging must also re-sign Sparkle nested components and the outer app with `disable-library-validation`; otherwise dyld may reject `Sparkle.framework` at launch with a Team ID mismatch.
- For Developer ID distribution, sign CLI with Developer ID, re-sign the entire app, then notarize.
