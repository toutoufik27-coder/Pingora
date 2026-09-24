import type { CommissionRule, TransactionKind } from "@/lib/domain";
import { applyRate, formatBasisPoints, formatMoney } from "@/lib/money";

/** The money fields of a transaction that commission rules look at. */
export interface FeeableLine {
  kind: TransactionKind;
  amountCents: number;
  grossEarningsCents: number | null;
  serviceFeeCents: number;
  fastPayFeeCents: number;
  cleaningFeeCents: number;
}

export interface LineFee {
  /** Amount the percentage was applied to. */
  baseCents: number;
  commissionCents: number;
  flatFeeCents: number;
  /** Guest cleaning fee kept by the co-host. */
  cleaningFeeCents: number;
  totalCents: number;
}

export const NO_FEE: LineFee = Object.freeze({
  baseCents: 0,
  commissionCents: 0,
  flatFeeCents: 0,
  cleaningFeeCents: 0,
  totalCents: 0,
});

/** Gross booking revenue before Airbnb's host fee. */
export function grossCents(line: FeeableLine): number {
  return line.grossEarningsCents ?? line.amountCents + line.serviceFeeCents + line.fastPayFeeCents;
}

/**
 * Reservations and adjustments to them (alterations, refunds) earn commission.
 * Resolution payouts reimburse the owner for damage and other lines are passed
 * through untouched.
 */
export function isCommissionable(kind: TransactionKind): boolean {
  return kind === "reservation" || kind === "adjustment";
}

export function computeLineFee(
  line: FeeableLine,
  rule: CommissionRule,
  options: { chargeFlatFee: boolean },
): LineFee {
  if (!isCommissionable(line.kind)) return NO_FEE;

  // A co-host who keeps the cleaning fee never also takes commission on it.
  const excludeCleaning = rule.excludeCleaningFee || rule.cleaningFeeTo === "cohost";
  const raw = rule.base === "gross" ? grossCents(line) : line.amountCents;
  const baseCents = raw - (excludeCleaning ? line.cleaningFeeCents : 0);
  const commissionCents = applyRate(baseCents, rule.rateBps);
  const flatFeeCents = options.chargeFlatFee && line.kind === "reservation" ? rule.flatFeePerReservationCents : 0;
  const cleaningFeeCents = rule.cleaningFeeTo === "cohost" ? line.cleaningFeeCents : 0;

  return {
    baseCents,
    commissionCents,
    flatFeeCents,
    cleaningFeeCents,
    totalCents: commissionCents + flatFeeCents + cleaningFeeCents,
  };
}

/** One-line human summary, e.g. "20% of Airbnb payout, excluding cleaning · $25 per booking". */
export function describeRule(rule: CommissionRule): string {
  const parts: string[] = [];
  if (rule.rateBps > 0) {
    const base = rule.base === "gross" ? "gross booking revenue" : "Airbnb payout";
    const cleaning =
      rule.excludeCleaningFee || rule.cleaningFeeTo === "cohost" ? ", excluding cleaning fees" : "";
    parts.push(`${formatBasisPoints(rule.rateBps)} of ${base}${cleaning}`);
  }
  if (rule.flatFeePerReservationCents > 0) parts.push(`${formatMoney(rule.flatFeePerReservationCents)} per booking`);
  if (rule.monthlyFeeCents > 0) parts.push(`${formatMoney(rule.monthlyFeeCents)} per month`);
  if (rule.cleaningFeeTo === "cohost") parts.push("co-host keeps cleaning fees");
  return parts.length > 0 ? parts.join(" · ") : "No co-host fee";
}
