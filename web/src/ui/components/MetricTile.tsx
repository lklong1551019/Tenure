import type { Metric } from '../../domain/model'
import { metricChangeText, withUnit } from '../../domain/story'
import './components.css'

/** "-44%", in a capsule. */
export function ChangePill({ text }: { text: string }) {
  return <span className="change-pill">{text}</span>
}

/** One metric: label, before struck through, after in bold, change, and how it was measured. */
export function MetricTile({ metric }: { metric: Metric }) {
  const change = metricChangeText(metric)
  const before = metric.before ? withUnit(metric, metric.before) : undefined
  return (
    <div className="metric-tile">
      <div className="metric-label">{metric.label}</div>
      <div className="metric-values">
        {before && (
          <s className="metric-before" aria-label={`from ${before}`}>
            {before}
          </s>
        )}
        <span className="metric-after">{withUnit(metric, metric.after)}</span>
      </div>
      {change && <ChangePill text={change} />}
      {metric.note && <div className="metric-note">{metric.note}</div>}
    </div>
  )
}
