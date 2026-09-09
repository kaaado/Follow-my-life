# MULTI-PLAN FINANCIAL INTELLIGENCE SPECIFICATION

## 1. OVERVIEW
Plans represent long-term purchase goals, sinking funds, or target savings reserves (e.g. Laptop: 120,000 DZD, Travel: 80,000 DZD).

---

## 2. DETERMINISTIC CALCULATIONS
For each active plan:
- **Remaining Amount:** `Target Amount - Reserved/Current Amount`
- **Progress %:** `(Current Amount / Target Amount) * 100`
- **Required Monthly Contribution:** `Remaining Amount / Months Until Target Date`
- **Required Weekly Contribution:** `Remaining Amount / Weeks Until Target Date`
- **Estimated Completion Date:** Based on current monthly allocation rate.
- **Feasibility Score:** Assessed against historical net monthly cash flow.

---

## 3. MULTI-PLAN CONFLICT RESOLUTION
When total planned contributions exceed available monthly cash flow:
- Plans are prioritized by priority rating (`High`, `Medium`, `Low`).
- High-priority plans receive recommended allocation first.
- Detailed warning banners notify users of conflicts and propose adjusted timelines or contributions.
