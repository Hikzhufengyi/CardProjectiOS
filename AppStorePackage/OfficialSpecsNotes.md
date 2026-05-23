# Official Specs Notes

This file is a product-maintenance checklist, not legal advice. Requirements change, and different portals can enforce different file-size or upload rules. Verify each source before App Store submission and after major country/portal changes.

## Safer In-App Wording

Use:
- official-size
- based on published requirements
- review official source before submission
- compliance guidance
- Ready to Export

Avoid:
- official app
- government certified
- guaranteed accepted
- embassy approved
- 100% pass

## Core Presets to Keep Fresh

| Preset | Common Size | Background | Important Notes |
| --- | --- | --- | --- |
| U.S. Passport | 2 x 2 in / 51 x 51 mm | White or off-white | Head size and neutral expression are closely checked. |
| U.S. Visa | 600 x 600 px common upload | White or off-white | Upload portals may enforce file-size limits. |
| UK Passport / Visa | 35 x 45 mm | Light gray or cream | Avoid shadows and visible retouching. |
| Canada Passport | 50 x 70 mm | White or light | Face height differs from U.S. style photos. |
| Canada Visa / PR | 35 x 45 mm or portal-specific | White or light | File-size and dimensions can differ by application portal. |
| Schengen Visa | 35 x 45 mm | Plain light background | Face/head should occupy most of the frame. |
| Australia Passport / Visa | 35 x 45 mm | Plain light background | Check current Department of Home Affairs guidance. |
| Japan Passport / Visa | 35 x 45 mm | Plain background | Face position and top margin are important. |
| South Korea Passport / Visa | 35 x 45 mm | White | Avoid hair covering eyebrows/eyes. |
| India Visa | Square upload common | White/light | Online portal rules can vary by visa type. |
| China Visa | 33 x 48 mm | White or near-white | Head height and margins are often strict. |
| 4x6 Print Sheet | 101.6 x 152.4 mm | N/A | Use 300 DPI, optional crop marks, and repeated photos. |

## Release Checklist

- Verify each `sourceURL` opens and matches the in-app preset.
- Confirm `widthMM`, `heightMM`, `pixelSize`, head ratio, background, and `maxFileKB`.
- Keep disclaimers visible in the privacy page and export flow.
- Do not show fake seals or certification badges in screenshots.
- Test export files on a real device and inspect KB size after compression.
