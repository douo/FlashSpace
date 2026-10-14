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
- Personal packaging signs `Contents/Resources/flashspace` after build using the fixed certificate loaded from `~/.config/apple/signing.env`; never use ad-hoc signing.
- Personal packaging must also sign Sparkle nested components with that certificate and the outer app with `disable-library-validation`; otherwise hardened runtime may reject the self-signed framework because it has no Apple Team ID.
- Compare the designated requirement with the existing installation. If the existing app is ad-hoc signed, document the identity migration and possible permission reauthorization rather than claiming signature continuity.
- For Developer ID distribution, sign CLI with Developer ID, re-sign the entire app, then notarize.
