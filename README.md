# PulsePlay — Streaming Analytics (Power BI)

**BI dashboard** for a fictional OTT service. Tracks usage, retention, content performance, and acquisition with a clean dark theme.

---

## What this solves
- Monitor **MAU/WAU/DAU** and **stickiness** over time  
- Compare **Live vs VOD**, **device mix**, and **genres**  
- Track **Trial → Pay** by **acquisition channel**

---

## Pages
- **Overview** – KPIs (MAU, Avg DAU, Stickiness, Watchtime h), MAU trend, watchtime by genre, Top 10 content (latest month).  
- **Content** – Live vs VOD (hours & share), device mix, completion distribution.  
- **Acquisition** – Trial Users → Converted.

## Data & Model
Synthetic, realistic dataset:
- **Facts:** `sessions`, `events`  
- **Dims:** `content`, `subscribers`, `date_dim`  
- Star schema

---

## Key Measures (sample)
`Watchtime_hr`, `Active Users`, `DAU/WAU/MAU (Month)`, `Avg DAU (Month)`, `Stickiness (1/30)`,  
`Live/VOD Watch Hours`, `Live Share`,  
`Trial Users`, `Converted From Trial`, `Trial → Pay Rate`, `Cancels (M)`,  

---

## Screenshots
### Overview
![Overview](IMG/Overview.PNG)

### Content Page
![Content](IMG/Content.PNG)

### Acquisition Page
![Acquisition](IMG/Acquisition.PNG)

---

## Deliverables
- **Power BI file**: `Maven_market.pbix`  
- **PDF export** of the dashboard for non-Power BI users (see `/docs/`)  
