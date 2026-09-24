/**
 * IRS reporting threshold for Forms 1099-NEC and 1099-MISC: $600 for payments
 * made through 2025 and $2,000 for payments made in 2026 (One Big Beautiful
 * Bill Act). The IRS adjusts it for inflation after 2026, so later years reuse
 * the 2026 figure until it is updated here.
 */
export function form1099ThresholdCents(year: number): number {
  return year <= 2025 ? 60_000 : 200_000;
}
