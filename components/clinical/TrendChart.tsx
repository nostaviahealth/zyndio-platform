import React from 'react';
import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceArea,
  ResponsiveContainer,
  XAxis,
  YAxis,
} from 'recharts';
import { TrendPoint } from '../../lib/clinicalApi';
import { formatMonthDay, formatValue, rangeLegendText } from '../../lib/clinicalFormat';

// C59 trend chart (web rendering of the patient-app C30). Line + dots, latest
// dot filled, range band only when a range exists, legend otherwise "No range
// set yet". 664×220 desktop / 520×220 tablet via the parent card width (same
// data). The whole figure is role="img" with every point in the accessible
// label plus a visually-hidden table fallback, so the trend is available
// without the SVG. Data comes ONLY from patient_trend (never recomputed from
// the latest-results list).

const COLORS = {
  light: { line: '#2C5CF2', dot: '#FFFFFF', band: '#CDEBD8', grid: '#E6EAF2', axis: '#6B7486' },
  dark: { line: '#7C9CFF', dot: '#10141F', band: '#17382A', grid: '#222838', axis: '#A6B0C3' },
};

interface TrendChartProps {
  points: TrendPoint[];
  analyteLabel: string;
  unit: string | null;
  mode?: 'light' | 'dark';
}

const TrendChart: React.FC<TrendChartProps> = ({ points, analyteLabel, unit, mode = 'light' }) => {
  const c = COLORS[mode];
  const u = unit ?? '';

  const data = points.map((p, i) => ({
    x: formatMonthDay(p.takenAt),
    y: p.value,
    isLast: i === points.length - 1,
  }));

  const ranged = [...points].reverse().find((p) => p.rangeLow !== null || p.rangeHigh !== null);
  const rangeLow = ranged?.rangeLow ?? null;
  const rangeHigh = ranged?.rangeHigh ?? null;
  const hasBand = rangeLow !== null || rangeHigh !== null;
  const legend = rangeLegendText(rangeLow, rangeHigh, unit);

  const values = points.map((p) => p.value).filter((v): v is number => v !== null);
  const bounds = [...values, ...(rangeLow !== null ? [rangeLow] : []), ...(rangeHigh !== null ? [rangeHigh] : [])];
  const min = bounds.length ? Math.min(...bounds) - 0.3 : 0;
  const max = bounds.length ? Math.max(...bounds) + 0.3 : 1;

  const label =
    `${analyteLabel} chart: ` +
    points.map((p) => `${formatMonthDay(p.takenAt)} ${formatValue(p.value)}${u}`).join(', ');

  return (
    <figure className="mt-5" role="img" aria-label={label}>
      <div className="h-[220px] w-full">
        <ResponsiveContainer width="100%" height={220}>
          <LineChart data={data} margin={{ top: 8, right: 12, bottom: 4, left: 0 }}>
            <CartesianGrid stroke={c.grid} vertical={false} />
            {hasBand && (
              <ReferenceArea
                y1={rangeLow ?? min}
                y2={rangeHigh ?? max}
                fill={c.band}
                fillOpacity={mode === 'dark' ? 0.8 : 1}
                stroke="none"
                ifOverflow="extendDomain"
              />
            )}
            <XAxis
              dataKey="x"
              tick={{ fill: c.axis, fontSize: 12 }}
              tickLine={false}
              axisLine={{ stroke: c.grid }}
            />
            <YAxis
              width={44}
              domain={[min, max]}
              tick={{ fill: c.axis, fontSize: 12 }}
              tickLine={false}
              axisLine={false}
            />
            <Line
              type="linear"
              dataKey="y"
              stroke={c.line}
              strokeWidth={2}
              isAnimationActive={false}
              dot={(props: { cx?: number; cy?: number; payload?: { isLast?: boolean } }) => {
                const { cx, cy, payload } = props;
                if (cx === undefined || cy === undefined) return <g key={`${cx}-${cy}`} />;
                const last = payload?.isLast;
                return (
                  <circle
                    key={`${cx}-${cy}`}
                    cx={cx}
                    cy={cy}
                    r={last ? 6 : 4}
                    fill={last ? c.line : c.dot}
                    stroke={c.line}
                    strokeWidth={2}
                  />
                );
              }}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <figcaption className="mt-3 flex items-center gap-2 text-[13px] text-[#48556A] dark:text-[#A6B0C3]">
        {hasBand ? (
          <>
            <span className="inline-block h-3 w-4 rounded-sm" style={{ backgroundColor: c.band }} aria-hidden="true" />
            {legend}
          </>
        ) : (
          <span>No range set yet</span>
        )}
      </figcaption>

      <table className="sr-only">
        <caption>{analyteLabel} results over time</caption>
        <thead>
          <tr>
            <th scope="col">Date</th>
            <th scope="col">Value</th>
          </tr>
        </thead>
        <tbody>
          {points.map((p, i) => (
            <tr key={i}>
              <td>{formatMonthDay(p.takenAt)}</td>
              <td>
                {formatValue(p.value)}
                {u}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  );
};

export default TrendChart;
