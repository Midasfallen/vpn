# Certificate Pinning Setup Guide

## Overview

Certificate pinning prevents man-in-the-middle (MITM) attacks by validating that the server's certificate matches a known public key hash. The app supports environment-specific pinning:

- **Development**: No pinning (allows self-signed certificates)
- **Staging**: Pinning disabled (for testing with development certificates)
- **Production**: Pinning enabled (validates against production certificate hashes)

## How It Works

1. **Extract Certificate Pin**: Get the SHA256 hash of the server's SubjectPublicKeyInfo (SPKI)
2. **Add to Config**: Store pin in `CertificatePinningClient.getProductionPins()`
3. **Validate on Connect**: When client connects to server, validates certificate hash
4. **Reject if Invalid**: If hash doesn't match, connection is refused (prevents MITM)

## Extracting Certificate Pins

### From PEM Certificate File

```bash
# Extract public key and get SHA256 hash (base64 encoded)
openssl x509 -in cert.pem -pubkey -noout | \
  openssl pkey -pubin -outform DER | \
  openssl dgst -sha256 -binary | \
  base64
```

### From Live Server

```bash
# Download certificate from server and extract pin
openssl s_client -connect api.vpn.prod:443 -showcerts </dev/null | \
  openssl x509 -outform PEM | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform DER | \
  openssl dgst -sha256 -binary | \
  base64
```

### Example Output
```
PQmD+DBSpF0tR67gU5+lHtZNUyNADwv/zBIUeL8GvJI=
```

## Adding Pins to Code

Edit `lib/api/certificate_pinning.dart`:

```dart
static Map<String, List<String>> getProductionPins() {
  return {
    'api.vpn.prod': [
      'PQmD+DBSpF0tR67gU5+lHtZNUyNADwv/zBIUeL8GvJI=',     // Primary pin
      'hd+FEG7aIJ344wSDPA9JmtBQtoFnW0Mekmp1Z2JDM6E=',      // Backup pin
    ],
  };
}
```

## Multiple Pins (Recommended)

Always add **at least 2 pins**:
1. **Primary**: Current certificate pin
2. **Backup**: Next certificate's pin (for rotation without app update)

This prevents app breakage during certificate renewal.

## Testing Pinning

### Disable Pinning Temporarily for Testing

In `lib/config/environment.dart`, set `enableCertificatePinning: false` for staging.

### Test with Invalid Pin

```dart
// lib/api/certificate_pinning.dart
static Map<String, List<String>> getStagingPins() {
  return {
    'staging-api.vpn.local': [
      'InvalidPin123456789Abcd=', // Should fail
    ],
  };
}
```

Then attempt to connect—should receive certificate validation error.

## Certificate Rotation Workflow

1. **Pre-Rotation**: Add new certificate pin to `getProductionPins()` as backup
2. **Deploy App**: Users update app with new pin
3. **Rotate Certificate**: Change server certificate (old pin still works via backup)
4. **Post-Rotation**: Remove old pin, keep new pin as primary
5. **Deploy Final Update**: Users update with only new pin

## Android Security Configuration

For additional Android security, create `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.vpn.prod</domain>
        <pin-set>
            <pin digest="SHA-256">PQmD+DBSpF0tR67gU5+lHtZNUyNADwv/zBIUeL8GvJI=</pin>
            <pin digest="SHA-256">hd+FEG7aIJ344wSDPA9JmtBQtoFnW0Mekmp1Z2JDM6E=</pin>
            <expiration>2026-01-01</expiration>
        </pin-set>
    </domain-config>
</network-security-config>
```

## Troubleshooting

### "Certificate validation failed" Error

**Cause**: Pin in code doesn't match actual certificate  
**Solution**: Re-extract pin using `openssl` commands above

### Connection Hangs

**Cause**: Certificate pinning enabled but pins not configured  
**Solution**: Check Environment.current.enableCertificatePinning is correct

### "Certificate Validation Error" in Logs

**Cause**: MITM attempt or corrupted certificate  
**Action**: Block connection immediately (intentional behavior)

## Security Best Practices

✅ **DO**:
- Use multiple pins (primary + backup)
- Pin leaf certificate or intermediate
- Rotate pins before certificate expiry
- Test pinning before deployment
- Monitor certificate expiry in production

❌ **DON'T**:
- Pin root CA certificate (too inflexible)
- Use single pin (blocks app during rotation)
- Disable pinning in production
- Hardcode pins without versioning strategy

## Current Status

| Environment | Pinning | Status |
|---|---|---|
| Development | ❌ Disabled | Working - allows self-signed |
| Staging | ❌ Disabled | Working - allows test certs |
| Production | ✅ Enabled | **TODO: Add real pins** |

## Next Steps

1. Generate certificate pins from production server
2. Add pins to `getProductionPins()` in `certificate_pinning.dart`
3. Test on staging with pinning enabled
4. Deploy to production
5. Monitor certificate expiry and plan rotation schedule
