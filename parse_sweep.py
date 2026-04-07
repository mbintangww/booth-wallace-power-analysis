"""
parse_sweep.py — Parse sparsity sweep power reports and generate graph.

Usage:
    nix-shell -p python3Packages.matplotlib python3Packages.pandas \
        --run "python3 parse_sweep.py"

Reads:  <design>/sim_out/power_report_N.log  (N = 0,10,...,90)
Writes: sweep_results.csv
        docs/power_vs_sparsity.png
"""

import re
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd

DESIGNS = ["behavioral", "structural-baseline", "structural-icg"]
SPARSITY = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90]

COLORS = {
    "behavioral":        "#2196F3",  
    "structural-baseline": "#4CAF50",  
    "structural-icg":    "#F44336",  
}

LABELS = {
    "behavioral":          "Behavioral",
    "structural-baseline": "Structural Baseline",
    "structural-icg":      "Structural ICG",
}

# Regex: match the Total row in OpenROAD power report
TOTAL_RE = re.compile(
    r'^Total\s+([\d.e+\-]+)\s+([\d.e+\-]+)\s+([\d.e+\-]+)\s+([\d.e+\-]+)',
    re.MULTILINE
)

rows = []

for design in DESIGNS:
    for zpct in SPARSITY:
        log_path = os.path.join(design, "sim_out", f"power_report_{zpct}.log")
        if not os.path.exists(log_path):
            print(f"  MISSING: {log_path}")
            continue

        with open(log_path) as f:
            content = f.read()

        m = TOTAL_RE.search(content)
        if not m:
            print(f"  PARSE ERROR: Total row not found in {log_path}")
            continue

        internal_w  = float(m.group(1))
        switching_w = float(m.group(2))
        leakage_w   = float(m.group(3))
        total_w     = float(m.group(4))

        rows.append({
            "design":       design,
            "zero_pct":     zpct,
            "internal_mw":  internal_w  * 1000,
            "switching_mw": switching_w * 1000,
            "leakage_mw":   leakage_w   * 1000,
            "total_mw":     total_w     * 1000,
        })

if not rows:
    print("No data found. Run ./run_sweep.sh first.")
    exit(1)

df = pd.DataFrame(rows)

# --- Save CSV ---
df.to_csv("sweep_results.csv", index=False)
print(f"Saved sweep_results.csv ({len(df)} rows)")

# --- Print summary table ---
print("\n=== Power vs Sparsity (mW) ===")
pivot = df.pivot(index="zero_pct", columns="design", values="total_mw")
print(pivot.to_string(float_format="%.3f"))

# --- Find crossover: ICG vs Structural Baseline ---
crossover_pct = None
if "structural-baseline" in df["design"].values and "structural-icg" in df["design"].values:
    base = df[df["design"] == "structural-baseline"][["zero_pct", "total_mw"]].set_index("zero_pct")
    icg  = df[df["design"] == "structural-icg"][["zero_pct", "total_mw"]].set_index("zero_pct")
    diff = (base["total_mw"] - icg["total_mw"]).dropna()
    # crossover where diff changes sign (ICG becomes better)
    for i in range(len(diff) - 1):
        if diff.iloc[i] <= 0 and diff.iloc[i+1] > 0:
            # linear interpolation between the two points
            x0, x1 = diff.index[i], diff.index[i+1]
            y0, y1 = diff.iloc[i], diff.iloc[i+1]
            crossover_pct = x0 + (0 - y0) / (y1 - y0) * (x1 - x0)
            break

if crossover_pct is not None:
    print(f"\nCrossover point (ICG = Baseline): ~{crossover_pct:.1f}% zero input")
else:
    print("\nCrossover point: not found in measured range")

# --- Plot ---
fig, ax = plt.subplots(figsize=(9, 5.5))

for design in DESIGNS:
    subset = df[df["design"] == design].sort_values("zero_pct")
    if subset.empty:
        continue
    ax.plot(
        subset["zero_pct"],
        subset["total_mw"],
        marker='o',
        linewidth=2,
        markersize=6,
        color=COLORS[design],
        label=LABELS[design],
    )

if crossover_pct is not None:
    ax.axvline(
        x=crossover_pct,
        color='gray',
        linestyle='--',
        linewidth=1.2,
        label=f'Crossover ~{crossover_pct:.0f}%',
    )

ax.set_xlabel("Zero Input (%)", fontsize=12)
ax.set_ylabel("Total Dynamic Power (mW)", fontsize=12)
ax.set_title("Power vs Input Sparsity — Sky130, nom_tt_025C_1v80, 62.5 MHz", fontsize=12)
ax.set_xticks(SPARSITY)
ax.grid(True, linestyle='--', alpha=0.5)
ax.legend(fontsize=10)
fig.tight_layout()

os.makedirs("docs", exist_ok=True)
out_path = "docs/power_vs_sparsity.png"
fig.savefig(out_path, dpi=150)
print(f"\nSaved {out_path}")
