"use client";

import clsx from "clsx";

interface Props {
  label: string;
  value: string | number;
  change?: string;
  accent?: "default" | "green" | "red" | "amber";
}

const accents = {
  default: "border-l-misk-500",
  green: "border-l-emerald-500",
  red: "border-l-red-500",
  amber: "border-l-amber-500",
};

export default function StatCard({ label, value, change, accent = "default" }: Props) {
  return (
    <div className={clsx("bg-white rounded-xl shadow-sm border-l-4 p-5", accents[accent])}>
      <p className="text-sm text-gray-500 font-medium">{label}</p>
      <p className="text-3xl font-bold mt-1">{typeof value === "number" ? value.toLocaleString() : value}</p>
      {change && <p className="text-xs text-gray-400 mt-2">{change}</p>}
    </div>
  );
}
