# Pediatric rule transcription

Pediatric scoring remains deliberately unsupported in this scaffold.

Before a pediatric rule family becomes executable:

- identify every metric-specific age transition;
- distinguish scoring eligibility from dataset availability;
- document whether a precomputed percentile or reference adapter is required;
- record the reference provider, provider version, source profile, and fallback
  behavior;
- verify the LE8 point mapping separately from percentile calculation; and
- create fixed fixtures spanning ages, reference-sex categories, heights, and
  measurement boundaries where applicable.

Never infer a pediatric score from adult thresholds or general public-health
recommendations.

