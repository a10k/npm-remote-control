# Notes

## Releasing

Push a version tag and GitHub Actions builds the DMG and attaches it to the release automatically:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## Signing and notarization

Without this, downloaded builds show a Gatekeeper warning. Add these secrets to the GitHub repo under Settings → Secrets:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_CERT` | Base64-encoded Developer ID `.p12`: `base64 -i cert.p12` |
| `DEVELOPER_ID_CERT_PASSWORD` | Password for the `.p12` |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_ID_PASSWORD` | An [app-specific password](https://support.apple.com/en-us/102654) |
| `APPLE_TEAM_ID` | 10-character team ID from developer.apple.com |

Once set, every release is signed, notarized, and stapled — opens on any Mac without a Gatekeeper warning.
