import { formatMoney } from "@/lib/money";

export interface FeesChartPoint {
  /** "YYYY-MM" */
  month: string;
  /** Short label, e.g. "Aug". */
  label: string;
  cents: number;
}

/** Nice round top for the y axis: 1, 2 or 5 × a power of ten. */
function niceCeiling(value: number): number {
  if (value <= 0) return 100_00;
  const power = 10 ** Math.floor(Math.log10(value));
  const step = [1, 2, 5, 10].find((m) => m * power >= value)!;
  return step * power;
}

/**
 * Column chart of the co-host's fees per month. Single series, so no legend: the
 * card title names it. Columns carry a hover tooltip; the latest value is
 * labeled on its cap; a table gives screen readers the same numbers.
 */
export function FeesChart({ points }: { points: FeesChartPoint[] }) {
  const top = niceCeiling(Math.max(...points.map((p) => p.cents), 0));
  const ticks = [top, top / 2, 0];
  const last = points.length - 1;

  return (
    <figure>
      <div className="flex gap-3" aria-hidden>
        <div className="flex h-44 flex-col justify-between py-0 text-right text-xs text-ink-400">
          {ticks.map((t) => (
            <span key={t} className="tabular -translate-y-1/2 first:translate-y-0 last:translate-y-0">
              {formatMoney(t).replace(/\.00$/, "")}
            </span>
          ))}
        </div>
        <div className="relative h-44 flex-1">
          {ticks.map((t, i) => (
            <div key={t} className="absolute inset-x-0 border-t border-ink-100" style={{ top: `${(i / (ticks.length - 1)) * 100}%` }} />
          ))}
          <div className="absolute inset-0 flex items-end justify-around gap-1">
            {points.map((p, i) => {
              const height = top > 0 ? (p.cents / top) * 100 : 0;
              return (
                <div key={p.month} className="group relative flex h-full w-full max-w-16 items-end justify-center">
                  <div
                    className="w-full max-w-6 rounded-t bg-brand-500 transition-opacity group-hover:opacity-80"
                    style={{ height: `${Math.max(height, p.cents > 0 ? 1.5 : 0)}%` }}
                  />
                  {i === last && p.cents > 0 ? (
                    <span className="tabular absolute text-xs font-semibold text-ink-900" style={{ bottom: `calc(${height}% + 4px)` }}>
                      {formatMoney(Math.round(p.cents / 100) * 100).replace(/\.00$/, "")}
                    </span>
                  ) : null}
                  <div className="pointer-events-none absolute bottom-full z-10 mb-1 hidden rounded-md bg-ink-900 px-2 py-1 text-xs whitespace-nowrap text-white shadow group-hover:block">
                    {p.label}: <span className="tabular font-semibold">{formatMoney(p.cents)}</span>
                  </div>
                  {/* Hit area taller than the mark so small columns stay hoverable. */}
                  <div className="absolute inset-0" />
                </div>
              );
            })}
          </div>
        </div>
      </div>
      <div className="ml-12 flex justify-around gap-1 pt-2 text-xs text-ink-500" aria-hidden>
        {points.map((p) => (
          <span key={p.month} className="w-full max-w-16 text-center">
            {p.label}
          </span>
        ))}
      </div>
      <table className="sr-only">
        <caption>Your fees per month</caption>
        <thead>
          <tr>
            <th scope="col">Month</th>
            <th scope="col">Fees</th>
          </tr>
        </thead>
        <tbody>
          {points.map((p) => (
            <tr key={p.month}>
              <th scope="row">{p.month}</th>
              <td>{formatMoney(p.cents)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  );
}
