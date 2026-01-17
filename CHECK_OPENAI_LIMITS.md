# 🔍 OpenAI Limieten Checken

## 📊 Methode 1: Usage Dashboard

### Stap 1: Ga naar Usage
**Link:** https://platform.openai.com/usage

**Wat zie je:**
```
┌─────────────────────────────────┐
│ Total usage this month:         │
│ $2.45                           │
│                                 │
│ Today: $0.15                    │
│                                 │
│ Breakdown:                      │
│ • Whisper: $0.12 (20 min)      │
│ • GPT-5-nano: $0.03            │
└─────────────────────────────────┘
```

**Handige filters:**
- 📅 Datum range (vandaag/week/maand)
- 🔧 Per model (Whisper, GPT-5-nano)
- 💰 Kosten per API call

---

## ⚡ Methode 2: Rate Limits

### Stap 2: Ga naar Rate Limits
**Link:** https://platform.openai.com/settings/organization/limits

**Wat zie je:**

### Free Tier:
```
❌ Whisper: 0 RPM (niet beschikbaar)
❌ GPT-5-nano: 3 RPM, 200/dag
```

### Tier 1 ($5+ betaald):
```
✅ Whisper: 50 RPM
✅ GPT-5-nano: 500 RPM
```

### Tier 2 ($50+ betaald):
```
✅ Whisper: 100 RPM
✅ GPT-5-nano: 5,000 RPM
```

**RPM** = Requests Per Minute

---

## 💳 Methode 3: Billing & Credits

### Stap 3: Ga naar Billing
**Link:** https://platform.openai.com/account/billing

**Wat zie je:**
```
┌─────────────────────────────────┐
│ Current balance: $10.00         │
│                                 │
│ Usage limits:                   │
│ • Soft limit: $10/month         │
│ • Hard limit: $20/month         │
│                                 │
│ This month: $2.45 / $10.00     │
└─────────────────────────────────┘
```

**Stel je limits in:**
1. Klik "Set usage limits"
2. **Soft limit** → Email bij 80% (bijv. $10)
3. **Hard limit** → Stop automatisch (bijv. $20)
4. ✅ Save

---

## 🚨 Waarschuwingssignalen:

### Je krijgt Error 429 als:
1. ⏱️ **Te veel requests:** > 50/min (Tier 1)
2. 💳 **Budget op:** Credit balance = $0
3. 🚫 **Hard limit:** Maandelijks max bereikt

### Oplossingen:
- ✅ Wacht 60 seconden (rate limit)
- ✅ Voeg credit toe (quota)
- ✅ Verhoog limits (settings)
- ✅ Upgrade tier ($5 → Tier 1)

---

## 📱 Quick Check via Terminal:

```bash
# Check je API key status
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY" | jq

# Success = 200 → Key werkt ✅
# Error 401 → Invalid key ❌
# Error 429 → Rate limit bereikt ⏱️
```

---

## 📊 Verwacht Gebruik (schatting):

Voor jouw app:

| Activiteit | Kosten | Per maand (50 opnames) |
|------------|--------|------------------------|
| **Transcriptie** (Whisper) | $0.006/min | ~$1.50 (250 min) |
| **Samenvatting** (GPT-5-nano) | ~$0.01/opname | ~$0.50 |
| **AI Assistant** (GPT-5-nano) | ~$0.02/chat | ~$1.00 |
| **TOTAAL** | | **~$3.00/maand** |

**Advies:** Zet $10 credit + $10 soft limit

---

## ✅ Checklist:

- [ ] Bekijk usage: https://platform.openai.com/usage
- [ ] Check rate limits: https://platform.openai.com/settings/organization/limits
- [ ] Controleer credit: https://platform.openai.com/account/billing
- [ ] Zet usage limits ($10 soft, $20 hard)
- [ ] Voeg payment method toe
- [ ] Add $10 credit

---

**Status:** ✅ Guide gemaakt (Jan 2026)

