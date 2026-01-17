# 🚨 OpenAI Rate Limit (Error 429)

## Wat is Error 429?

**HTTP 429** = "Too Many Requests" - je hebt de OpenAI API limiet bereikt.

## 2 Soorten 429 Errors:

### 1. ⏱️ Rate Limit (Te veel requests per minuut)
**Symptoom:** 
```
⚠️ Rate limit reached. Wait 60 seconds and try again.
```

**Oorzaak:** Te veel API calls in korte tijd

**Oplossing:**
- ✅ Wacht 60 seconden
- ✅ Probeer opnieuw
- ✅ Upgrade naar betaald OpenAI plan (hogere limiet)

---

### 2. 💳 Quota Exceeded (Budget limiet bereikt)
**Symptoom:**
```
⚠️ OpenAI quota exceeded. Add billing info at platform.openai.com
```

**Oorzaak:** Gratis credits op of maandelijks budget bereikt

**Oplossing:**
1. **Ga naar:** https://platform.openai.com/account/billing
2. **Voeg betaalmethode toe**
3. **Zet usage limits:**
   - Soft limit: $10/maand (krijg email bij 80%)
   - Hard limit: $20/maand (stopt automatisch)

---

## 📊 OpenAI Pricing (2026)

### Whisper (Transcriptie):
- **$0.006 per minuut** audio
- 10 minuten opname = ~$0.06
- 100 minuten opname = ~$0.60

### GPT-4o-mini (Samenvatting):
- **$0.15 per 1M input tokens**
- **$0.60 per 1M output tokens**
- Gemiddelde summary = ~$0.01

### Voorbeeld maandkosten:
| Gebruik | Kosten |
|---------|--------|
| 10 opnames (5 min) | ~$0.50 |
| 50 opnames (5 min) | ~$2.50 |
| 100 opnames (5 min) | ~$5.00 |

---

## 🔧 Rate Limits Per Tier:

### Free Tier:
- ❌ **Whisper:** Niet beschikbaar gratis
- ❌ **GPT:** 3 requests/min, 200/dag
- **Oplossing:** Voeg $5 credit toe

### Tier 1 ($5+ betaald):
- ✅ **Whisper:** 50 requests/min
- ✅ **GPT-4o-mini:** 500 requests/min
- **Voldoende voor:** 50+ opnames/dag

### Tier 2 ($50+ betaald):
- ✅ **Whisper:** 100 requests/min
- ✅ **GPT-4o-mini:** 5,000 requests/min
- **Voldoende voor:** Professioneel gebruik

---

## 🎯 Wat de App Nu Doet:

### Betere Error Messages:
```swift
// Voor transcriptie (Whisper):
case 429 → "⚠️ Rate limit reached. Wait 60 seconds..."
case 401 → "Invalid OpenAI API key..."
case 413 → "Audio file too large (max 25MB)..."

// Voor samenvatting (GPT):
case 429 → "⚠️ Rate limit reached. Wait 60 seconds..."
case 401 → "Invalid OpenAI API key..."
```

### Gebruiker kan:
1. ✅ Duidelijke foutmelding zien
2. ✅ "Retry" knop gebruiken na 60 sec
3. ✅ Link naar platform.openai.com volgen

---

## 🚀 Snelle Fix:

### Optie A: Voeg Credit Toe (Aanbevolen)
1. Ga naar: https://platform.openai.com/account/billing
2. Klik "Add payment method"
3. Voeg $5-$10 credit toe
4. ✅ Klaar! Rate limits verhoogd

### Optie B: Gebruik Apple Speech (Gratis)
De app heeft Apple Speech als fallback - maar die is minder goed dan Whisper.

**Trade-off:**
- ✅ Gratis & on-device
- ❌ Lagere kwaliteit
- ❌ Minder talen
- ❌ Geen punctuatie

---

## 🔍 Debug Info:

Als je een 429 krijgt, check console voor:
```
❌ DIRECT WHISPER: Rate limit (429) - {error details}
```

De error details vertellen of het:
- `insufficient_quota` = Voeg credit toe
- `rate_limit_exceeded` = Wacht 60 sec

---

**Status:** ✅ Error handling verbeterd (Jan 2026)
**Files:** `RecordingsManager.swift`

