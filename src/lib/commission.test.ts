import { describe, expect, it } from "vitest";
import { computeLineFee, describeRule, grossCents, NO_FEE, type FeeableLine } from "./commission";
import type { CommissionRule } from "./domain";

const booking: FeeableLine = {
  kind: "reservation",
  amountCents: 50440,
  grossEarningsCents: 52000,
  serviceFeeCents: 1560,
  fastPayFeeCents: 0,
  cleaningFeeCents: 8500,
};

const rule: CommissionRule = {
  base: "payout",
  rateBps: 2000,
  excludeCleaningFee: true,
  cleaningFeeTo: "owner",
  flatFeePerReservationCents: 0,
  monthlyFeeCents: 0,
};

describe("computeLineFee", () => {
  it("takes a percentage of the payout without the cleaning fee", () => {
    expect(computeLineFee(booking, rule, { chargeFlatFee: true })).toEqual({
      baseCents: 41940,
      commissionCents: 8388,
      flatFeeCents: 0,
      cleaningFeeCents: 0,
      totalCents: 8388,
    });
  });

  it("can take a percentage of gross revenue including cleaning", () => {
    const fee = computeLineFee(booking, { ...rule, base: "gross", excludeCleaningFee: false }, { chargeFlatFee: true });
    expect(fee.baseCents).toBe(52000);
    expect(fee.commissionCents).toBe(10400);
  });

  it("gives the co-host the cleaning fee without also taking commission on it", () => {
    const fee = computeLineFee(booking, { ...rule, excludeCleaningFee: false, cleaningFeeTo: "cohost" }, { chargeFlatFee: true });
    expect(fee).toEqual({ baseCents: 41940, commissionCents: 8388, flatFeeCents: 0, cleaningFeeCents: 8500, totalCents: 16888 });
  });

  it("charges the flat fee only when asked and only on reservations", () => {
    const withFlat = { ...rule, flatFeePerReservationCents: 2500 };
    expect(computeLineFee(booking, withFlat, { chargeFlatFee: true }).flatFeeCents).toBe(2500);
    expect(computeLineFee(booking, withFlat, { chargeFlatFee: false }).flatFeeCents).toBe(0);
    const refund: FeeableLine = { ...booking, kind: "adjustment", amountCents: -6000, grossEarningsCents: -6186, serviceFeeCents: -186, cleaningFeeCents: 0 };
    expect(computeLineFee(refund, withFlat, { chargeFlatFee: true })).toEqual({
      baseCents: -6000,
      commissionCents: -1200,
      flatFeeCents: 0,
      cleaningFeeCents: 0,
      totalCents: -1200,
    });
  });

  it("never charges on damage reimbursements or other lines", () => {
    expect(computeLineFee({ ...booking, kind: "resolution" }, rule, { chargeFlatFee: true })).toEqual(NO_FEE);
    expect(computeLineFee({ ...booking, kind: "other" }, rule, { chargeFlatFee: true })).toEqual(NO_FEE);
  });

  it("rebuilds gross revenue when the export has no gross column", () => {
    expect(grossCents({ ...booking, grossEarningsCents: null, fastPayFeeCents: 100 })).toBe(52100);
  });
});

describe("describeRule", () => {
  it("summarizes the rule", () => {
    expect(describeRule(rule)).toBe("20% of Airbnb payout, excluding cleaning fees");
    expect(
      describeRule({ ...rule, base: "gross", excludeCleaningFee: false, rateBps: 1250, flatFeePerReservationCents: 2500, monthlyFeeCents: 10000 }),
    ).toBe("12.5% of gross booking revenue · $25.00 per booking · $100.00 per month");
    expect(describeRule({ ...rule, rateBps: 0 })).toBe("No co-host fee");
  });
});
