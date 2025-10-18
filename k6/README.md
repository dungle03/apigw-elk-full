# 📊 Load Testing Scripts

Scripts for performance and security testing using k6.

## Files

- `valid.js` - Legitimate traffic simulation
- `brute.js` - Brute-force attack simulation

## Usage

### Valid Traffic Test
```bash
# Test through Gateway
MODE=gw k6 run valid.js

# Test directly to backend (bypass Gateway)
MODE=base k6 run valid.js
```

### Brute-Force Test
```bash
# Attack through Gateway (will be blocked)
MODE=gw k6 run brute.js

# Attack directly to backend (no protection)
MODE=base k6 run brute.js
```

## Expected Results

### valid.js
- **Through Gateway**: Some overhead, all requests succeed
- **Direct**: Faster, no Gateway overhead

### brute.js
- **Through Gateway**: Many 429 (rate limited) ✅
- **Direct**: Only 401 (not rate limited) ❌

## Test Scenarios

| Scenario | VUs | Duration | Purpose |
|----------|-----|----------|---------|
| Valid traffic | 50→200→0 | 80s | Performance test |
| Brute-force | 100 | 60s | Security test |
